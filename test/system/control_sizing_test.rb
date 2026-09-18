# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# The kit's control metrics, measured in the browser (docs/specs/ui-control-sizing).
#
# Amended 2026-09-18: the scale gained two steps, xs and xl, and every step now carries inline
# padding, text size and radius as well as its height token, so the old "every control renders
# v0.3.0 unchanged" check (proved against the unmodified pre-scale components) is retired with
# the promise it proved. In its place, the box tests below pin each of the five steps' boxes to
# § Behavior's table -- a decision recorded once, in docs/specs/ui-control-sizing § Business
# rules, rule 3, never a side effect from here on.
#
# Every length Tailwind draws from its spacing unit is recorded here in units rather than
# pixels, and asserted twice -- once at Tailwind's own 0.25rem unit, once with --spacing
# retuned on :root -- which is what the token defaults claim (calc(var(--spacing) * 8) and its
# siblings). Font size, line height and radius are asserted in pixels: they don't move with the
# spacing unit (radius comes from --radius, a separate token; text size from Tailwind's own
# --text-* variables).
class ControlSizingTest < ApplicationSystemTestCase
  include SelectHelpers

  UNIT = 4.0            # Tailwind's own --spacing, 0.25rem
  RETUNED = '0.3rem'    # a host that has retuned it
  RETUNED_UNIT = 4.8

  # WCAG 2.5.8's target minimum, in CSS px.
  TARGET_MINIMUM = 24.0

  # The shared scale: one height per step, whatever the control (§ Behavior). A textarea grows
  # with its content, so its step sets a minimum instead -- one control height plus a constant
  # one-line allowance of seven spacing units.
  HEIGHT_UNITS = { xs: 6, sm: 7, default: 8, lg: 9, xl: 10 }.freeze
  STEPS = HEIGHT_UNITS.transform_values { |units| units * UNIT }.freeze
  TEXTAREA_ALLOWANCE_UNITS = 7
  TEXTAREA_ALLOWANCE = TEXTAREA_ALLOWANCE_UNITS * UNIT

  # Each step's own recipe, independent of the spacing unit: inline padding in spacing units
  # (multiplied by the unit under test below), font size and line height in px, and radius in
  # px -- Tailwind's rounded-sm/rounded-md at the kit's own --radius: 0.5rem.
  STEP_RECIPE = {
    xs: { padding: 2.0, font_size: 12.0, line_height: 16.0, radius: 4.0 },
    sm: { padding: 2.0, font_size: 14.0, line_height: 20.0, radius: 4.0 },
    default: { padding: 2.5, font_size: 14.0, line_height: 20.0, radius: 6.0 },
    lg: { padding: 3.0, font_size: 14.0, line_height: 20.0, radius: 6.0 },
    xl: { padding: 3.5, font_size: 14.0, line_height: 20.0, radius: 6.0 }
  }.freeze

  # Select's shared box (the native select, the combobox and search mode's trigger) widens its
  # end padding past the table's own value, by a constant five spacing units, to clear the
  # chevron (Ui::Select::Box::SIZES) -- the glyph's own size and position don't move with the
  # step, so the headroom it needs doesn't either.
  SELECT_END_EXTRA = 5.0
  SELECT_CONTROLS = ['the native select', 'the combobox', "search mode's trigger"].freeze

  HEIGHT_UNITS.each_key do |step|
    test "the box at size: :#{step} matches the table, at Tailwind's default spacing" do
      visit field_path
      open_all_sized_controls
      disable_transitions

      assert_step_box(step, UNIT)
    end

    test "the box at size: :#{step} matches the table, when a host retunes --spacing" do
      visit field_path
      open_all_sized_controls
      disable_transitions
      page.execute_script("document.documentElement.style.setProperty('--spacing', '#{RETUNED}')")

      assert_step_box(step, RETUNED_UNIT)
    end
  end

  test "the icon Button's box matches the table, at Tailwind's default spacing" do
    visit button_path
    disable_transitions

    assert_icon_box(UNIT)
  end

  test "the icon Button's box matches the table, when a host retunes --spacing" do
    visit button_path
    disable_transitions
    page.execute_script("document.documentElement.style.setProperty('--spacing', '#{RETUNED}')")

    assert_icon_box(RETUNED_UNIT)
  end

  test 'CS3: every control at a step is the height of that step, so a row of them aligns' do
    visit field_path
    open_all_sized_controls
    disable_transitions

    STEPS.each { |step, height| assert_step(step, height) }

    # The popup's search row is not a control: a list's density is its own, so it keeps one height
    # while the trigger it hangs from takes the step (ui-control-sizing § Behavior; ui-select
    # § Behavior, item 17).
    heights = STEPS.each_key.map { |step| search_row_height(step) }
    assert_equal 1, heights.uniq.size,
                 "the popup's search row moved with the step: #{STEPS.keys.zip(heights).to_h}"
    assert_operator heights.first, :>=, TARGET_MINIMUM
  end

  test 'CS4: an enhanced popup aligns to the width of the control it replaces, at every step' do
    visit field_path
    open_all_sized_controls
    disable_transitions

    STEPS.each_key do |step|
      combobox("sizes-#{step}-select").click
      assert_popup "sizes-#{step}-select", 'open'

      control = laid_out_rect("#sizes-#{step}-select-combobox")
      popup = laid_out_rect("#sizes-#{step}-select-popup")

      assert_in_delta control['width'], popup['width'], 1, "the #{step} popup does not match its control's width"
      press :escape
      assert_popup "sizes-#{step}-select", 'closed'
    end
  end

  test 'CS5: redefining a step token, on :root or on one wrapper, aligns every control at that step to it' do
    visit field_path
    open_all_sized_controls
    disable_transitions

    # Five independent tokens rather than a derived scale, so a redefinition is honoured
    # wherever it lands -- including below :root, where a derived scale would move `default`
    # and leave `sm` behind (docs/specs/ui-control-sizing, § Behavior).
    set_token(:root, '--control-height-sm', '3rem')
    assert_step(:sm, 48.0)
    assert_step(:default, STEPS[:default])

    set_token(:root, '--control-height-sm', nil)
    assert_step(:sm, STEPS[:sm])

    set_token('sizes-sm-row', '--control-height-sm', '3rem')
    assert_step(:sm, 48.0)
  end

  # Measured directly, because assert_accessible can't see it: axe-core 4.13 ships its
  # `target-size` rule disabled. Asserted at the kit's own token values only -- a host that
  # redefines a control height below 24px has chosen to break WCAG 2.5.8, and the kit doesn't
  # clamp it (docs/specs/ui-control-sizing, § Business rules, rule 5).
  test 'CS6: every control at the smallest step, and every icon-only Button, meets the 24px target minimum' do
    visit field_path
    open_all_sized_controls
    disable_transitions

    step_controls(:xs).merge('the textarea' => '#sizes-xs-textarea',
                             'an icon-only Button at size: :xs' => '#sizes-xs-icon-button')
                      .each { |name, selector| assert_target_size(name, selector) }

    visit button_path
    assert_target_size('the icon Button', "#button-sizes-preview [data-slot=button][aria-label='Add item']")
  end

  private

  # The page's demo shows two controls a row; the full set these checks measure sits under a
  # disclosure, and a closed <details> has no boxes to measure.
  def open_all_sized_controls
    page.execute_script("document.getElementById('control-sizes-all').open = true")
  end

  def assert_target_size(name, selector)
    rect = rect_of(selector)

    %w[width height].each do |side|
      assert_operator rect[side], :>=, TARGET_MINIMUM,
                      "#{name} is #{rect[side]}px in #{side}, under WCAG 2.5.8's #{TARGET_MINIMUM}px target minimum"
    end
  end

  # Measured with the popup open, because a row inside a closed popover has no box to measure.
  def search_row_height(step)
    id = "sizes-#{step}-search"
    find("##{id}-trigger").click
    assert_popup id, 'open'
    height = laid_out_rect("##{id}-search")['height']
    press :escape
    assert_popup id, 'closed'
    height
  end

  # Every control at one step, plus the textarea's minimum, against one height.
  def assert_step(step, height)
    step_controls(step).each do |name, selector|
      measured = metrics_of(find(selector, visible: :all))

      assert_in_delta height, measured['height'], 0.5,
                      "#{name} at size: :#{step} is #{measured['height']}px, not the #{height}px the step's token sets"
    end

    textarea = metrics_of(find("#sizes-#{step}-textarea"))
    assert_in_delta height + TEXTAREA_ALLOWANCE, textarea['min_height'], 0.5,
                    "the textarea at size: :#{step} has a #{textarea['min_height']}px minimum, " \
                    "not the #{height + TEXTAREA_ALLOWANCE}px its step sets"
  end

  # Every control's box at one step, against § Behavior's table: height, inline padding, font
  # size, line height and radius. Select's shared box (the native select, the combobox and
  # search mode's trigger) takes the same recipe with its end padding widened for the chevron.
  def assert_step_box(step, unit)
    height = HEIGHT_UNITS[step] * unit
    recipe = STEP_RECIPE.fetch(step)

    step_controls(step).each do |name, selector|
      assert_box(name, find(selector, visible: :all), height, recipe, unit,
                 end_padding: SELECT_CONTROLS.include?(name) ? recipe[:padding] + SELECT_END_EXTRA : recipe[:padding])
    end

    textarea = find("#sizes-#{step}-textarea")
    assert_box('the textarea', textarea, nil, recipe, unit, min_height: height + (TEXTAREA_ALLOWANCE_UNITS * unit))
  end

  # `icon` stays a single square bound to the default step (§ Behavior), so it is checked once,
  # against the default row's recipe, rather than once per step.
  def assert_icon_box(unit)
    recipe = STEP_RECIPE.fetch(:default)
    height = HEIGHT_UNITS[:default] * unit
    measured = metrics_of(find("#button-sizes-preview [data-slot=button][aria-label='Add item']"))

    assert_in_delta height, measured['height'], 0.5, "the icon Button is #{measured['height']}px tall, not #{height}px"
    assert_in_delta height, measured['width'], 0.5, "the icon Button is #{measured['width']}px wide, not #{height}px"
    assert_box_type('the icon Button', measured, recipe)
  end

  # One control's box against the recipe: height (or min_height, for a textarea), inline padding
  # -- symmetric unless `end_padding:` names a different end value, the way Select's box does --
  # font size, line height and radius.
  def assert_box(name, element, height, recipe, unit, end_padding: recipe[:padding], min_height: nil)
    measured = metrics_of(element)

    assert_box_height(name, measured, height, min_height)
    assert_in_delta recipe[:padding] * unit, measured['padding_left'], 0.5,
                    "#{name} has #{measured['padding_left']}px of start padding, not #{recipe[:padding] * unit}px"
    assert_in_delta end_padding * unit, measured['padding_right'], 0.5,
                    "#{name} has #{measured['padding_right']}px of end padding, not #{end_padding * unit}px"
    assert_box_type(name, measured, recipe)
  end

  def assert_box_height(name, measured, height, min_height)
    if min_height
      assert_in_delta min_height, measured['min_height'], 0.5,
                      "#{name} has a #{measured['min_height']}px minimum, not the #{min_height}px its step sets"
    else
      assert_in_delta height, measured['height'], 0.5, "#{name} is #{measured['height']}px tall, not #{height}px"
    end
  end

  def assert_box_type(name, measured, recipe)
    assert_in_delta recipe[:font_size], measured['fontSize'], 0.1, "#{name}'s font size moved"
    assert_in_delta recipe[:line_height], measured['lineHeight'], 0.1, "#{name}'s line height moved"
    assert_in_delta recipe[:radius], measured['radius'], 0.1, "#{name}'s radius moved"
  end

  # The native select is measured alongside the combobox that covers it: they are one box, and
  # a step that moved only one of them would show as a jump the moment JavaScript arrived.
  def step_controls(step)
    { 'the button' => "#sizes-#{step}-button",
      'the input' => "#sizes-#{step}-input",
      'the native select' => "#sizes-#{step}-select",
      'the combobox' => "#sizes-#{step}-select-combobox",
      "search mode's trigger" => "#sizes-#{step}-search-trigger" }
  end

  def set_token(element, token, value)
    page.execute_script(<<~JS, element.to_s, token, value)
      const el = arguments[0] === 'root' ? document.documentElement : document.getElementById(arguments[0])
      arguments[2] === null ? el.style.removeProperty(arguments[1]) : el.style.setProperty(arguments[1], arguments[2])
    JS
  end

  # One read per control: the rendered box, plus the computed lengths a class could move
  # without changing the box on a page this narrow. min-height is `none` on most controls,
  # which parses to NaN; that reads as 0 and is only asserted where it's the metric named.
  def metrics_of(element)
    page.evaluate_script(<<~JS, element)
      (function (el) {
        const style = getComputedStyle(el)
        const rect = el.getBoundingClientRect()
        const px = (value) => parseFloat(value) || 0

        return {
          height: rect.height, width: rect.width,
          min_height: px(style.minHeight),
          padding_top: px(style.paddingTop), padding_right: px(style.paddingRight),
          padding_bottom: px(style.paddingBottom), padding_left: px(style.paddingLeft),
          fontSize: px(style.fontSize), lineHeight: px(style.lineHeight),
          radius: px(style.borderTopLeftRadius)
        }
      })(arguments[0])
    JS
  end
end
