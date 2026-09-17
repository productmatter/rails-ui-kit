# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# Step 7: a stream that updates the container while a modal is open replaces it. One dialog
# afterwards, the page locked throughout, and focus still owed to the trigger that started it.
class ModalTurboReplaceTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  test 'a stream replacing an open modal leaves exactly one dialog, and it is the new one' do
    open_modal(1)
    mark_dialog('first')

    within('#modal') { click_on 'Invite a teammate' }
    assert_modal_open(content_frame: 'invitation_modal_content')

    assert_equal 1, page.evaluate_script("document.querySelectorAll('#modal dialog').length")
    assert_no_selector "#modal dialog[data-probe='first']"
    assert page.evaluate_script("document.querySelector('#modal dialog').matches(':modal')")
    assert page.evaluate_script("document.querySelector('#modal dialog').contains(document.activeElement)"),
           'focus is not inside the modal that replaced the first'
  end

  test 'the page stays scroll-locked through the replacement, frame by frame' do
    open_modal(1)
    assert scroll_locked?
    sample_scroll_lock

    within('#modal') { click_on 'Invite a teammate' }
    assert_modal_open(content_frame: 'invitation_modal_content')
    samples = stop_sampling_scroll_lock

    assert_operator samples.size, :>, 1, 'the sampler never ran'
    assert_equal ['fixed'], samples.uniq, "the page came unlocked mid-replacement: #{samples.uniq.inspect}"
    assert scroll_locked?
  end

  test 'closing the second modal returns focus to the element that opened the first' do
    open_modal(1)
    within('#modal') { click_on 'Invite a teammate' }
    assert_modal_open(content_frame: 'invitation_modal_content')

    within('#modal') { click_on 'Cancel' }

    no_modal
    assert_scroll_unlocked
    assert_equal 'open_project_1', focused_id
  end

  private

  # The lock is released and re-taken inside one task during a replacement, so "still locked
  # afterwards" would pass even if a frame had been painted unlocked. This reads <body> once per
  # animation frame instead: every frame the browser actually paints.
  def sample_scroll_lock
    page.execute_script(<<~JS)
      window.__samples = []
      window.__sampling = true
      const sample = () => {
        window.__samples.push(document.body.style.position)
        if (window.__sampling) requestAnimationFrame(sample)
      }
      requestAnimationFrame(sample)
    JS
  end

  def stop_sampling_scroll_lock
    samples = page.evaluate_script('window.__samples')
    page.execute_script('window.__sampling = false')

    samples
  end
end
