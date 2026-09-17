# frozen_string_literal: true

require_relative 'ui_overlay_helpers'

# Shared vocabulary for the toast browser tests. Not a second harness: ApplicationSystemTestCase
# stays the base class. `install_console_warning_capture` and `console_warnings` come from its
# BrowserHelpers.
module ToastHelpers
  include UiOverlayHelpers

  TOAST = '#ui-toasts [data-slot=toast]'

  # triggerToast is installed when the container connects, a tick after the page arrives.
  def wait_for_toast_api
    wait_until("typeof window.triggerToast === 'function'")
  end

  def trigger_toast(payload)
    wait_for_toast_api
    page.execute_script('window.triggerToast(arguments[0])', deep_stringify(payload))
  end

  # Waits, as a Capybara assertion does, for a script expression to become true.
  def wait_until(expression, *args, timeout: Capybara.default_max_wait_time)
    Timeout.timeout(timeout) { sleep 0.02 until page.evaluate_script(expression, *args) }
  rescue Timeout::Error
    flunk "timed out waiting for #{expression}"
  end

  # The newest toast, once its enter transition has settled.
  def settled_toast
    assert_selector TOAST
    wait_until(<<~JS)
      (() => {
        const toasts = document.querySelectorAll('#{TOAST}')
        const toast = toasts[toasts.length - 1]
        return toast && toast.dataset.state === 'open' &&
          !toast.getAnimations().some((a) => !['finished', 'idle'].includes(a.playState))
      })()
    JS
    all(TOAST).last
  end

  def deep_stringify(value)
    case value
    when Hash then value.to_h { |key, item| [key.to_s, deep_stringify(item)] }
    when Array then value.map { |item| deep_stringify(item) }
    when Symbol then value.to_s
    else value
    end
  end
end
