# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'choices_helpers'

# Long text at a narrow width (ui-choices § Behavior, items 17 and 18, and ui-localization
# § Behavior, item 12: controls truncate, lists wrap). A fieldset's UA min-inline-size is the
# trap here -- it holds a group open at its longest word, and Tailwind's preflight doesn't reset
# it -- so the measurements are taken at a phone width where that shows.
class ChoicesLayoutTest < ApplicationSystemTestCase
  include ChoicesHelpers

  LONG_TEXT = 'Everything in Growth, plus priority support, a dedicated success manager and ' \
              'an uptime commitment we will actually put in writing for you.'
  UNBREAKABLE = 'Zahlungsbedingungenundlieferbedingungenfuergrosskunden'

  setup do
    page.driver.browser.manage.window.resize_to(320, 900)
    visit choices_path
    page.execute_script("document.getElementById('choices-card-preview').scrollIntoView({ block: 'center' })")
  end

  def rect(selector)
    box = page.evaluate_script('document.querySelector(arguments[0]).getBoundingClientRect().toJSON()', selector)
    assert_operator box['width'], :>, 0, "#{selector} has no width, so its geometry proves nothing"
    assert_operator box['height'], :>, 0, "#{selector} has no height, so its geometry proves nothing"
    box
  end

  def lengthen(id, text)
    page.execute_script(<<~JS, id, text)
      document.getElementById(arguments[0] + '-label').textContent = arguments[1]
      document.getElementById(arguments[0] + '-description').textContent = arguments[1]
    JS
  end

  test 'CL1 a long choice and an unbreakable token wrap inside the group, with nothing overflowing' do
    lengthen('card_plan_scale', "#{LONG_TEXT} #{UNBREAKABLE}")

    group = rect('fieldset#card_plan')
    card = rect('label:has(#card_plan_scale)')

    assert_operator card['right'], :<=, group['right'] + 1, 'a card overflows the group it is in'
    assert_equal 0, page.evaluate_script(<<~JS), 'the group scrolls horizontally, so something inside it is too wide'
      (() => {
        const group = document.getElementById('card_plan')
        return Math.max(0, group.scrollWidth - group.clientWidth)
      })()
    JS
    assert_equal 0, page.evaluate_script(<<~JS), 'the text overflows its own card'
      (() => {
        const card = document.querySelector('label:has(#card_plan_scale)')
        return Math.max(0, card.scrollWidth - card.clientWidth)
      })()
    JS
  end

  test 'CL2 the fieldset is not held open at its longest word by the UA min-inline-size' do
    lengthen('card_plan_scale', UNBREAKABLE)

    assert_equal 'min-content', page.evaluate_script(<<~JS), 'the UA rule this resets is gone; check item 18 still holds'
      (() => {
        const probe = document.createElement('fieldset')
        document.body.appendChild(probe)
        const value = getComputedStyle(probe).minInlineSize
        probe.remove()
        return value
      })()
    JS
    assert_equal '0px', page.evaluate_script("getComputedStyle(document.getElementById('card_plan')).minInlineSize")
  end

  test 'CL3 the indicator keeps its size and stays on the first line of a wrapped choice' do
    lengthen('card_plan_scale', LONG_TEXT)

    indicator = rect('#card_plan_scale')
    text = rect('#card_plan_scale-label')

    assert_in_delta 16, indicator['width'], 0.5, 'the indicator shrank beside long text'
    assert_in_delta 16, indicator['height'], 0.5
    assert_operator text['height'], :>, 20, 'the text did not wrap, so this proves nothing about the indicator'
    assert_operator indicator['top'], :>=, text['top'] - 4
    assert_operator indicator['bottom'], :<=, text['top'] + 24,
                    'the indicator is not aligned with the first line of the text'
  end

  # `size:` changes nothing on Choices (ui-choices § Behavior, item 17), which the unit test proves
  # by rendering every step; what the browser can add is that the floor holds once laid out. Scoped
  # to the fieldset, so the Field's own label, which is not a choice, is not measured.
  test 'CL4 every choice, row or card, is at least the 24px target minimum' do
    { 'a list row' => '#choices-preview fieldset label', 'a card' => '#choices-card-preview fieldset label' }
      .each do |name, selector|
      heights = page.evaluate_script(<<~JS, selector)
        Array.from(document.querySelectorAll(arguments[0])).map((label) => label.getBoundingClientRect().height)
      JS
      assert_operator heights.length, :>, 0, "no #{name} found at #{selector}"
      heights.each { |height| assert_operator height, :>=, 24, "#{name} is under the 24px target minimum" }
    end
  end
end
