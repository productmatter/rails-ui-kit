# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# Step 5: a destructive action inside the modal. The kit's ConfirmDialog opens above it, and the
# answer decides whether the modal closes or carries on.
class ModalTurboDeleteTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  test 'confirming a delete closes the modal, removes the row and shows a toast' do
    open_modal(2)
    record_dialog_states

    within('#modal') { click_on 'Delete' }
    assert_selector 'dialog[open]#default-confirm', text: 'Delete Q3 campaign?'
    find('#default-confirm button[value="confirm"]').click

    no_modal
    assert_no_selector '#project_2'
    assert_selector '#project_1'
    assert_selector '#ui-toasts [data-slot=toast-description]', text: 'Q3 campaign deleted.'
    assert_includes dialog_states, 'closing', 'the modal was removed rather than animated out'
    assert_scroll_unlocked
  end

  test 'the confirmation opens above the modal, in the top layer' do
    open_modal(2)
    within('#modal') { click_on 'Delete' }

    assert_selector 'dialog[open]#default-confirm'
    assert page.evaluate_script("document.getElementById('default-confirm').matches(':modal')")
    assert page.evaluate_script("document.querySelector('#modal dialog').matches(':modal')"),
           'the modal underneath left the top layer while the confirmation was open'
  end

  test 'cancelling the confirmation leaves the modal open with focus back inside it' do
    open_modal(2)
    within('#modal') { click_on 'Delete' }
    assert_selector 'dialog[open]#default-confirm'

    find('#default-confirm button[value="cancel"]').click

    assert_no_selector 'dialog[open]#default-confirm'
    assert_state '#modal dialog', 'open'
    assert page.evaluate_script("document.querySelector('#modal dialog').contains(document.activeElement)"),
           'focus did not come back inside the modal'
    assert_selector '#project_2', text: 'Q3 campaign'
    assert scroll_locked?
  end
end
