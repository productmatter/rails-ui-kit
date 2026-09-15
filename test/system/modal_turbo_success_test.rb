# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# Step 4: a successful submission. The server closes the modal -- through
# turbo_stream.ui_close_modal where the response is a stream, and through
# ui--modal#closeOnSuccess where it has nothing to render.
class ModalTurboSuccessTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  test 'the stream response closes the modal with its exit animation, updates the row and shows a toast' do
    open_modal(1, trigger: 'edit')
    record_dialog_states

    fill_in 'Name', with: 'Acme rebrand v2'
    within('#modal') { click_on 'Save' }

    no_modal
    assert_selector '#project_1', text: 'Acme rebrand v2'
    assert_selector '#ui-toasts [data-slot=toast-description]', text: 'Acme rebrand v2 saved.'
    assert_includes dialog_states, 'closing', 'the modal was removed rather than animated out'
    assert_scroll_unlocked
    # The same response replaced the row the trigger sat in, so the element focus came from is
    # gone; the id is the app's name for that control, and focus follows it.
    assert_equal 'edit_project_1', focused_id
  end

  test 'the list row is a plain id, not a frame, and only that row is replaced' do
    open_modal(1, trigger: 'edit')
    fill_in 'Name', with: 'Acme rebrand v2'
    within('#modal') { click_on 'Save' }
    assert_selector '#project_1', text: 'Acme rebrand v2'

    assert_selector '#project_2', text: 'Q3 campaign'
    assert_no_selector '#projects turbo-frame'
  end

  test 'closeOnSuccess closes the modal on a success response that carries no stream' do
    open_invitation_modal
    record_dialog_states
    record_response_statuses

    fill_in 'Email', with: 'sam@example.com'
    within('#modal') { click_on 'Send invite' }

    no_modal
    assert_equal [204], response_statuses, 'the success response should carry nothing to render'
    assert_includes dialog_states, 'closing'
    assert_scroll_unlocked
    assert_equal 'open_project_1', focused_id
  end

  test 'closeOnSuccess leaves the modal open on a 422' do
    open_invitation_modal_from_page
    count_mounts
    record_response_statuses

    fill_in 'Email', with: 'sam@example'
    within('#modal') { click_on 'Send invite' }

    assert_selector '#modal turbo-frame#invitation_modal_content', text: 'must be a valid address'
    assert_equal [422], response_statuses
    assert_state '#modal dialog', 'open'
    assert_equal 0, mounts, 'the 422 re-rendered the whole modal instead of the frame'
    assert scroll_locked?
  end

  test 'ui_close_modal does nothing when no modal is open, and the page still works afterwards' do
    stream('<turbo-stream action="ui_close_modal" target="modal"><template></template></turbo-stream>')

    assert_no_selector '#modal dialog'
    open_modal(1)
    assert_selector '#modal dialog', text: 'Acme rebrand'
  end

  test 'a server close is never asked about, even with unsaved changes in the form' do
    open_modal(1, trigger: 'edit')
    fill_in 'Name', with: 'A name never saved'
    # The modal is tracking changes, so its own close would ask first. The server's does not:
    # the change it is closing for has already been accepted.
    assert_selector '#modal [data-controller~="ui--form-change"]'

    stream('<turbo-stream action="ui_close_modal" target="modal"><template></template></turbo-stream>')

    no_modal
    assert_no_selector 'dialog[open]#default-confirm'
    assert_scroll_unlocked
  end

  test 'ui_close_modal leaves the container in place for the next modal' do
    open_modal(1)
    stream('<turbo-stream action="ui_close_modal" target="modal"><template></template></turbo-stream>')
    no_modal

    assert_selector '#modal', visible: :all
    open_modal(2)
    assert_selector '#modal dialog', text: 'Q3 campaign'
  end
end
