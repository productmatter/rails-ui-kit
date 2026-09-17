# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'choices_helpers'

# Measured colour, not class names (ui-choices § Behavior, items 15 and 16). The invalid-beats-
# checked rule in particular cannot be read off a class list: the two selectors compile to equal
# specificity, so what settles it is which colour the browser actually paints.
class ChoicesVariantTest < ApplicationSystemTestCase
  include ChoicesHelpers

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1600)
    visit choices_path
    disable_transitions
    page.execute_script("document.getElementById('choices-card-preview').scrollIntoView({ block: 'center' })")
  end

  def card_of(id)
    find("##{id}").find(:xpath, 'ancestor::label')
  end

  def token(name)
    page.evaluate_script(<<~JS, name)
      (() => {
        const probe = document.createElement('span')
        probe.style.color = `var(${arguments[0]})`
        document.body.appendChild(probe)
        const color = getComputedStyle(probe).color
        probe.remove()
        return color
      })()
    JS
  end

  def border_color(element)
    page.evaluate_script('getComputedStyle(arguments[0]).borderTopColor', element)
  end

  test 'CP1 a checked card takes the primary border and an unchecked one keeps the input boundary' do
    assert_equal token('--primary'), border_color(card_of('card_plan_growth'))
    assert_equal token('--input'), border_color(card_of('card_plan_starter'))
  end

  test 'CP2 inside an invalid group the destructive border beats the checked one' do
    page.execute_script("document.getElementById('card_plan').setAttribute('aria-invalid', 'true')")

    assert_equal token('--destructive'), border_color(card_of('card_plan_growth')),
                 'the checked card kept its primary border inside an invalid group'
    assert_equal token('--destructive'), border_color(card_of('card_plan_starter'))
  end

  test 'CP3 a card rings for the keyboard and not after a click' do
    input = find('#card_plan_scale')
    card = card_of('card_plan_scale')

    card.click
    assert_equal 'card_plan_scale', focused_id
    assert_equal 'none', page.evaluate_script('getComputedStyle(arguments[0]).outlineStyle', card),
                 'a pointer click rang the card'

    focus_visibly(input)
    outline = page.evaluate_script(<<~JS, card)
      (() => {
        const style = getComputedStyle(arguments[0])
        return { style: style.outlineStyle, width: style.outlineWidth, color: style.outlineColor }
      })()
    JS
    assert_not_equal 'none', outline['style'], 'the card did not ring for the keyboard'
    assert_equal 2, outline['width'].to_f
    assert_equal token('--ring'), outline['color']
    assert_equal 'none', page.evaluate_script('getComputedStyle(arguments[0]).outlineStyle', input),
                 "the input's own outline is suppressed in the card variant"
  end

  test 'CP4 the list variant rings the input itself' do
    page.execute_script("document.getElementById('choices-preview').scrollIntoView({ block: 'center' })")
    input = find('#demo_plan_starter')

    focus_visibly(input)
    outline = outline_of(input)

    assert_not_equal 'none', outline['style']
    assert_operator outline['width'].to_f, :>=, 2
    assert_equal token('--ring'), outline['color']
  end

  test 'CP5 the indicator boundary, the checked card border and the ring reach 3:1 on every surface' do
    preview = find('#choices-card-preview')
    unchecked = find('#card_plan_starter')
    checked_card = card_of('card_plan_growth')

    each_token_surface(preview) do |mode, surface|
      boundary = contrast_ratio(color_of(:border, unchecked), color_of(:background, preview))
      assert_operator boundary, :>=, 3,
                      "the indicator boundary is #{boundary.round(2)}:1 on #{surface} in #{mode} mode"

      checked = contrast_ratio(color_of(:border, checked_card), color_of(:background, preview))
      assert_operator checked, :>=, 3,
                      "the checked card border is #{checked.round(2)}:1 on #{surface} in #{mode} mode"
    end
    use_dark_mode(false)
  end

  test 'CP6 the focus ring and the check mark survive forced colours' do
    card = card_of('card_plan_scale')
    input = find('#card_plan_scale')

    # Not assert_focus_outline_in_forced_colors: that focuses the element it measures, and the
    # card is a <label>, which is never focusable. The ring is the card's, drawn from the input's
    # own :focus-visible, so the focus and the measurement are on different elements here.
    emulate_forced_colors(true)
    assert_equal 'none', page.evaluate_script('getComputedStyle(arguments[0]).outlineStyle', card)

    focus_visibly(input)
    outline = page.evaluate_script(<<~JS, card)
      (() => {
        const style = getComputedStyle(arguments[0])
        return { style: style.outlineStyle, width: style.outlineWidth, color: style.outlineColor }
      })()
    JS
    assert_not_equal 'none', outline['style'], 'the card loses its focus indicator in forced colours'
    assert_operator outline['width'].to_f, :>=, 2
    assert_not_equal 'rgba(0, 0, 0, 0)', outline['color']

    page.execute_script("document.getElementById('demo_role_ids_1').scrollIntoView({ block: 'center' })")
    mark = find('label:has(#demo_role_ids_1) svg', visible: :all)

    # A mark drawn as a background would go with the fill in forced colours; this one is a stroke
    # in currentColor, which becomes CanvasText.
    assert_equal 'none', page.evaluate_script('getComputedStyle(arguments[0]).fill', mark)
    assert_equal 1, page.evaluate_script('Number(getComputedStyle(arguments[0]).opacity)', mark),
                 'the checked mark is not shown'
    assert_operator contrast_ratio(color_of(:text, mark), color_of(:background, find('#demo_role_ids_1'))), :>=, 3
  ensure
    emulate_forced_colors(false)
  end
end
