# frozen_string_literal: true

# The instrumentation half of the Modal + Turbo lifecycle tests: the probes that make a claim
# checkable rather than plausible -- what the server answered, whether the dialog was re-mounted,
# whether it animated out, whether anything was requested at all. Separated from
# ModalTurboHelpers, which is the vocabulary of the demo itself.
module ModalTurboProbes
  # Marks the dialog that is open now, so a later assertion can prove it is the same element
  # rather than a re-mounted one that merely looks the same.
  def mark_dialog(name = 'same')
    page.execute_script("document.querySelector('#modal dialog').dataset.probe = arguments[0]", name)
  end

  def assert_same_dialog(name = 'same')
    assert_selector "#modal dialog[data-probe='#{name}']"
  end

  # showModal() is the mount. Counting it is how "the dialog did not re-open" is proved rather
  # than assumed from content that happens to look unchanged.
  def count_mounts
    page.execute_script(<<~JS)
      window.__mounts = 0
      const original = HTMLDialogElement.prototype.showModal
      HTMLDialogElement.prototype.showModal = function (...args) {
        window.__mounts++
        return original.apply(this, args)
      }
    JS
  end

  def mounts
    page.evaluate_script('window.__mounts')
  end

  def count_requests
    page.execute_script(<<~JS)
      window.__requests = 0
      document.addEventListener('turbo:before-fetch-request', () => { window.__requests++ })
    JS
  end

  def requests
    page.evaluate_script('window.__requests')
  end

  # Turbo swaps a frame's content and then waits two repaints before dispatching
  # turbo:frame-render, which is what moves focus. Seeing the new content is not the finish line.
  def track_frame_renders
    page.execute_script(<<~JS)
      window.__frameRenders = 0
      document.addEventListener('turbo:frame-render', () => { window.__frameRenders++ })
    JS
  end

  def assert_focus_in_dialog_after_frame_render(count)
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.02 until page.evaluate_script('window.__frameRenders') >= count
    end
    assert page.evaluate_script("document.querySelector('#modal dialog').contains(document.activeElement)"),
           "expected focus inside the dialog, got #{page.evaluate_script('document.activeElement.outerHTML.slice(0, 80)')}"
  end

  # The status code the server actually answered with, recorded as the response arrives.
  def record_response_statuses
    page.execute_script(<<~JS)
      window.__statuses = []
      document.addEventListener('turbo:before-fetch-response', (event) => {
        window.__statuses.push(event.detail.fetchResponse.statusCode)
      })
    JS
  end

  def response_statuses
    page.evaluate_script('window.__statuses')
  end

  # Every data-state the open dialog passes through from here on. "closing" in that list is the
  # exit animation having run: an element that is merely removed never reports it.
  def record_dialog_states
    page.execute_script(<<~JS)
      window.__states = []
      const dialog = document.querySelector('#modal dialog')
      new MutationObserver(() => window.__states.push(dialog.dataset.state))
        .observe(dialog, { attributes: true, attributeFilter: ['data-state'] })
    JS
  end

  def dialog_states
    page.evaluate_script('window.__states')
  end

  def click_at(point_x, point_y)
    page.driver.browser.action.move_to_location(point_x.to_i, point_y.to_i).click.perform
  end

  # A point the dialog is provably not covering -- measured, because a dialog that is not laid
  # out measures zero and would make any "outside" coordinate pass for the wrong reason.
  def point_outside_dialog
    rect = page.evaluate_script("document.querySelector('#modal dialog').getBoundingClientRect().toJSON()")
    assert_operator rect['width'], :>, 0, 'the dialog is not laid out'
    assert_operator rect['height'], :>, 0, 'the dialog is not laid out'
    point = [rect['left'] / 2, rect['top'] / 2]
    assert_operator point[0], :<, rect['left']
    assert_operator point[1], :<, rect['top']

    point
  end
end
