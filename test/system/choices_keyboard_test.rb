# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'choices_helpers'

# The keyboard and pointer model, with no kit controller anywhere near it: native radios and
# checkboxes already own every key here, which is why Choices adds none (ui-choices § Behavior,
# item 14, and § Business rules, rules 4 and 7). Real keypresses, so what is under test is the
# browser's behaviour in the markup the component renders -- not a dispatched event.
class ChoicesKeyboardTest < ApplicationSystemTestCase
  include ChoicesHelpers

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit choices_path
  end

  def focus(id)
    page.execute_script("document.getElementById(arguments[0]).scrollIntoView({ block: 'center' }); " \
                        'document.getElementById(arguments[0]).focus()', id)
    assert_equal id, focused_id
  end

  test 'CK1 no radio group carries a kit controller, and nothing in a group is focusable but an input' do
    assert_no_selector 'fieldset[role=radiogroup][data-controller]', visible: :all
    assert_no_selector 'fieldset [tabindex]', visible: :all
    assert_no_selector 'fieldset label[tabindex]', visible: :all
  end

  test 'CK2 Tab enters a radio group at the checked radio, and Tab leaves the group' do
    focus 'membership_role_ids_3'
    press :tab

    assert_equal 'membership_plan_starter', focused_id,
                 'Tab entered the radio group somewhere other than the checked radio'

    press :tab
    assert_equal 'choices-round-trip-submit', focused_id, 'Tab did not leave the group in one press'
  end

  test 'CK3 arrow keys move and check inside the group, skip a disabled radio and wrap around' do
    focus 'demo_plan_growth'

    press :arrow_down
    assert_equal 'demo_plan_starter', focused_id, 'ArrowDown did not skip the disabled radio and wrap'
    assert_equal %w[starter], checked_values('fieldset#demo_plan'), 'arrowing did not move the choice'

    press :arrow_up
    assert_equal 'demo_plan_growth', focused_id, 'ArrowUp did not wrap past the disabled radio'
    assert_equal %w[growth], checked_values('fieldset#demo_plan')
  end

  test 'CK4 Space toggles a checkbox and leaves its neighbours alone' do
    focus 'demo_role_ids_2'

    press :space
    assert_equal %w[1 2], checked_values('fieldset#demo_role_ids')

    press :space
    assert_equal %w[1], checked_values('fieldset#demo_role_ids')
    assert_equal 'demo_role_ids_2', focused_id, 'Space moved focus'
  end

  test 'CK5 a click anywhere in a card checks it, and focus lands on the input' do
    { 'the text' => '#card_plan_scale-label', 'the description' => '#card_plan_scale-description',
      'the icon' => "label:has(#card_plan_scale) > span[aria-hidden='true']" }.each do |part, selector|
      page.execute_script("document.querySelector(arguments[0]).scrollIntoView({ block: 'center' })", selector)
      find(selector).click

      assert_equal %w[scale], checked_values('fieldset#card_plan'), "clicking #{part} did not check the card"
      assert_equal 'card_plan_scale', focused_id, "clicking #{part} did not put focus on the input"

      find('#card_plan_growth').click
    end
  end

  test 'CK6 a click on the card padding checks it too, and never focuses the card' do
    card = find('#card_plan_scale').find(:xpath, 'ancestor::label')
    rect = page.evaluate_script('arguments[0].getBoundingClientRect().toJSON()', card)
    assert_operator rect['width'], :>, 0, 'the card has no width, so its geometry proves nothing'

    # The inline-end edge of the card, well past the text column: padding and nothing else.
    page.driver.browser.action
        .move_to_location((rect['x'] + rect['width'] - 4).to_i, (rect['y'] + rect['height'] - 4).to_i)
        .click.perform

    assert_equal %w[scale], checked_values('fieldset#card_plan')
    assert_equal 'input', focused_tag
    assert_equal 'card_plan_scale', focused_id
  end

  test 'CK7 a disabled choice is out of the tab order and cannot be checked by pointer' do
    focus 'demo_plan_growth'
    press :tab

    assert_not_equal 'demo_plan_enterprise', focused_id
    find('#demo_plan_enterprise', visible: :all).click(allow_label_click: false)
    assert_equal %w[growth], checked_values('fieldset#demo_plan')
  end
end
