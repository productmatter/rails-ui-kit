# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# Constraint validation is the platform's, and Select's job is not to lose it: a required Select
# left blank blocks its form before any request is made, and the browser's focus lands somewhere
# the user can act on (ui-select § Behavior, items 6 and 12).
class SelectValidationTest < ApplicationSystemTestCase
  include SelectHelpers

  ID = 'trip_city'

  setup do
    visit select_path
    disable_transitions
    page.execute_script("document.getElementById('#{ID}-combobox').scrollIntoView({ block: 'center' })")
    page.execute_script(<<~JS)
      window.__requests = []
      document.addEventListener('turbo:before-fetch-request', (event) => {
        window.__requests.push(String(event.detail.url))
      })
    JS
  end

  test 'SV1: a required Select left blank blocks submission with no request sent' do
    assert_equal '', select_value(ID)
    assert page.evaluate_script("document.getElementById('#{ID}').validity.valueMissing"),
           'the select does not report itself invalid, so nothing is blocking the form'

    find('#select-round-trip-submit').click

    assert_empty page.evaluate_script('window.__requests'), 'the browser sent the request anyway'
    assert_no_selector '#select-round-trip-result'
  end

  test 'SV2: the focus the browser puts on the invalid select is forwarded to the combobox' do
    find('#select-round-trip-submit').click

    assert_focus_on_combobox ID, 'focus was left on a select the user cannot see'
    # And the control is operable from there, so the user can fix what the browser complained about.
    press :enter
    assert_popup ID, 'open'
  end

  test 'SV3: choosing a value clears the invalid state and lets the form through' do
    find('#select-round-trip-submit').click
    assert_focus_on_combobox ID

    press :enter
    press :arrow_down
    press :arrow_down
    press :enter
    assert_equal 'berlin', select_value(ID)
    assert_not page.evaluate_script("document.getElementById('#{ID}').validity.valueMissing")

    find('#select-round-trip-submit').click
    assert_selector '#select-round-trip-result', text: 'berlin'
    assert_equal 1, page.evaluate_script('window.__requests').size
  end

  test 'SV4: a server-side error reaches both renderings of the control' do
    focus_combobox(ID)
    press :enter
    press :end
    press :enter
    find('#select-round-trip-submit').click
    assert_selector '[data-slot=field-error]', text: 'is not available this week'

    assert_selector "select##{ID}[aria-invalid='true'][aria-describedby~='#{ID}-error']", visible: :all
    assert_selector "##{ID}-combobox[aria-invalid='true'][aria-describedby~='#{ID}-error']"
  end
end
