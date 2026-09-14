# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# Step 2: show -> edit -> show inside the content frame. The frame swaps; the dialog does not.
class ModalTurboNavigationTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  test 'in-modal navigation swaps only the content frame, keeping the same dialog open' do
    open_modal(1)
    mark_dialog
    count_mounts

    within '#modal turbo-frame#project_modal_content' do
      click_on 'Edit'
    end
    assert_selector '#modal turbo-frame#project_modal_content', text: 'Edit project'
    assert_same_dialog
    assert_equal 0, mounts, 'the dialog was re-mounted by a frame navigation'

    within '#modal turbo-frame#project_modal_content' do
      click_on 'Cancel'
    end
    assert_selector '#modal turbo-frame#project_modal_content', text: 'Brand system'
    assert_same_dialog
    assert_equal 0, mounts
    assert_state '#modal dialog', 'open'
  end

  test 'focus stays inside the dialog across a content frame swap' do
    open_modal(1)
    track_frame_renders

    within '#modal turbo-frame#project_modal_content' do
      click_on 'Edit'
    end
    assert_focus_in_dialog_after_frame_render(1)

    within '#modal turbo-frame#project_modal_content' do
      click_on 'Cancel'
    end
    assert_focus_in_dialog_after_frame_render(2)
  end

  test 'the modal keeps its name through the swap, and the id it names is rendered in both states' do
    open_modal(1)
    assert_named 'Acme rebrand'

    within '#modal turbo-frame#project_modal_content' do
      click_on 'Edit'
    end
    assert_selector '#modal turbo-frame#project_modal_content', text: 'Edit project'
    assert_named 'Edit project'
  end

  test 'the page behind stays locked and untouched while the frame navigates' do
    open_modal(1)

    within '#modal turbo-frame#project_modal_content' do
      click_on 'Edit'
    end
    assert_selector '#modal turbo-frame#project_modal_content', text: 'Edit project'

    assert scroll_locked?
    # A frame navigation is not a page visit: the list behind the modal is exactly as it was.
    assert_selector '#project_1', text: 'Acme rebrand', visible: :all
  end
end
