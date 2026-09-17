# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# The second blessed pattern, and its limits: a read-only modal rendered into a turbo-frame of
# its own. It opens and closes like any other, and Back never brings it back.
class ModalTurboFrameTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  FRAME = 'turbo-frame#project_activity_modal'

  test 'a frame-target link opens a read-only modal inside its own frame' do
    open_activity_modal(1)

    assert_selector "#{FRAME} dialog", text: 'Acme rebrand created'
    assert page.evaluate_script("document.querySelector('#{FRAME} dialog').matches(':modal')")
    # The layout's shared container is untouched: the two patterns never share a container.
    assert_no_selector '#modal dialog'
    assert scroll_locked?
  end

  test 'the frame modal is named and closes cleanly, leaving its frame in place' do
    open_activity_modal(1)

    dialog = find("#{FRAME} dialog")
    assert_equal 'project_activity_title', dialog['aria-labelledby']
    assert_selector '#project_activity_title', text: 'Activity'

    within(FRAME) { click_on 'Close' }

    assert_no_selector "#{FRAME} dialog"
    assert_selector FRAME, visible: :all
    assert_scroll_unlocked
    assert_equal 'activity_project_1', focused_id
  end

  # The guide tells the reader not to put data-turbo-action="advance" on a link that opens a
  # modal. This is why: the advance visit caches a snapshot as soon as the frame has loaded, and
  # the kit removes an open modal before every cache (so Back can never restore a stuck one). The
  # modal is therefore gone within a frame of opening -- it is not a deep link, it is a flash.
  test 'data-turbo-action="advance" on a modal trigger removes the modal it just opened' do
    page.execute_script("document.getElementById('activity_project_1').setAttribute('data-turbo-action', 'advance')")

    find('#activity_project_1').click

    assert_current_path '/demos/projects/1/activity'
    assert_no_selector "#{FRAME} dialog"
    assert_scroll_unlocked
  end

  test 'Back after opening a frame modal never restores it' do
    open_activity_modal(1)

    # The open dialog's backdrop blocks every click, so the visit is made directly -- the same
    # path a real navigation takes.
    page.execute_script('Turbo.visit(arguments[0])', '/installation')
    assert_selector 'h1', text: 'Installation'

    page.go_back
    assert_selector 'h1', text: 'Modal & Turbo'
    assert_no_selector 'dialog[open]'
    assert_scroll_unlocked

    # And the page still works: the trigger opens a real modal again.
    find('#activity_project_1').click
    assert_selector "#{FRAME} dialog"
    assert page.evaluate_script("document.querySelector('#{FRAME} dialog').matches(':modal')")
  end
end
