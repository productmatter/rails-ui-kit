# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# Select is a form control or it is nothing (ui-select § Business rules, rule 2). These drive a
# real POST to a real Rails action and read what the server received, rather than trusting the
# widget's own account of itself.
class SelectFormSubmissionTest < ApplicationSystemTestCase
  include SelectHelpers

  ID = 'trip_city'

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit select_path
    disable_transitions
    page.execute_script("document.getElementById('#{ID}-combobox').scrollIntoView({ block: 'center' })")
  end

  # The result element outlives every response, so reading its text alone would happily match the
  # response before this one. What is waited for instead is an element the previous response did
  # not draw -- each carries its own number -- with the text this one should have. A read that
  # lands early now fails rather than passing on stale content.
  def submit_and_assert_received(value)
    drawn_by = submission_token
    find('#select-round-trip-submit').click
    assert_selector "#select-round-trip-result:not([data-submission='#{drawn_by}'])", text: value
  end

  def submit_and_wait
    drawn_by = submission_token
    find('#select-round-trip-submit').click
    assert_selector "#select-round-trip-result:not([data-submission='#{drawn_by}'])"
  end

  # Which response drew what is on screen now; "none" before the first one.
  def submission_token
    page.evaluate_script(<<~JS)
      (() => {
        const result = document.querySelector('#select-round-trip-result')
        return result ? result.dataset.submission : 'none'
      })()
    JS
  end

  test 'SF1: a value chosen by keyboard is what the server receives' do
    focus_combobox(ID)
    press :enter
    assert_popup ID, 'open'
    press :arrow_down
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
    find("##{ID}-option-3").click
    assert_equal 'london', select_value(ID)

    submit_and_assert_received 'london'
  end

  test 'SF3: a 422 re-render shows the error and the submitted value still selected' do
    focus_combobox(ID)
    press :enter
    press :end
    press :enter
    assert_equal 'tokyo', select_value(ID)

    submit_and_wait

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
