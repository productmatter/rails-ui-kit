# frozen_string_literal: true

require 'application_system_test_case'

class TooltipTest < ApplicationSystemTestCase
  # The registered driver's screen_size isn't honoured for the actual browser window on
  # this machine (observed viewport ~756x413), which is too small for the block-layout
  # hover test below to land inside the viewport.
  setup { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test 'TT1: a pre-existing aria-describedby is merged onto the control, not the wrapper, and restored when the controller disconnects' do
    visit tooltip_path
    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--tooltip']")
      var clone = original.cloneNode(true)
      var button = clone.querySelector('button')
      button.id = 'tt1-button'
      button.setAttribute('aria-describedby', 'x')
      clone.id = 'tt1-wrapper'
      document.body.appendChild(clone)
    JS

    button = find('#tt1-button')
    wrapper = find('#tt1-wrapper')

    described_by = button['aria-describedby']
    assert_match(/\Ax ui-tooltip-/, described_by)
    assert_nil wrapper['aria-describedby']

    page.execute_script("document.getElementById('tt1-wrapper').removeAttribute('data-controller')")
    assert_equal 'x', find('#tt1-button')['aria-describedby']
  end

  test 'TT2: Escape hides a visible tooltip without moving focus' do
    visit tooltip_path
    trigger = find('button', text: 'Top')
    trigger.click
    assert_selector "[data-ui--tooltip-target='content']", text: 'Tooltip top', visible: true

    trigger.send_keys(:escape)
    assert_selector "[data-ui--tooltip-target='content']", text: 'Tooltip top', visible: :hidden
    assert focused?(trigger)
  end

  test 'TT2: inside a dialog with its own Escape handler, the tooltip consumes the first Escape only' do
    visit tooltip_path
    # A rendered tooltip, moved inside a modal <dialog> that handles Escape itself.
    page.execute_script(<<~JS)
      var dialog = document.createElement('dialog')
      dialog.id = 'tt2-dialog'
      var clone = document.querySelector("[data-controller~='ui--tooltip']").cloneNode(true)
      clone.querySelector('button').id = 'tt2-trigger'
      dialog.appendChild(clone)
      document.body.appendChild(dialog)
      dialog.showModal()
      window.__dialogEscapeRan = false
      dialog.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
          e.preventDefault()
          window.__dialogEscapeRan = true
        }
      })
    JS

    trigger = find('#tt2-trigger')
    trigger.click
    assert_selector "#tt2-dialog [data-ui--tooltip-target='content']", visible: true

    trigger.send_keys(:escape)
    assert page.evaluate_script("document.getElementById('tt2-dialog').open")
    assert_equal false, page.evaluate_script('window.__dialogEscapeRan')
    assert_selector "#tt2-dialog [data-ui--tooltip-target='content']", visible: :hidden

    # Let the 100ms exit animation finish (ui--presence puts the hidden attribute back) before
    # the second Escape, so the tooltip has nothing left to consume and the dialog's handler runs.
    sleep 0.15
    trigger.send_keys(:escape)
    assert_equal true, page.evaluate_script('window.__dialogEscapeRan')
  end

  test 'TT3: the pointer can move from the trigger onto the tooltip content without it hiding' do
    visit tooltip_path
    trigger = find('button', text: 'Top')
    content = find("[data-ui--tooltip-target='content']", visible: :all, text: 'Tooltip top')

    page.driver.browser.action.move_to(trigger.native).perform
    assert_selector "[data-ui--tooltip-target='content']", text: 'Tooltip top', visible: true

    page.driver.browser.action.move_to(content.native).perform
    assert_selector "[data-ui--tooltip-target='content']", text: 'Tooltip top', visible: true

    page.driver.browser.action.move_to(find('h1').native).perform
    assert_selector "[data-ui--tooltip-target='content']", text: 'Tooltip top', visible: :hidden
  end

  test 'TT4: staying focused keeps the tooltip visible after the pointer leaves; blurring hides it' do
    visit tooltip_path
    trigger = find('button', text: 'Top')

    page.execute_script('arguments[0].focus()', trigger)
    assert_selector "[data-ui--tooltip-target='content']", text: 'Tooltip top', visible: true

    page.driver.browser.action.move_to(trigger.native).perform
    page.driver.browser.action.move_to(find('h1').native).perform
    assert_selector "[data-ui--tooltip-target='content']", text: 'Tooltip top', visible: true

    page.execute_script('arguments[0].blur()', trigger)
    assert_selector "[data-ui--tooltip-target='content']", text: 'Tooltip top', visible: :hidden
  end

  test 'TT5: in a block layout, hovering beside the trigger does not show it, and hovering the trigger centres it' do
    visit tooltip_path
    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--tooltip']")
      var container = document.createElement('div')
      container.id = 'tt5-container'
      container.style.cssText = 'width:600px;display:block;margin-left:320px'
      container.appendChild(original.cloneNode(true))
      document.body.appendChild(container)
    JS

    container = find('#tt5-container', visible: :all)
    button = container.find('button')
    page.execute_script("arguments[0].scrollIntoView({block: 'center'})", button)
    button_rect = page.evaluate_script('arguments[0].getBoundingClientRect()', button)

    far_x = button_rect['left'] + 300
    far_y = button_rect['top'] + (button_rect['height'] / 2)
    page.execute_script(<<~JS, far_x, far_y)
      var el = document.elementFromPoint(arguments[0], arguments[1])
      if (el) el.dispatchEvent(new MouseEvent('mouseenter', { bubbles: true }))
    JS
    assert_no_selector "#tt5-container [data-ui--tooltip-target='content']", visible: true

    page.driver.browser.action.move_to(button.native).perform
    content = container.find("[data-ui--tooltip-target='content']", visible: true)
    content_rect = page.evaluate_script('arguments[0].getBoundingClientRect()', content)

    button_center = button_rect['left'] + (button_rect['width'] / 2)
    content_center = content_rect['left'] + (content_rect['width'] / 2)
    assert_in_delta button_center, content_center, 2
  end

  test 'TT6: after following a turbo-linked trigger and pressing Back with the pointer elsewhere, no tooltip is visible' do
    visit tooltip_path
    # A rendered tooltip whose trigger is a Turbo-navigating link.
    page.execute_script(<<~JS, installation_path)
      var wrapper = document.querySelector("[data-controller~='ui--tooltip']").cloneNode(true)
      wrapper.id = 'tt6-wrapper'
      // Clear of the fixed sidebar, which would otherwise receive the hover instead.
      wrapper.style.cssText = 'margin-left:320px'
      var slot = wrapper.querySelector("[data-ui--tooltip-target='trigger']")
      slot.innerHTML = '<a id="tt6-link" href="' + arguments[0] + '">Go</a>'
      document.body.appendChild(wrapper)
    JS

    link = find('#tt6-link')
    page.execute_script("arguments[0].scrollIntoView({block: 'center'})", link)
    link.hover
    assert_selector "#tt6-wrapper [data-ui--tooltip-target='content']", visible: true

    link.click
    assert_selector 'h1', text: 'Installation'

    # The defect TT6 describes is a *stale* tooltip: one still showing after Back with the
    # pointer somewhere else. Leaving the pointer parked on the trigger through the whole
    # navigation is a different situation -- the restored page puts the trigger back under
    # a pointer that really is hovering it, and Chrome re-fires mouseenter. Showing the
    # tooltip then is correct hover behaviour, not a bug, so move the pointer away first.
    page.driver.browser.action.move_to(find('h1').native).perform

    page.go_back
    assert_selector 'h1', text: 'Tooltip'
    assert_selector "#tt6-wrapper [data-ui--tooltip-target='content'][hidden]", visible: :hidden
    assert_no_selector "[data-ui--tooltip-target='content']", visible: true
  end

  test 'TT7: a fast leave-then-enter within the grace period ends with the tooltip visible and staying visible' do
    visit tooltip_path
    trigger = find('button', text: 'Top')

    # Dispatched directly rather than via real pointer moves, so the 30ms gap between
    # leave and enter is exact -- travel time for a real move would swamp it.
    page.execute_script("arguments[0].dispatchEvent(new MouseEvent('mouseenter'))", trigger)
    assert_selector "[data-ui--tooltip-target='content']", text: 'Tooltip top', visible: true

    page.execute_script("arguments[0].dispatchEvent(new MouseEvent('mouseleave'))", trigger)
    sleep 0.03
    page.execute_script("arguments[0].dispatchEvent(new MouseEvent('mouseenter'))", trigger)

    assert_selector "[data-ui--tooltip-target='content']", text: 'Tooltip top', visible: true
    sleep 0.3
    assert_selector "[data-ui--tooltip-target='content']", text: 'Tooltip top', visible: true
  end

  test 'TT8: a tooltip missing its ui--overlay or ui--anchor companion never throws, and warns once naming each' do
    visit tooltip_path
    install_console_warning_capture
    install_error_capture

    # Two clones, each missing one companion -- old copy-paste predating 144d104, say. Missing
    # ui--overlay means hovering shows nothing at all; missing ui--anchor means it shows centred
    # instead of anchored to the trigger. Neither should error, and each should say so once.
    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--tooltip']")

      // Clear of the fixed sidebar, which would otherwise receive the hover instead.
      var noOverlay = original.cloneNode(true)
      noOverlay.id = 'tt8-no-overlay'
      noOverlay.setAttribute('data-controller', 'ui--tooltip ui--anchor')
      noOverlay.querySelector('button').id = 'tt8-no-overlay-button'
      noOverlay.style.cssText = 'margin-left:320px'
      document.body.appendChild(noOverlay)

      var noAnchor = original.cloneNode(true)
      noAnchor.id = 'tt8-no-anchor'
      noAnchor.setAttribute('data-controller', 'ui--tooltip ui--overlay')
      noAnchor.querySelector('button').id = 'tt8-no-anchor-button'
      noAnchor.style.cssText = 'margin-left:320px'
      document.body.appendChild(noAnchor)
    JS

    find('#tt8-no-overlay-button').hover
    find('#tt8-no-anchor-button').hover
    assert_selector "#tt8-no-anchor [data-ui--tooltip-target='content']", visible: true

    assert_empty captured_errors
    warnings = console_warnings
    assert warnings.any? { |warning| warning.include?('ui--overlay') && warning.include?('showing') },
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
end
