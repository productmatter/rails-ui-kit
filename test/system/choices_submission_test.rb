# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'choices_helpers'

# Choices is a form control or it is nothing (ui-choices § Business rules, rules 1 and 2). These
# drive a real POST to a real Rails action and read what the server received, rather than
# trusting the markup's account of itself.
class ChoicesSubmissionTest < ApplicationSystemTestCase
  include ChoicesHelpers

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit choices_path
    page.execute_script("document.getElementById('choices-round-trip-submit').scrollIntoView({ block: 'center' })")
  end

  # The result element outlives every response, so reading its text alone would happily match the
  # response before this one. What is waited for instead is an element the previous response did
  # not draw -- each carries its own number.
  def submit_and_wait
    drawn_by = submission_token
    find('#choices-round-trip-submit').click
    assert_selector "#choices-round-trip-result:not([data-submission='#{drawn_by}'])"
  end

  def submission_token
    page.evaluate_script(<<~JS)
      (() => {
        const result = document.querySelector('#choices-round-trip-result')
        return result ? result.dataset.submission : 'none'
      })()
    JS
  end

  def role(value)
    find("#membership_role_ids_#{value}", visible: :all)
  end

  test 'CB1 checking two boxes and submitting posts both ids' do
    role(2).click
    role(3).click
    assert_equal %w[1 2 3], checked_values('fieldset#membership_role_ids')

    submit_and_wait

    assert_selector '#choices-round-trip-result', text: '1, 2, 3'
    # The 422-free path still re-renders from the server, with the submitted choices checked.
    assert_equal %w[1 2 3], checked_values('fieldset#membership_role_ids')
  end

  test 'CB2 unchecking every box posts the blank entry, and the server sees no roles' do
    role(1).click
    assert_empty checked_values('fieldset#membership_role_ids')
    assert_equal [['membership[role_ids][]', ''], ['membership[plan]', ''], ['membership[plan]', 'starter']],
                 form_entries('#choices-round-trip form').reject { |name, _| name.start_with?('authenticity') },
                 'the blank entry Rails prepends is what clears an association'

    submit_and_wait

    assert_selector '#choices-round-trip-result', text: 'no roles'
  end

  test 'CB3 a 422 shows the submitted choices checked, with the error on the group' do
    role(1).click
    find('#membership_plan_starter', visible: :all).click
    role(3).click

    submit_and_wait

    assert_selector '#choices-round-trip-result', text: '3'
    assert_no_selector '#choices-round-trip [data-slot=field-error]'

    # Now clear the roles: the model says a membership needs one, so the 422 comes back.
    role(3).click
    submit_and_wait

    assert_selector '[data-slot=field-error]', text: 'needs at least one role'
    assert_selector "fieldset#membership_role_ids[aria-invalid='true']", visible: :all
    assert_selector 'fieldset#membership_role_ids[aria-describedby~=membership_role_ids-error]', visible: :all
    assert_equal %w[starter], checked_values('fieldset#membership_plan'),
                 'the 422 re-render lost the radio the user chose'
  end

  test 'CB4 a locked, checked value posts through its carrier while the user unchecks the rest' do
    find('#locked_role_ids_2', visible: :all).click

    assert_equal %w[1], checked_values('#choices-locked-preview'),
                 'the locked box stays checked; only the enabled one changed'
    assert_selector '#locked_role_ids_1[disabled]', visible: :all
    # What the browser would post: the disabled input contributes nothing, and the carrier beside
    # it carries the locked value instead. Rails' own markup would post only the blank entry here,
    # and the save would delete the role the form showed as checked.
    assert_equal [['locked[role_ids][]', ''], ['locked[role_ids][]', '1']],
                 form_entries('#choices-locked-form')
  end

  test 'CB5 the whole card is the target: clicking the text checks the input under it' do
    within('#choices-card-preview') do
      find('#card_plan_starter-description').click
    end

    assert_equal %w[starter], checked_values('#choices-card-preview fieldset')
    assert_equal 'input', focused_tag, 'focus landed on something other than the input'
  end
end
