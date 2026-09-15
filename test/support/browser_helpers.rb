# frozen_string_literal: true

# Browser probes shared by every test/system/*_test.rb file and the per-component helper modules
# beside them. Included once, from ApplicationSystemTestCase, so a file that needs one of these
# picks it up automatically instead of writing its own copy -- five files each once did, for
# `press` alone.
module BrowserHelpers
  # Sends keys to whatever currently has focus, the way a keyboard does -- unlike Capybara's
  # element.send_keys, which focuses the element it is called on first.
  def press(*keys)
    page.driver.browser.action.send_keys(*keys).perform
  end

  def focused?(element)
    page.evaluate_script('document.activeElement === arguments[0]', element)
  end

  def focused_id
    page.evaluate_script('document.activeElement && document.activeElement.id')
  end

  # A real pointer click at viewport coordinates -- element.click() doesn't shift focus the way a
  # genuine mousedown does, which several tests below depend on.
  def click_at(point_x, point_y)
    page.driver.browser.action.move_to_location(point_x.to_i, point_y.to_i).click.perform
  end

  def state_of(selector)
    page.evaluate_script('document.querySelector(arguments[0]).dataset.state', selector)
  end

  def rect_of(selector)
    page.evaluate_script('document.querySelector(arguments[0]).getBoundingClientRect().toJSON()', selector)
  end

  # Captures console.warn calls made from here on, without silencing them -- the real warning
  # still reaches the browser's own console too.
  def install_console_warning_capture
    page.execute_script(<<~JS)
      window.__consoleWarnings = []
      window.__originalConsoleWarn ||= console.warn.bind(console)
      console.warn = function () {
        window.__consoleWarnings.push(Array.from(arguments).map(String).join(' '))
        window.__originalConsoleWarn.apply(console, arguments)
      }
    JS
  end

  def console_warnings
    page.evaluate_script('window.__consoleWarnings')
  end

  # Captures uncaught errors from here on, so a claim that a code path "never throws" is checked
  # rather than assumed.
  def install_error_capture
    page.execute_script(<<~JS)
      window.__errors = []
      window.addEventListener('error', function (event) { window.__errors.push(event.message) })
    JS
  end

  def captured_errors
    page.evaluate_script('window.__errors')
  end

  # The value a round-trip result element carries right now, or 'none' before the first
  # submission -- so a wait for the *next* response can tell it apart from the one already drawn.
  def submission_token(result_selector)
    page.evaluate_script(<<~JS, result_selector)
      (() => {
        const result = document.querySelector(arguments[0])
        return result ? result.dataset.submission : 'none'
      })()
    JS
  end

  # Submits the form at `submit_selector` and waits for the response: an element the previous
  # response did not draw, since the result element outlives every submission and its text alone
  # would happily match a stale one.
  def submit_and_wait(submit_selector, result_selector)
    drawn_by = submission_token(result_selector)
    find(submit_selector).click
    assert_selector "#{result_selector}:not([data-submission='#{drawn_by}'])"
  end

  # Chrome's own accessibility tree for one element: nil where the element is missing from the
  # DOM (so a typo'd selector fails an assertion instead of raising a raw CDP error) and nil
  # where it is ignored -- display:none, aria-hidden -- since either way it never reaches a
  # screen reader.
  def ax_node(selector)
    browser = page.driver.browser
    root = browser.execute_cdp('DOM.getDocument', depth: 0)['root']['nodeId']
    node = browser.execute_cdp('DOM.querySelector', nodeId: root, selector: selector)['nodeId']
    return nil if node.to_i.zero?

    ax = browser.execute_cdp('Accessibility.getPartialAXTree', nodeId: node, fetchRelatives: false)['nodes'].first
    ax unless ax.nil? || ax['ignored']
  end
end
