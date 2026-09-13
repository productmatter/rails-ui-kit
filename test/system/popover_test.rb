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
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)
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
    assert_equal 'true', first['aria-expanded']

    second.click
    assert_equal 'true', second['aria-expanded']
    assert_equal 'false', first['aria-expanded']
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

  test 'PO7: Escape closes when focus is inside or on the trigger, leaves it open when focus is elsewhere, and honours defaultPrevented' do
    visit popover_path
    trigger = find("[data-ui--popover-target='trigger'] button")

    # 1. Click on plain text inside the panel (not a button): focus lands on <body>,
    # so the document has nothing focused and Escape still needs to close it via the trigger.
    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    text = find("[data-ui--popover-target='content'] p", match: :first)
    text_rect = page.evaluate_script('arguments[0].getBoundingClientRect()', text)
    page.driver.browser.action.move_to_location(
      (text_rect['left'] + 2).to_i, (text_rect['top'] + 2).to_i
    ).click.perform
    assert page.evaluate_script('document.activeElement === document.body')
    find('body').send_keys(:escape)
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)

    # 2. Open, focus a button inside the panel, Escape: closed, focus back on the trigger.
    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    find("[data-ui--popover-target='content'] button", match: :first).send_keys(:escape)
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)

    # 3. Open, then programmatically focus an outside button: Popover has no
    # focus-leaves-closes-it behaviour (unlike Dropdown), so it stays open, and
    # Escape does nothing because focus isn't inside it, on the trigger, or on body.
    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    page.execute_script(<<~JS)
      var btn = document.createElement('button')
      btn.id = 'po7-outside'
      btn.textContent = 'Outside'
      document.body.appendChild(btn)
      btn.focus()
    JS
    outside = find('#po7-outside')
    assert_equal 'true', trigger['aria-expanded']
    assert focused?(outside)
    outside.send_keys(:escape)
    assert_equal 'true', trigger['aria-expanded']
    assert focused?(outside)
    trigger.click # close it back down for the next case
    assert_equal 'false', trigger['aria-expanded']

    # 4. A capture-phase listener that preventDefault()s the first Escape blocks it;
    # the second Escape goes through normally.
    trigger.click
    assert_equal 'true', trigger['aria-expanded']
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
    assert_equal 'true', trigger['aria-expanded']
    find("[data-ui--popover-target='content'] button", match: :first).send_keys(:escape)
    assert_equal 'false', trigger['aria-expanded']
  end

  private

  def focused?(element)
    page.evaluate_script('document.activeElement === arguments[0]', element)
  end
end
