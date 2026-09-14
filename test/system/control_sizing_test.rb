# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# The kit's control metrics, measured in the browser (docs/specs/ui-control-sizing).
#
# Written and green against the unmodified v0.3.0 components before any of them moved onto
# the --control-height* tokens (§ Business rules, rule 3): a regression check that has never
# run against the old code proves nothing.
#
# Every length Tailwind draws from its spacing unit is recorded here in units rather than
# pixels, and asserted twice -- once at Tailwind's own 0.25rem unit, once with --spacing
# retuned on :root. That is what the token defaults claim (calc(var(--spacing) * 9) and its
# siblings), so a host that has already retuned --spacing sees no change either. Font size
# and line height are asserted in pixels, because they must not move with the spacing unit.
class ControlSizingTest < ApplicationSystemTestCase
  include SelectHelpers

  UNIT = 4.0            # Tailwind's own --spacing, 0.25rem
  RETUNED = '0.3rem'    # a host that has retuned it
  RETUNED_UNIT = 4.8

  TEXT_SM = 14.0
  TEXT_SM_LINE_HEIGHT = 20.0

  # The shared scale: one height per step, whatever the control (§ Behavior). A textarea grows
  # with its content, so its step sets a minimum instead -- one control height plus a constant
  # one-line allowance of seven spacing units.
  STEPS = { sm: 32.0, default: 36.0, lg: 40.0 }.freeze
  TEXTAREA_ALLOWANCE = 28.0

  # v0.3.0's boxes. `height`, `min_height`, `width` and the paddings are in spacing units.
  CONTROLS = {
    'Button sm' => { page: :button, selector: '#button-sizes-preview [data-slot=button]', text: 'Small',
                     height: 8, padding_x: 3, padding_y: 0 },
    'Button default' => { page: :button, selector: '#button-sizes-preview [data-slot=button]', text: 'Default',
                          height: 9, padding_x: 4, padding_y: 2 },
    'Button lg' => { page: :button, selector: '#button-sizes-preview [data-slot=button]', text: 'Large',
                     height: 10, padding_x: 6, padding_y: 0 },
    'Button icon' => { page: :button, selector: "#button-sizes-preview [data-slot=button][aria-label='Add item']",
                       height: 9, width: 9, padding_x: 0, padding_y: 0 },
    'Input' => { page: :input, selector: '#default-input', height: 9, padding_x: 3, padding_y: 1 },
    'Textarea' => { page: :textarea, selector: '#default-textarea', min_height: 16,
                    padding_x: 3, padding_y: 2 },
    'Select, native' => { page: :select, selector: '#demo_timezone', height: 9,
                          padding_left: 3, padding_right: 8 },
    'Select, combobox' => { page: :select, selector: '#demo_timezone-combobox', height: 9,
                            padding_left: 3, padding_right: 8 }
  }.freeze

  test 'CS1: every control renders v0.3.0 box metrics unchanged, at Tailwind default spacing' do
    assert_boxes(UNIT)
  end

  test 'CS2: every control renders v0.3.0 box metrics unchanged when a host retunes --spacing' do
    assert_boxes(RETUNED_UNIT) { page.execute_script("document.documentElement.style.setProperty('--spacing', '#{RETUNED}')") }
  end

  test 'CS3: every control at a step is the height of that step, so a row of them aligns' do
    visit field_path
    disable_transitions

    STEPS.each { |step, height| assert_step(step, height) }
  end

  test 'CS4: an enhanced popup aligns to the width of the control it replaces, at every step' do
    visit field_path
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
    disable_transitions

    # Three independent tokens rather than a derived scale, so a redefinition is honoured
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

  private

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

  # The native select is measured alongside the combobox that covers it: they are one box, and
  # a step that moved only one of them would show as a jump the moment JavaScript arrived.
  def step_controls(step)
    { 'the button' => "#sizes-#{step}-button",
      'the input' => "#sizes-#{step}-input",
      'the native select' => "#sizes-#{step}-select",
      'the combobox' => "#sizes-#{step}-select-combobox",
      'the search combobox' => "#sizes-#{step}-search-combobox",
      'search mode\'s show-options button' => "#sizes-#{step}-search-combobox + button" }
  end

  def set_token(element, token, value)
    page.execute_script(<<~JS, element.to_s, token, value)
      const el = arguments[0] === 'root' ? document.documentElement : document.getElementById(arguments[0])
      arguments[2] === null ? el.style.removeProperty(arguments[1]) : el.style.setProperty(arguments[1], arguments[2])
    JS
  end

  # Walks the table a page at a time, so the four docs pages are each visited once.
  def assert_boxes(unit)
    CONTROLS.group_by { |_, spec| spec[:page] }.each do |docs_page, controls|
      visit send("#{docs_page}_path")
      disable_transitions
      yield if block_given?

      controls.each { |name, spec| assert_box(name, spec, unit) }
    end
  end

  def assert_box(name, spec, unit)
    measured = metrics_of(locate(spec))

    expected_lengths(spec, unit).each do |metric, expected|
      assert_in_delta expected, measured.fetch(metric.to_s), 0.1,
                      "#{name}'s #{metric.to_s.tr('_', ' ')} is #{measured.fetch(metric.to_s)}px, " \
                      "not the #{expected}px it rendered in v0.3.0 (spacing unit #{unit}px)"
    end

    assert_in_delta TEXT_SM, measured['fontSize'], 0.1, "#{name}'s font size moved"
    assert_in_delta TEXT_SM_LINE_HEIGHT, measured['lineHeight'], 0.1, "#{name}'s line height moved"
  end

  # Spacing units out of the table, pixels in -- and paddingX/paddingY expanded into the four
  # sides they stand for, so a change to any one of them is named in the failure.
  def expected_lengths(spec, unit)
    lengths = { height: spec[:height], width: spec[:width], min_height: spec[:min_height],
                padding_top: spec[:padding_y], padding_bottom: spec[:padding_y],
                padding_left: spec[:padding_left] || spec[:padding_x],
                padding_right: spec[:padding_right] || spec[:padding_x] }

    lengths.compact.transform_values { |units| units * unit }
  end

  def locate(spec)
    return find(spec[:selector], exact_text: spec[:text]) if spec[:text]

    find(spec[:selector], visible: :all)
  end

  # One read per control: the rendered box, plus the computed lengths a class could move
  # without changing the box on a page this narrow. min-height is `none` on most controls,
  # which parses to NaN; that reads as 0 and is only asserted where the table names it.
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
          fontSize: px(style.fontSize), lineHeight: px(style.lineHeight)
        }
      })(arguments[0])
    JS
  end
end
