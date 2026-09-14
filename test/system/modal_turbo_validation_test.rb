# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# Step 3: an invalid submission answers 422 and re-renders the error inside the content frame.
# The modal neither closes nor re-mounts, and the field says it is invalid.
class ModalTurboValidationTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  test 'an invalid submission answers 422 and re-renders the error in the content frame' do
    open_modal(1, trigger: 'edit')
    mark_dialog
    count_mounts
    record_response_statuses

    # A name another project already has: the browser can't know that, so the server is the
    # only thing that can reject it -- which is the point of the 422.
    fill_in 'Name', with: 'Q3 campaign'
    within('#modal') { click_on 'Save' }

    assert_selector '#modal turbo-frame#project_modal_content', text: 'is already taken'
    assert_equal [422], response_statuses,
                 'an invalid submission must answer 422 -- Turbo rejects a 200 HTML response to a form'
    assert_same_dialog
    assert_equal 0, mounts, 'the 422 re-rendered the whole modal instead of the frame'
    assert_state '#modal dialog', 'open'
    assert scroll_locked?
  end

  test 'the invalid field is marked and described by its error' do
    open_modal(1, trigger: 'edit')

    fill_in 'Name', with: 'Q3 campaign'
    within('#modal') { click_on 'Save' }
    assert_selector '#modal turbo-frame#project_modal_content', text: 'is already taken'

    field = find('#modal input[name="project[name]"]')
    assert_equal 'true', field['aria-invalid']
    described_by = field['aria-describedby']
    assert described_by.present?, 'the invalid field describes nothing'
    assert_selector "##{described_by.split.first}", text: 'is already taken'
  end

  test 'correcting the value and saving closes the modal and updates the row' do
    open_modal(1, trigger: 'edit')

    fill_in 'Name', with: 'Q3 campaign'
    within('#modal') { click_on 'Save' }
    assert_selector '#modal turbo-frame#project_modal_content', text: 'is already taken'

    fill_in 'Name', with: 'Acme rebrand v2'
    within('#modal') { click_on 'Save' }

    no_modal
    assert_selector '#project_1', text: 'Acme rebrand v2'
  end
end
