# frozen_string_literal: true

require 'application_system_test_case'

class DropdownTest < ApplicationSystemTestCase
  # The registered driver's screen_size isn't honoured for the actual browser window on
  # this machine (observed viewport ~756x413), which is too small for the block-layout
  # coordinate clicks below to land inside the viewport.
  setup { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test 'DD1: after following a menu item link and pressing Back, the menu stays closed with focus outside it' do
    visit dropdown_path
    edit_item = find("[role='menu'] a[role='menuitem']", text: 'Edit', visible: false)
    page.execute_script("arguments[0].setAttribute('href', arguments[1])", edit_item, installation_path)

    trigger = menu_trigger
    trigger.click
    assert_equal 'true', trigger['aria-expanded']

    find("[role='menu'] a[role='menuitem']", text: 'Edit').click
    assert_selector 'h1', text: 'Installation'

    page.go_back
    assert_selector 'h1', text: 'Dropdown'

    trigger = menu_trigger
    assert_equal 'false', trigger['aria-expanded']
    assert_no_selector "[role='menu']", visible: true
    refute focused?(find("[role='menu']", visible: false))
  end

  test 'DD2: activating a menu item (click or Enter) closes the menu and returns focus to the trigger' do
    visit dropdown_path
    # Prevent the demo's href="#" items from actually navigating (scrolling to top),
    # so the assertions below reflect the dropdown's own close/focus behaviour.
    page.execute_script(<<~JS)
      document.addEventListener('click', function(e) {
        if (e.target.closest('[role="menuitem"]')) e.preventDefault()
      }, true)
    JS

    trigger = menu_trigger
    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    find("[role='menu'] a[role='menuitem']", text: 'Edit').click
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)

    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    find("[role='menu'] a[role='menuitem']", text: 'Edit').send_keys(:enter)
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)
  end

  test 'DD3: opening one dropdown closes another that was open' do
    visit dropdown_path
    trigger_menu = menu_trigger
    trigger_listbox = find("[data-ui--dropdown-target='trigger'] button", text: 'Listbox')

    trigger_menu.click
    assert_equal 'true', trigger_menu['aria-expanded']

    trigger_listbox.click
    assert_equal 'true', trigger_listbox['aria-expanded']
    assert_equal 'false', trigger_menu['aria-expanded']
  end

  test 'DD4: match_width and bottom-end placement measure the trigger control, not a full-width wrapper' do
    visit dropdown_path
    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--dropdown'][data-ui--dropdown-kind-value='menu']")
      var container = document.createElement('div')
      container.id = 'dd4-container'
      container.style.cssText = 'width:600px;display:block;margin-left:320px'
      var clone = original.cloneNode(true)
      clone.setAttribute('data-ui--dropdown-placement-value', 'bottom-end')
      clone.setAttribute('data-ui--dropdown-match-width-value', 'true')
      container.appendChild(clone)
      document.body.appendChild(container)
    JS

    container = find('#dd4-container', visible: :all)
    trigger = container.find("[data-ui--dropdown-target='trigger'] button")
    trigger.click

    content = container.find("[data-ui--dropdown-target='content']", visible: true)

    trigger_rect = page.evaluate_script('arguments[0].getBoundingClientRect()', trigger)
    content_rect = page.evaluate_script('arguments[0].getBoundingClientRect()', content)

    # A couple of px of tolerance for floating-point/sub-pixel layout noise: the actual
    # bug being guarded against put the content ~500px off, not ~1px.
    assert_in_delta trigger_rect['right'], content_rect['right'], 2
    # match_width sets the content's CSS width from the trigger's (integer) offsetWidth,
    # so compare that instead of the fractional getBoundingClientRect widths above.
    assert_equal page.evaluate_script('arguments[0].offsetWidth', trigger),
                 page.evaluate_script('arguments[0].offsetWidth', content)
  end

  test 'DD5: Tab closes the menu and moves focus on; Shift+Tab closes it and leaves focus on the trigger' do
    visit dropdown_path
    trigger = menu_trigger

    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    first_item = find("[role='menu'] a[role='menuitem']", text: 'Edit')
    first_item.send_keys(:tab)
    assert_equal 'false', trigger['aria-expanded']
    refute focused?(first_item)

    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    find("[role='menu'] a[role='menuitem']", text: 'Edit').send_keys(%i[shift tab])
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)
  end

  test 'DD6: the dialog-kind dropdown is named, focuses its input on open, and Escape returns focus to the trigger' do
    visit dropdown_path
    trigger = find("[data-ui--dropdown-target='trigger'] button", text: 'Dialog')
    content = find("[data-ui--dropdown-target='content'][role='dialog']", visible: :all)
    assert_equal 'Filter', content['aria-label']

    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    input = find("[role='dialog'] input")
    assert focused?(input)

    input.send_keys(:escape)
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)
  end

  test 'DD7: Escape closes when focus is inside or on the trigger, and honours defaultPrevented' do
    visit dropdown_path
    trigger = menu_trigger

    # 1. Click on plain text inside the content (not an item): focus lands on <body>,
    # so the document-level Escape listener closes it and returns focus to the trigger.
    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    content_wrapper = find("[data-ui--dropdown-target='content'] > div", visible: true)
    wrapper_rect = page.evaluate_script('arguments[0].getBoundingClientRect()', content_wrapper)
    click_at_point(wrapper_rect['left'] + (wrapper_rect['width'] / 2), wrapper_rect['top'] + 2)
    assert page.evaluate_script('document.activeElement === document.body')
    find('body').send_keys(:escape)
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)

    # 2. Open, focus an item, Escape: closed, focus back on the trigger.
    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    find("[role='menu'] a[role='menuitem']", text: 'Edit').send_keys(:escape)
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)

    # 3. Dropdown (unlike Popover) also closes as soon as focus leaves it at all -- see
    # DD5 -- so moving focus to an unrelated button already closes it before Escape is
    # pressed. What must hold is that Escape afterwards is a no-op: it doesn't reopen
    # anything and doesn't steal focus back from that button.
    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    page.execute_script(<<~JS)
      var btn = document.createElement('button')
      btn.id = 'dd7-outside'
      btn.textContent = 'Outside'
      document.body.appendChild(btn)
      btn.focus()
    JS
    outside = find('#dd7-outside')
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(outside)
    outside.send_keys(:escape)
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(outside)

    # 4. A capture-phase listener that preventDefault()s the first Escape blocks it;
    # the second Escape goes through normally.
    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    page.execute_script(<<~JS)
      window.__dd7PreventCount = 0
      document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && window.__dd7PreventCount < 1) {
          window.__dd7PreventCount++
          e.preventDefault()
        }
      }, true)
    JS
    find("[role='menu'] a[role='menuitem']", text: 'Edit').send_keys(:escape)
    assert_equal 'true', trigger['aria-expanded']
    find("[role='menu'] a[role='menuitem']", text: 'Edit').send_keys(:escape)
    assert_equal 'false', trigger['aria-expanded']
  end

  test 'DD8: rapid reopen clicks settle into a fully open, visible state' do
    visit dropdown_path
    trigger = menu_trigger

    # The bug was timing-specific (close then reopen inside 100ms): reproduce the
    # exact cadence rather than a single click.
    trigger.click
    sleep 0.3
    trigger.click
    sleep 0.03
    trigger.click

    sleep 0.5
    assert_equal 'true', trigger['aria-expanded']
    assert_selector "[role='menu']", visible: true
  end

  private

  def menu_trigger
    find("[data-ui--dropdown-target='trigger'] button", text: 'Menu')
  end

  def focused?(element)
    page.evaluate_script('document.activeElement === arguments[0]', element)
  end

  # A real pointer click at viewport coordinates -- element.click() doesn't shift focus
  # the way a genuine mousedown does, and this test depends on focus landing on <body>.
  def click_at_point(point_x, point_y)
    page.driver.browser.action.move_to_location(point_x.to_i, point_y.to_i).click.perform
  end
end
