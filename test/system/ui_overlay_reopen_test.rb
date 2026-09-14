# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

# Reopening an overlay that has not finished closing. Both cases here are the same shape as the
# race ui--dialog fixed in 7f04f95: work queued by one cycle arriving during the next.
class UiOverlayReopenTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  setup { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test 'reopening from the closed event leaves a genuinely open overlay, not an invisible modal' do
    visit primitives_overlay_path
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'

    # close() queues its `close` event as a task, so an overlay reopened before that task runs
    # gets the previous cycle's close delivered to it. Acted on, it marks a dialog that is
    # rendered and :modal as closed: the page stays inert behind an overlay nothing can see.
    page.execute_script(<<~JS)
      const overlay = document.querySelector('#modal-overlay')
      overlay.addEventListener('ui--overlay:closed', function once() {
        overlay.removeEventListener('ui--overlay:closed', once)
        overlay.setAttribute('data-ui--overlay-open-value', 'true')
      })
      overlay.setAttribute('data-ui--overlay-open-value', 'false')
    JS

    assert_state '#modal-content', 'open'
    assert page.evaluate_script("document.querySelector('#modal-content').matches(':modal')")
    assert_not hidden?('#modal-content')
    assert scroll_locked?, 'the page is unlocked under an overlay that is still on screen'
  end

  test 'an overlay reopened while it is still animating out still returns focus to its trigger' do
    visit primitives_overlay_path
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'

    # Mid-exit the browser still has focus inside the dialog, so the element a reopen finds
    # focused belongs to content that is about to stop being rendered. Recorded as the
    # focus-return target, it strands focus on <body> when the overlay finally closes.
    page.execute_script(<<~JS)
      const overlay = document.querySelector('#modal-overlay')
      window.__midExitFocus = null
      overlay.setAttribute('data-ui--overlay-open-value', 'false')
      requestAnimationFrame(() => {
        window.__midExitFocus = document.activeElement.id
        overlay.setAttribute('data-ui--overlay-open-value', 'true')
      })
    JS

    assert_state '#modal-content', 'open'
    assert_equal 'modal-content', page.evaluate_script('window.__midExitFocus'),
                 'the reopen did not land while focus was still inside the closing dialog'

    press :escape
    assert_state '#modal-content', 'closed'
    assert_equal 'modal-trigger', focused_id
  end
end
