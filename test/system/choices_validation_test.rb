# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'choices_helpers'

# "At least one of these" -- the one constraint the browser has no way to express, and the only
# reason `ui--choices` exists (ui-choices § Behavior, item 14). A required radio group is here
# too, because what the controller has to match is the platform's own behaviour beside it.
class ChoicesValidationTest < ApplicationSystemTestCase
  include ChoicesHelpers

  FORM = '#choices-required-form'
  HINT = 'Select at least one option.'

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit choices_path
    page.execute_script("document.querySelector('#{FORM}').scrollIntoView({ block: 'center' })")
  end

  def submit
    mark = mark_document
    find('#choices-required-submit').click
    mark
  end

  test 'CV1 a required checkbox group blocks an empty submission, with the chrome string as the message' do
    find('#required_plan_starter').click
    mark = submit

    assert_equal mark, document_mark, 'the form was submitted: no request should have been sent'
    assert_equal HINT, validation_message('#required_role_ids_1')
    assert_equal 'required_role_ids_1', focused_id, 'the browser did not focus the box it reported'
    assert_equal '', validation_message('#required_role_ids_2'),
                 'only the first enabled checkbox carries the constraint'
  end

  test 'CV2 a required radio group blocks an empty submission natively, with no kit controller' do
    find('#required_role_ids_1').click
    mark = submit

    assert_equal mark, document_mark
    assert_equal 'required_plan_starter', focused_id
    assert page.evaluate_script("document.getElementById('required_plan_starter').validity.valueMissing"),
           'the radio group is not valueMissing, so the browser is not enforcing it'
    assert_no_selector 'fieldset#required_plan[data-controller]', visible: :all
  end

  test 'CV3 checking one box clears the constraint, and unchecking it brings it back' do
    find('#required_role_ids_2').click
    assert_equal '', validation_message('#required_role_ids_1')

    find('#required_role_ids_2').click
    assert_equal HINT, validation_message('#required_role_ids_1')
  end

  test 'CV4 a group whose only checked box is locked is satisfied, because the carrier posts it' do
    page.execute_script("document.querySelector('#choices-locked-form').scrollIntoView({ block: 'center' })")
    find('#locked_role_ids_2').click

    assert_equal %w[1], checked_values('#choices-locked-form')
    assert_equal '', validation_message('#locked_role_ids_2'),
                 'a checked, locked box counts as checked: its value is carried'
    assert page.evaluate_script("document.getElementById('choices-locked-form').checkValidity()")
  end

  test 'CV5 a form reset re-derives the constraint after the browser restores the boxes' do
    find('#required_role_ids_1').click
    assert_equal '', validation_message('#required_role_ids_1')

    page.execute_script("document.querySelector('#{FORM}').reset()")

    # The browser restores default checkedness after the reset event, and ui--choices re-derives
    # in the task after that, so this waits the way any Capybara matcher waits rather than
    # reading once and hoping.
    assert_equal HINT, awaited_validation_message('#required_role_ids_1', HINT),
                 'the constraint did not come back after the form was reset'
    assert_empty checked_values("#{FORM} fieldset#required_role_ids")
  end

  # Waits for a validation message to reach `expected`, and returns whatever it holds when the
  # wait ends, so a failure prints what was actually there.
  def awaited_validation_message(selector, expected)
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.02 until validation_message(selector) == expected
    end
    expected
  rescue Timeout::Error
    validation_message(selector)
  end

  test 'CV6 a Turbo Stream replace of the group re-derives the constraint on connect' do
    find('#required_role_ids_1').click
    assert_equal '', validation_message('#required_role_ids_1')

    page.execute_script(<<~JS)
      const group = document.getElementById('required_role_ids')
      const wrapper = group.closest('[data-slot=field]')
      wrapper.id = 'choices-stream-target'
      group.querySelectorAll('input[type=checkbox]').forEach((box) => box.removeAttribute('checked'))
      Turbo.renderStreamMessage(
        `<turbo-stream action="replace" target="choices-stream-target"><template>${wrapper.outerHTML}</template></turbo-stream>`
      )
    JS

    assert_selector '#choices-stream-target #required_role_ids_1'
    assert_empty checked_values('#required_role_ids')
    assert_equal HINT, validation_message('#required_role_ids_1'),
                 'the replaced group did not re-derive its constraint on connect'
  end

  test 'CV7 with the hint translated, the browser reports the translated message' do
    page.execute_script(<<~JS, HINT)
      document.getElementById('required_role_ids-required').textContent = 'Wähle mindestens eine Option.'
      document.getElementById('required_role_ids_1').dispatchEvent(new Event('change', { bubbles: true }))
    JS

    assert_equal 'Wähle mindestens eine Option.', validation_message('#required_role_ids_1'),
                 'the message is read from the hint, so the string has one source'
  end
end
