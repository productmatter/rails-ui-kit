# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'choices_helpers'

# What a screen reader actually meets, read out of Chrome's own accessibility tree rather than
# inferred from attributes (ui-choices § Behavior, item 10, and § Business rules, rules 6 and 8).
class ChoicesAccessibilityTest < ApplicationSystemTestCase
  include ChoicesHelpers

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1600)
    visit choices_path
  end

  # ax_node (Chrome's accessibility tree for one element) comes from ApplicationSystemTestCase's
  # BrowserHelpers.
  def ax(selector, key)
    ax_node(selector)&.dig(key, 'value')
  end

  def ax_property(selector, name)
    ax_node(selector)&.fetch('properties', [])&.find { |property| property['name'] == name }&.dig('value', 'value')
  end

  test 'CA1 a radio group is a radiogroup named by the Field label, and each radio names its choice' do
    assert_equal 'radiogroup', ax('fieldset#demo_plan', 'role')
    assert_equal 'Plan', ax('fieldset#demo_plan', 'name')
    assert_equal 'One choice. Enterprise is on request.', ax('fieldset#demo_plan', 'description')

    assert_equal 'radio', ax('#demo_plan_growth', 'role')
    assert_equal 'Growth', ax('#demo_plan_growth', 'name'), 'the wrapping label named the radio with all its text'
    assert_equal 'true', ax_property('#demo_plan_growth', 'checked')
    assert_equal 'false', ax_property('#demo_plan_starter', 'checked')
    assert_equal true, ax_property('#demo_plan_enterprise', 'disabled')
  end

  test 'CA2 a checkbox group is a group, and a choice description reaches its own input' do
    assert_equal 'group', ax('fieldset#demo_role_ids', 'role')
    assert_equal 'Roles', ax('fieldset#demo_role_ids', 'name')

    assert_equal 'checkbox', ax('#demo_role_ids_1', 'role')
    assert_equal 'Admin', ax('#demo_role_ids_1', 'name')
    assert_equal 'Can change anything, including billing.', ax('#demo_role_ids_1', 'description')
  end

  test 'CA3 a required checkbox group is described by the hint, and no checkbox claims required' do
    assert_includes ax('fieldset#required_role_ids', 'description').to_s, 'Select at least one option.'
    page.all('#required_role_ids input[type=checkbox]', visible: :all).each do |checkbox|
      assert_nil ax_property("##{checkbox[:id]}", 'required'),
                 'a checkbox claiming required would say every box is required'
    end

    # The radio group beside it needs no hint: `required` on each radio makes the group
    # valueMissing, which Chrome reports in the tree as invalid until one is checked.
    assert_nil ax_property('fieldset#required_plan', 'describedby'),
               'a required radio group needs no hint: each radio already carries required'
    assert_equal 'true', ax_property('#required_plan_starter', 'invalid')
  end

  test 'CA4 a decorative icon is not in the accessibility tree, and the card names only its text' do
    assert_nil ax_node("label:has(#card_plan_growth) > span[aria-hidden='true']")
    assert_equal 'Growth', ax('#card_plan_growth', 'name')
    assert_equal 'Ten projects, unlimited seats.', ax('#card_plan_growth', 'description')
  end

  test 'CA5 an invalid group carries the invalid state and the error, on the group' do
    page.execute_script("document.getElementById('choices-round-trip-submit').scrollIntoView({ block: 'center' })")
    find('#membership_role_ids_1').click
    find('#choices-round-trip-submit').click
    assert_selector '[data-slot=field-error]', text: 'needs at least one role'

    assert_equal 'true', page.evaluate_script(<<~JS)
      document.getElementById('membership_role_ids').getAttribute('aria-invalid')
    JS
    assert_includes ax('fieldset#membership_role_ids', 'description').to_s, 'needs at least one role'
    assert_equal 'true', ax_property('fieldset#membership_role_ids', 'invalid')
  end

  test 'CA6 every preview passes axe, in light and dark mode' do
    previews = %w[#choices-preview #choices-card-preview #choices-required-preview #choices-locked-preview
                  #choices-sizes-preview]

    [false, true].each do |dark|
      use_dark_mode(dark)
      previews.each { |preview| assert_accessible within: preview }
    end
  end

  test 'CA7 a checked, disabled and invalid group still passes axe' do
    page.execute_script("document.getElementById('choices-round-trip-submit').scrollIntoView({ block: 'center' })")
    find('#membership_role_ids_1').click
    find('#choices-round-trip-submit').click
    assert_selector '[data-slot=field-error]'

    page.execute_script(<<~JS)
      document.getElementById('card_plan').setAttribute('disabled', 'disabled')
      document.getElementById('card_plan').setAttribute('aria-invalid', 'true')
    JS

    assert_accessible within: '#choices-round-trip-preview'
    assert_accessible within: '#choices-card-preview'
  end
end
