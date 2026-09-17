# frozen_string_literal: true

# Shared probes for the ui--presence / ui--overlay browser tests. Not a test file, and not a
# second harness: ApplicationSystemTestCase (ui-test-harness) stays the base class, and these
# are the few primitive-specific reads that would otherwise be copied into eight files.
# `state_of`, `focused?`, `focused_id`, `press` and `rect_of` come from ApplicationSystemTestCase's
# BrowserHelpers.
module UiOverlayHelpers
  def hidden?(selector)
    page.evaluate_script("document.querySelector(arguments[0]).hasAttribute('hidden')", selector)
  end

  # The scroll lock takes <body> out of flow; that, not a class, is the observable state.
  def scroll_locked?
    page.evaluate_script("document.body.style.position === 'fixed'")
  end

  def body_style(property)
    page.evaluate_script('document.body.style[arguments[0]]', property)
  end

  def scroll_position
    page.evaluate_script('[window.scrollX, window.scrollY]')
  end

  # Waits, the way any Capybara assertion waits rather than sleeping a duration, for the element
  # to reach `expected` with its own animations finished. data-state="open" is set as the entry
  # transition *starts*; closing that early legitimately reverses or short-circuits the entry,
  # so a test that means "once it is open" has to wait for the transition too.
  def assert_state(selector, expected)
    settled = <<~JS
      (() => {
        const element = document.querySelector(arguments[0])
        const running = element.getAnimations().some((animation) => !['finished', 'idle'].includes(animation.playState))
        return element.dataset.state === arguments[1] && !running
      })()
    JS
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.02 until page.evaluate_script(settled, selector, expected)
    end
    assert_equal expected, state_of(selector)
  rescue Timeout::Error
    flunk "expected #{selector} to settle at data-state=#{expected}, got #{state_of(selector)}"
  end

  def emulate_media(name, value)
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [{ name: name, value: value }])
  end
end
