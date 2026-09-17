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

  test 'CL4 every choice is at least its step control height, and at least 24px' do
    page.execute_script("document.getElementById('choices-sizes-preview').scrollIntoView({ block: 'center' })")

    { 'sm' => '--control-height-sm', 'default' => '--control-height', 'lg' => '--control-height-lg' }
      .each do |step, token|
      # Resolved by laying a probe out at that token's height, rather than read as a custom
      # property: what matters is the length the browser computes from it.
      expected = page.evaluate_script(<<~JS, token)
        (() => {
          const probe = document.createElement('div')
          probe.style.height = `var(${arguments[0]})`
          document.body.appendChild(probe)
          const height = probe.getBoundingClientRect().height
          probe.remove()
          return height
        })()
      JS
      assert_operator expected, :>, 0, "#{token} did not resolve"

      heights = page.evaluate_script(<<~JS, step)
        Array.from(document.querySelectorAll(`#size_${arguments[0]}_plan label`))
             .map((label) => label.getBoundingClientRect().height)
      JS
      assert_operator heights.length, :>, 0
      heights.each do |height|
        assert_operator height, :>=, expected - 0.5, "a #{step} choice is shorter than #{token}"
        assert_operator height, :>=, 24, "a #{step} choice is under the 24px target minimum"
      end
    end
  end
end
