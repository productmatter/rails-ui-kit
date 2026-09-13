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
    page.execute_script(<<~JS)
      var dialog = document.createElement('dialog')
      dialog.id = 'tt2-dialog'
      dialog.innerHTML = '<div data-controller="ui--tooltip">' +
        '<div data-ui--tooltip-target="trigger"><button id="tt2-trigger">Hover me</button></div>' +
        '<div class="hidden opacity-0" data-ui--tooltip-target="content">Tip' +
        '<div data-ui--tooltip-target="arrow"></div></div></div>'
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

    # Let the 100ms hide animation finish (content gets the "hidden" class) before the
    # second Escape, so the tooltip's own handler no-ops and the dialog's handler runs.
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
    page.execute_script(<<~JS, installation_path)
      var wrapper = document.createElement('div')
      wrapper.id = 'tt6-wrapper'
      wrapper.setAttribute('data-controller', 'ui--tooltip')
      // Clear of the fixed sidebar, which would otherwise receive the hover instead.
      wrapper.style.cssText = 'margin-left:320px'
      wrapper.innerHTML = '<div data-ui--tooltip-target="trigger"><a id="tt6-link" href="' + arguments[0] + '">Go</a></div>' +
        '<div class="hidden opacity-0" data-ui--tooltip-target="content">Tip' +
        '<div data-ui--tooltip-target="arrow"></div></div>'
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
    assert_selector "#tt6-wrapper [data-ui--tooltip-target='content'].hidden", visible: :hidden
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

  private

  def focused?(element)
    page.evaluate_script('document.activeElement === arguments[0]', element)
  end
end
