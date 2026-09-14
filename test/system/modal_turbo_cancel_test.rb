# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# Step 6: closing without saving. A close button, Escape and a backdrop click each close the
# modal with no server request -- and with a dirty form, only after the person says so.
class ModalTurboCancelTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  test 'the close button closes with no request, releases the scroll lock and restores focus' do
    open_modal(1)
    count_requests
    record_dialog_states

    within('#modal') { click_on 'Close' }

    no_modal
    assert_equal 0, requests, 'closing a modal asked the server something'
    assert_includes dialog_states, 'closing'
    assert_scroll_unlocked
    assert_equal 'open_project_1', focused_id
  end

  test 'Escape closes the modal and restores focus to the trigger' do
    open_modal(1)
    count_requests

    press :escape

    no_modal
    assert_equal 0, requests
    assert_scroll_unlocked
    assert_equal 'open_project_1', focused_id
  end

  test 'a backdrop click closes the modal and restores focus to the trigger' do
    open_modal(1)
    count_requests

    click_at(*point_outside_dialog)

    no_modal
    assert_equal 0, requests
    assert_scroll_unlocked
    assert_equal 'open_project_1', focused_id
  end

  test 'a dirty form is asked about first, and refusing keeps the modal open' do
    open_modal(1, trigger: 'edit')
    fill_in 'Name', with: 'A name never saved'

    press :escape

    assert_selector 'dialog[open]#default-confirm', text: 'unsaved changes'
    find('#default-confirm button[value="cancel"]').click

    assert_state '#modal dialog', 'open'
    assert scroll_locked?
  end

  test 'a dirty form that is confirmed closes the modal and discards the change' do
    open_modal(1, trigger: 'edit')
    fill_in 'Name', with: 'A name never saved'

    press :escape
    assert_selector 'dialog[open]#default-confirm'
    find('#default-confirm button[value="confirm"]').click

    no_modal
    assert_scroll_unlocked
    assert_selector '#project_1', text: 'Acme rebrand'
  end
end
