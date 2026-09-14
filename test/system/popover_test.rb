# frozen_string_literal: true

require 'application_system_test_case'

class PopoverTest < ApplicationSystemTestCase
  # The registered driver's screen_size isn't honoured for the actual browser window on
  # this machine (observed viewport ~756x413), which is too small for the block-layout
  # coordinate clicks below to land inside the viewport.
  setup { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test 'PO1: ARIA lives on the trigger control, not the wrapper, and Escape from inside returns focus to it' do
    visit popover_path
    wrapper = find("[data-controller~='ui--popover']")
    trigger = find("[data-ui--popover-target='trigger'] button")
    content = find("[data-ui--popover-target='content']", visible: :all)

    assert_equal 'dialog', trigger['aria-haspopup']
    assert_equal content[:id], trigger['aria-controls']
    assert_nil wrapper['aria-haspopup']
    assert_nil wrapper['aria-expanded']
    assert_nil wrapper['aria-controls']

    trigger.click
    find("[data-ui--popover-target='content'] button", match: :first).send_keys(:escape)
    assert_expanded 'false', trigger
    assert_focused trigger
  end

  test 'PO2: opening one popover closes another that was open' do
    visit popover_path
    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--popover']")
      var clone = original.cloneNode(true)
      clone.querySelector("[data-ui--popover-target='content']").removeAttribute('id')
      clone.querySelector("[data-ui--popover-target='trigger'] button").textContent = 'Open popover 2'
      // Clear of the fixed sidebar, which would otherwise intercept the click below.
      clone.style.cssText = 'margin-left:320px'
      document.body.appendChild(clone)
    JS

    first = find('button', text: 'Open popover', exact_text: true)
    second = find('button', text: 'Open popover 2')

    first.click
    assert_expanded 'true', first

    second.click
    assert_expanded 'true', second
    assert_expanded 'false', first
  end

  test 'PO3: in a block layout, clicking empty wrapper space does not toggle the popover' do
    visit popover_path
    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--popover']")
      var container = document.createElement('div')
      container.id = 'po3-container'
      container.style.cssText = 'width:600px;display:block;margin-left:320px'
      container.appendChild(original.cloneNode(true))
      document.body.appendChild(container)
    JS

    container = find('#po3-container', visible: :all)
    wrapper = container.find("[data-controller~='ui--popover']", visible: :all)
    trigger = container.find("[data-ui--popover-target='trigger'] button")
    page.execute_script("arguments[0].scrollIntoView({block: 'center'})", wrapper)
    rect = page.evaluate_script('arguments[0].getBoundingClientRect()', wrapper)

    x = rect['right'] - 20
    y = rect['top'] + (rect['height'] / 2)
    page.driver.browser.action.move_to_location(x.to_i, y.to_i).click.perform

    assert_equal 'false', trigger['aria-expanded']
  end

  test 'PO4: a checkbox injected into the trigger slot toggles itself without opening the popover' do
    visit popover_path
    page.execute_script(<<~JS)
      var trigger = document.querySelector("[data-ui--popover-target='trigger']")
      var checkbox = document.createElement('input')
      checkbox.type = 'checkbox'
      checkbox.id = 'po4-checkbox'
      trigger.appendChild(checkbox)
    JS

    checkbox = find('#po4-checkbox', visible: :all)
    checkbox.click
    assert checkbox.checked?
    assert_equal 'false', find("[data-ui--popover-target='trigger'] button")['aria-expanded']
  end

  test 'PO7: Escape closes from inside, from the trigger or from nowhere and returns focus; from elsewhere it closes without taking focus; and it honours defaultPrevented' do
    visit popover_path
    trigger = find("[data-ui--popover-target='trigger'] button")
    content = find("[data-ui--popover-target='content']", visible: :all)

    # 1. Click on plain text inside the panel (not a button). The panel took focus when it opened
    # (ui--overlay's layer mode), so focus is on the panel itself rather than on any control, and
    # Escape still closes it and hands focus back to the trigger.
    trigger.click
    assert_expanded 'true', trigger
    text = find("[data-ui--popover-target='content'] p", match: :first)
    text_rect = page.evaluate_script('arguments[0].getBoundingClientRect()', text)
    page.driver.browser.action.move_to_location(
      (text_rect['left'] + 2).to_i, (text_rect['top'] + 2).to_i
    ).click.perform
    assert_focused content
    press :escape
    assert_closed trigger

    # 2. Nothing focused at all -- focus on <body> -- still closes it and returns focus.
    trigger.click
    assert_expanded 'true', trigger
    page.execute_script('document.activeElement.blur()')
    assert page.evaluate_script('document.activeElement === document.body')
    press :escape
    assert_closed trigger

    # 3. Open, focus a button inside the panel, Escape: closed, focus back on the trigger.
    trigger.click
    assert_expanded 'true', trigger
    find("[data-ui--popover-target='content'] button", match: :first).send_keys(:escape)
    assert_closed trigger

    # 4. Open, then programmatically focus an outside button: Popover has no
    # focus-leaves-closes-it behaviour (unlike Dropdown), so it stays open. The panel is a
    # popover="auto" in the top layer, and the platform gives Escape to the topmost one wherever
    # focus is -- so Escape closes it, but never pulls focus back from that button.
    trigger.click
    assert_expanded 'true', trigger
    page.execute_script(<<~JS)
      var btn = document.createElement('button')
      btn.id = 'po7-outside'
      btn.textContent = 'Outside'
      document.body.appendChild(btn)
      btn.focus()
    JS
    outside = find('#po7-outside')
    sleep 0.25
    assert_expanded 'true', trigger
    assert_focused outside
    outside.send_keys(:escape)
    assert_expanded 'false', trigger
    sleep 0.25
    assert_focused outside

    # 5. A capture-phase listener that preventDefault()s the first Escape blocks it;
    # the second Escape goes through normally.
    trigger.click
    assert_expanded 'true', trigger
    page.execute_script(<<~JS)
      window.__po7PreventCount = 0
      document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && window.__po7PreventCount < 1) {
          window.__po7PreventCount++
          e.preventDefault()
        }
      }, true)
    JS
    button_in_panel = find("[data-ui--popover-target='content'] button", match: :first)
    button_in_panel.send_keys(:escape)
    # The overlay closes a dismissed layer a frame later, so give a close that slipped through
    # time to show before asserting it didn't.
    sleep 0.25
    assert_expanded 'true', trigger
    find("[data-ui--popover-target='content'] button", match: :first).send_keys(:escape)
    assert_expanded 'false', trigger
  end

  test 'PO8: a popover missing its ui--overlay or ui--anchor companion never throws, and warns once naming each' do
    visit popover_path
    install_console_warning_capture
    install_error_capture

    # Two clones, each missing one companion -- old copy-paste predating 144d104, say. Missing
    # ui--overlay means opening does nothing at all; missing ui--anchor means it opens centred
    # instead of anchored to the trigger. Neither should error, and each should say so once.
    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--popover']")

      var noOverlay = original.cloneNode(true)
      noOverlay.id = 'po8-no-overlay'
      noOverlay.setAttribute('data-controller', 'ui--popover ui--anchor')
      noOverlay.querySelector("[data-ui--popover-target='content']").removeAttribute('id')
      noOverlay.style.cssText = 'margin-left:320px'
      document.body.appendChild(noOverlay)

      var noAnchor = original.cloneNode(true)
      noAnchor.id = 'po8-no-anchor'
      noAnchor.setAttribute('data-controller', 'ui--popover ui--overlay')
      noAnchor.querySelector("[data-ui--popover-target='content']").removeAttribute('id')
      noAnchor.style.cssText = 'margin-left:640px'
      document.body.appendChild(noAnchor)
    JS

    find('#po8-no-overlay [data-ui--popover-target="trigger"] button').click
    find('#po8-no-anchor [data-ui--popover-target="trigger"] button').click
    assert_selector "#po8-no-anchor [data-ui--popover-target='content']", visible: true

    assert_empty captured_errors
    warnings = console_warnings
    assert warnings.any? { |warning| warning.include?('ui--overlay') && warning.include?('opening') },
           "expected a warning naming the missing ui--overlay companion, got: #{warnings}"
    assert warnings.any? { |warning| warning.include?('ui--anchor') && warning.include?('positioning') },
           "expected a warning naming the missing ui--anchor companion, got: #{warnings}"
  end

  private

  # Captures uncaught errors from here on, so a claim that a code path "never throws" is
  # checked rather than assumed.
  def install_error_capture
    page.execute_script(<<~JS)
      window.__errors = []
      window.addEventListener('error', function (event) { window.__errors.push(event.message) })
    JS
  end

  def captured_errors
    page.evaluate_script('window.__errors')
  end

  # Captures console.warn calls made from here on, without silencing them -- the real warning
  # still reaches the browser's own console too.
  def install_console_warning_capture
    page.execute_script(<<~JS)
      window.__consoleWarnings = []
      var originalWarn = console.warn.bind(console)
      console.warn = function () {
        window.__consoleWarnings.push(Array.from(arguments).map(String).join(' '))
        originalWarn.apply(console, arguments)
      }
    JS
  end

  def console_warnings
    page.evaluate_script('window.__consoleWarnings')
  end

  def focused?(element)
    page.evaluate_script('document.activeElement === arguments[0]', element)
  end

  # ui--overlay closes a light-dismissed or Escaped layer on the next frame and returns focus once
  # its exit animation has finished, so these wait the way any Capybara assertion does.
  def assert_expanded(expected, trigger)
    trigger.synchronize do
      actual = trigger['aria-expanded']
      raise Capybara::ExpectationNotMet, "aria-expanded is #{actual.inspect}" unless actual == expected
    end
    assert_equal expected, trigger['aria-expanded']
  end

  # A trigger press while the panel is animating out means "stay closed", so a test that reopens
  # waits for the panel to leave the page first -- which is also when focus comes back.
  def assert_closed(trigger)
    assert_expanded 'false', trigger
    assert_no_selector "[data-ui--popover-target='content']", visible: true
    assert_focused trigger
  end

  def assert_focused(element)
    element.synchronize { raise Capybara::ExpectationNotMet, 'not focused' unless focused?(element) }
    assert focused?(element)
  end

  # Sends keys to whatever currently has focus, the way a keyboard does.
  def press(*keys)
    page.driver.browser.action.send_keys(*keys).perform
  end
end
