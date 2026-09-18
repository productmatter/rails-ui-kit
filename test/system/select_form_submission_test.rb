# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# Select is a form control or it is nothing (ui-select § Business rules, rule 2). These drive a
# real POST to a real Rails action and read what the server received, rather than trusting the
# widget's own account of itself.
class SelectFormSubmissionTest < ApplicationSystemTestCase
  include SelectHelpers

  ID = 'trip_city'
  SUBMIT = '#select-round-trip-submit'
  RESULT = '#select-round-trip-result'

  setup do
    visit select_path
    disable_transitions
    page.execute_script("document.getElementById('#{ID}-combobox').scrollIntoView({ block: 'center' })")
  end

  # The result element outlives every response, so reading its text alone would happily match the
  # response before this one. What is waited for instead is an element the previous response did
  # not draw -- each carries its own number -- with the text this one should have. A read that
  # lands early now fails rather than passing on stale content. (submission_token and
  # submit_and_wait come from ApplicationSystemTestCase's BrowserHelpers.)
  def submit_and_assert_received(value)
    drawn_by = submission_token(RESULT)
    find(SUBMIT).click
    assert_selector "#{RESULT}:not([data-submission='#{drawn_by}'])", text: value
  end

  test 'SF1: a value chosen by keyboard is what the server receives' do
    focus_combobox(ID)
    press :enter
    assert_popup ID, 'open'
    # One step: the prompt is a placeholder, not a listed option, so the first option is a city.
    press :arrow_down
    press :enter
    assert_equal 'berlin', select_value(ID)

    submit_and_assert_received 'berlin'

    assert_equal 'berlin', select_value(ID), 're-rendering lost the submitted value'
    assert_equal 'Berlin', combobox_label(ID)
  end

  test 'SF2: a value chosen by pointer is what the server receives' do
    combobox(ID).click
    assert_popup ID, 'open'
    find("##{ID}-option-2").click
    assert_equal 'london', select_value(ID)

    submit_and_assert_received 'london'
  end

  test 'SF3: a 422 re-render shows the error and the submitted value still selected' do
    focus_combobox(ID)
    press :enter
    press :end
    press :enter
    assert_equal 'tokyo', select_value(ID)

    submit_and_wait(SUBMIT, RESULT)

    assert_selector '[data-slot=field-error]', text: 'is not available this week'
    assert_equal 'tokyo', select_value(ID), 'the 422 re-render lost the submitted value'
    assert_equal 'Tokyo', combobox_label(ID), 'the combobox did not re-derive from the re-rendered select'
    assert_selector "##{ID}-combobox[aria-invalid='true']"
    assert_equal "#{ID}-description #{ID}-error", combobox(ID)['aria-describedby']
    assert_selector "##{ID}-error", text: 'is not available this week', visible: :all
  end

  test 'SF4: the re-rendered Select still opens, chooses and posts' do
    focus_combobox(ID)
    press :enter
    press :end
    press :enter
    submit_and_assert_received 'tokyo'
    assert_selector '[data-slot=field-error]'

    focus_combobox(ID)
    press :enter
    assert_popup ID, 'open'
    # No prompt option this time: Rails drops it once something is selected, so the first option
    # is a real city.
    press :home
    press :enter
    assert_equal 'berlin', select_value(ID)

    submit_and_assert_received 'berlin'

    assert_no_selector '[data-slot=field-error]'
    assert_no_selector "##{ID}-combobox[aria-invalid='true']"
  end
end
