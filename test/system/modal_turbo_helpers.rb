# frozen_string_literal: true

require_relative 'ui_overlay_helpers'
require_relative 'modal_turbo_probes'

# Shared setup and vocabulary for the Modal + Turbo lifecycle tests, which all drive the same demo
# endpoints (examples/app/controllers/projects_controller.rb) from the same page. The probes they
# measure with are in ModalTurboProbes.
module ModalTurboHelpers
  include UiOverlayHelpers
  include ModalTurboProbes

  def self.included(base)
    base.setup do
      Project.reset!
      visit modal_turbo_path
    end
  end

  # The open modal's dialog. `visible: :all` is never used: a modal that is not laid out is not
  # open, whatever its attributes say.
  def dialog
    find('#modal dialog')
  end

  def open_modal(project_id, trigger: 'open')
    find("##{trigger}_project_#{project_id}").click
    assert_modal_open
  end

  # assert_state reads the element, so it can only run once the response has put one there:
  # Capybara's own waiting assertion comes first, every time.
  def assert_modal_open(content_frame: nil)
    assert_selector content_frame ? "#modal turbo-frame##{content_frame}" : '#modal dialog'
    assert_state '#modal dialog', 'open'
  end

  # The invitation modal, opened from inside the project modal: the stream link that replaces one
  # modal with the next. The wait is on the invitation's own content frame, never on its text --
  # the project modal carries the words "Invite a teammate" too, so a text wait would be
  # satisfied by the state before the response.
  def open_invitation_modal(from_project: 1)
    open_modal(from_project)
    within('#modal') { click_on 'Invite a teammate' }
    assert_modal_open(content_frame: 'invitation_modal_content')
  end

  # The read-only frame-target demo. Its own frame, never the layout's shared container.
  def open_activity_modal(project_id)
    find("#activity_project_#{project_id}").click
    assert_selector 'turbo-frame#project_activity_modal dialog'
    assert_state 'turbo-frame#project_activity_modal dialog', 'open'
  end

  def open_invitation_modal_from_page
    find('#invite').click
    assert_modal_open(content_frame: 'invitation_modal_content')
  end

  # Every modal in the demo is named through Ui::ModalComponent's aria: keyword, and the id it
  # names has to resolve to text that is actually rendered.
  def assert_named(expected)
    labelledby = dialog['aria-labelledby']
    assert labelledby.present?, 'the dialog has no accessible name'
    assert_selector "##{labelledby}", text: expected
  end

  def no_modal
    assert_no_selector '#modal [data-controller~="ui--modal"]'
  end

  # The lock is released as the modal's element leaves the page, which is a Stimulus disconnect --
  # one tick after the element itself is gone. Sampling it the moment the dialog disappears passes
  # on a fast machine and fails on a slow one, so this waits the way every other assertion does.
  def assert_scroll_unlocked
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.02 while scroll_locked? }
    assert_not scroll_locked?
  rescue Timeout::Error
    flunk 'the page is still scroll-locked'
  end

  def stream(html)
    page.execute_script('Turbo.renderStreamMessage(arguments[0])', html)
  end
end
