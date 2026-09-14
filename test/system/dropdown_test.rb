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
      clone.setAttribute('data-ui--anchor-placement-value', 'bottom-end')
      clone.setAttribute('data-ui--anchor-match-width-value', 'true')
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

  test 'DD9: Tab reaches the trigger and Space opens the menu with focus on the first item' do
    visit dropdown_path
    trigger = menu_trigger

    tab_to(trigger)
    assert focused?(trigger)

    press :space
    assert_equal 'true', trigger['aria-expanded']
    assert_focused_item 'Edit'
  end

  test 'DD10: ArrowDown and ArrowUp move and wrap, Home and End jump to the ends' do
    visit dropdown_path
    open_menu_with_keyboard

    press :arrow_down
    assert_focused_item 'Duplicate'
    # Archive is aria-disabled, and still takes focus in both directions.
    press :arrow_down
    assert_focused_item 'Archive'
    press :arrow_down
    assert_focused_item 'Delete'
    press :arrow_down
    assert_focused_item 'Edit'

    press :arrow_up
    assert_focused_item 'Delete'
    press :arrow_up
    assert_focused_item 'Archive'

    press :end
    assert_focused_item 'Delete'
    press :home
    assert_focused_item 'Edit'
  end

  test 'DD11: arrow keys on the closed trigger open the menu at the first or last item' do
    visit dropdown_path
    trigger = menu_trigger

    page.execute_script('arguments[0].focus()', trigger)
    press :arrow_up
    assert_equal 'true', trigger['aria-expanded']
    assert_focused_item 'Delete'

    press :escape
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)

    press :arrow_down
    assert_equal 'true', trigger['aria-expanded']
    assert_focused_item 'Edit'
  end

  test 'DD12: typing moves to the item that starts with what was typed' do
    visit dropdown_path
    open_menu_with_keyboard

    press 'd', 'u'
    assert_focused_item 'Duplicate'

    # A fresh single character searches on from the focused item, so it steps between the
    # items sharing an initial rather than sticking on the first of them.
    sleep 0.6
    press 'd'
    assert_focused_item 'Delete'
    sleep 0.6
    press 'd'
    assert_focused_item 'Duplicate'

    # The disabled item is reachable by typeahead too.
    sleep 0.6
    press 'a'
    assert_focused_item 'Archive'
  end

  test 'DD13: Enter and Space activate the focused item and close the menu' do
    visit dropdown_path
    prevent_menu_item_navigation
    trigger = menu_trigger

    open_menu_with_keyboard
    press :arrow_down
    assert_focused_item 'Duplicate'
    press :enter
    assert_equal 'Duplicate', last_activated_item
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)

    open_menu_with_keyboard
    press :space
    assert_equal 'Edit', last_activated_item
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)
  end

  test 'DD14: an aria-disabled item takes focus but Enter, Space and a click neither activate it nor close the menu' do
    visit dropdown_path
    trigger = menu_trigger
    # Point the disabled item at a real page, so a guard that failed would visibly navigate
    # away. Record every click on a menu item that reaches the window, without cancelling any.
    archive = find("[role='menu'] [role='menuitem']", text: 'Archive', visible: false)
    page.execute_script("arguments[0].setAttribute('href', arguments[1])", archive, installation_path)
    page.execute_script(<<~JS)
      window.__ddClicks = []
      window.addEventListener('click', function(event) {
        if (event.target.closest('[role="menuitem"]')) window.__ddClicks.push(event.defaultPrevented)
      })
    JS

    open_menu_with_keyboard
    press :arrow_down, :arrow_down
    assert_focused_item 'Archive'

    # Enter on a link would normally dispatch a click and follow the href; Space would be
    # clicked by the controller. Neither may happen.
    press :enter
    press :space
    assert_focused_item 'Archive'
    assert_equal 'true', trigger['aria-expanded']
    assert_empty page.evaluate_script('window.__ddClicks')

    # A pointer click does reach the item, and is cancelled before it can navigate.
    find("[role='menu'] [role='menuitem']", text: 'Archive').click
    assert_equal [true], page.evaluate_script('window.__ddClicks')
    assert_equal 'true', trigger['aria-expanded']

    # Give any navigation that slipped through time to land before checking it didn't.
    sleep 0.5
    assert_current_path dropdown_path
    assert_selector 'h1', text: 'Dropdown'

    # Opening from the trigger lands on the end item even when that item is disabled.
    press :escape
    assert focused?(trigger)
    delete_item = find("[role='menu'] [role='menuitem']", text: 'Delete', visible: false)
    page.execute_script("arguments[0].setAttribute('aria-disabled', 'true')", delete_item)
    press :arrow_up
    assert_equal 'true', trigger['aria-expanded']
    assert_focused_item 'Delete'
  end

  test 'DD15: the menu is one tab stop -- only the focused item is tabindex="0" and Tab leaves the menu' do
    visit dropdown_path
    trigger = menu_trigger
    open_menu_with_keyboard

    # ui--roving-focus's model: the tab stop moves with focus, and every other item is -1.
    assert_equal %w[0 -1 -1 -1], menu_tabindexes
    press :arrow_down
    assert_focused_item 'Duplicate'
    assert_equal %w[-1 0 -1 -1], menu_tabindexes

    press :tab
    assert_equal 'false', trigger['aria-expanded']
    refute page.evaluate_script('!!document.activeElement.closest(\'[role="menuitem"]\')')

    # Closed, the tabindex="0" item is not rendered, so the trigger is the menu's only tab stop.
    page.execute_script('arguments[0].focus()', trigger)
    press :tab
    refute page.evaluate_script('!!document.activeElement.closest(\'[role="menuitem"]\')')
  end

  test 'DD16: a menu of plain links with no roles is navigable and is given menuitem roles' do
    visit dropdown_path
    # The rendered Menu dropdown with its slot swapped for role-less host markup.
    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--dropdown'][data-ui--dropdown-kind-value='menu']")
      var container = document.createElement('div')
      container.id = 'dd16'
      var clone = original.cloneNode(true)
      clone.querySelector("[data-ui--dropdown-target='trigger'] button").textContent = 'Plain'
      clone.querySelector("[data-ui--dropdown-target='content']").innerHTML = `
        <a href="#">Alpha</a>
        <a href="#">Beta</a>
        <button type="button">Gamma</button>`
      container.appendChild(clone)
      document.body.appendChild(container)
    JS

    trigger = find('#dd16 button', text: 'Plain')
    page.execute_script('arguments[0].focus()', trigger)
    press :space
    assert_equal 'true', trigger['aria-expanded']

    within('#dd16') do
      assert_selector "[role='menu'] [role='menuitem']", count: 3, visible: true
      assert_focused_item 'Alpha'
      press :arrow_down
      assert_focused_item 'Beta'
      press :end
      assert_focused_item 'Gamma'
      press :arrow_down
      assert_focused_item 'Alpha'
    end
  end

  test "DD17: the Card header's dropdown is fully operable from the keyboard" do
    visit card_path
    prevent_menu_item_navigation
    trigger = find("button[aria-label='Billing options']")

    tab_to(trigger)
    press :enter
    assert_equal 'true', trigger['aria-expanded']
    assert_focused_item 'Change plan'

    press :arrow_up
    assert_focused_item 'Cancel subscription'
    press 'u'
    assert_focused_item 'Update payment method'

    press :enter
    assert_equal 'Update payment method', last_activated_item
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)
  end

  test 'DD18: the open menu passes an axe audit' do
    visit dropdown_path
    open_menu_with_keyboard

    assert_accessible(within: "[data-ui--dropdown-kind-value='menu']")
  end

  test 'DD19: legacy ui--dropdown positioning attributes still position the menu, and each warns once' do
    visit dropdown_path
    install_console_warning_capture

    # A pre-144d104 integration: placement, offset and match-width written the old way, with
    # no ui--anchor-* attributes of their own. Flip and shift are turned off so the assertions
    # below depend only on the shim's forwarding, not on how much room this viewport happens
    # to have above the trigger.
    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--dropdown'][data-ui--dropdown-kind-value='menu']")
      var container = document.createElement('div')
      container.id = 'dd19-container'
      container.style.cssText = 'width:600px;display:block;margin-left:320px'
      var clone = original.cloneNode(true)
      clone.removeAttribute('data-ui--anchor-placement-value')
      clone.removeAttribute('data-ui--anchor-offset-value')
      clone.removeAttribute('data-ui--anchor-match-width-value')
      clone.setAttribute('data-ui--anchor-flip-value', 'false')
      clone.setAttribute('data-ui--anchor-shift-value', 'false')
      clone.setAttribute('data-ui--dropdown-placement-value', 'top-end')
      clone.setAttribute('data-ui--dropdown-offset-value', '4')
      clone.setAttribute('data-ui--dropdown-match-width-value', 'true')
      container.appendChild(clone)
      document.body.appendChild(container)
    JS

    container = find('#dd19-container', visible: :all)
    trigger = container.find("[data-ui--dropdown-target='trigger'] button")
    trigger.click

    content = container.find("[data-ui--dropdown-target='content']", visible: true)
    assert_selector "#dd19-container [data-ui--dropdown-target='content'][data-side='top'][data-align='end']"
    # Let the 100ms open transition settle -- mid-transition the content is still scaled down
    # from origin-top, which throws the edges off by more than the tolerance below.
    assert_selector "#dd19-container [data-ui--dropdown-target='content'].opacity-100.scale-100"

    trigger_rect = page.evaluate_script('arguments[0].getBoundingClientRect()', trigger)
    content_rect = page.evaluate_script('arguments[0].getBoundingClientRect()', content)
    assert_in_delta trigger_rect['right'], content_rect['right'], 2
    assert_in_delta trigger_rect['top'] - 4, content_rect['bottom'], 2
    assert_equal page.evaluate_script('arguments[0].offsetWidth', trigger),
                 page.evaluate_script('arguments[0].offsetWidth', content)

    warnings = console_warnings
    %w[placement offset match-width].each do |name|
      assert warnings.any? { |warning|
               warning.include?("data-ui--dropdown-#{name}-value") && warning.include?("data-ui--anchor-#{name}-value")
             },
             "expected a warning naming data-ui--dropdown-#{name}-value, got: #{warnings}"
    end
  end

  test 'DD20: a caller-set ui--anchor value is not overwritten by the legacy shim' do
    visit dropdown_path
    install_console_warning_capture

    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--dropdown'][data-ui--dropdown-kind-value='menu']")
      var container = document.createElement('div')
      container.id = 'dd20-container'
      container.style.cssText = 'width:600px;display:block;margin-left:320px'
      var clone = original.cloneNode(true)
      clone.setAttribute('data-ui--anchor-placement-value', 'bottom-start')
      clone.setAttribute('data-ui--dropdown-placement-value', 'top-end')
      container.appendChild(clone)
      document.body.appendChild(container)
    JS

    container = find('#dd20-container', visible: :all)
    dropdown = container.find("[data-controller~='ui--dropdown']", visible: :all)
    assert_equal 'bottom-start', dropdown['data-ui--anchor-placement-value']

    trigger = container.find("[data-ui--dropdown-target='trigger'] button")
    trigger.click
    assert_selector "#dd20-container [data-ui--dropdown-target='content'][data-side='bottom'][data-align='start']"

    # The attribute is still legacy and still dead markup, so the shim still warns about it --
    # it just doesn't act on it, since the caller's own value wins.
    assert console_warnings.any? do |warning|
      warning.include?('data-ui--dropdown-placement-value') && warning.include?('already set')
    end
  end

  private

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

  # Sends keys to whatever currently has focus, the way a keyboard does -- unlike
  # Capybara's element.send_keys, which focuses the element it's called on first.
  def press(*keys)
    page.driver.browser.action.send_keys(*keys).perform
  end

  def tab_to(element, limit: 80)
    limit.times do
      break if focused?(element)

      press :tab
    end
    element
  end

  def open_menu_with_keyboard
    trigger = menu_trigger
    page.execute_script('arguments[0].focus()', trigger)
    press :space
    assert_equal 'true', trigger['aria-expanded']
    assert_focused_item 'Edit'
    trigger
  end

  # Waits, the way any Capybara assertion does, for focus to settle on the named item:
  # CSS :focus matches the focused element itself, never an ancestor.
  def assert_focused_item(text)
    assert_selector "[role='menuitem']:focus", text: text, exact_text: true
  end

  # The demo items are href="#" links, which would scroll the page to the top and, on the
  # Card page, take the trigger out of view. Record the activation and cancel it instead.
  def prevent_menu_item_navigation
    page.execute_script(<<~JS)
      window.__ddActivated = null
      document.addEventListener('click', function(event) {
        var item = event.target.closest('[role="menuitem"]')
        if (!item) return
        window.__ddActivated = item.textContent.trim()
        event.preventDefault()
      })
    JS
  end

  def last_activated_item
    page.evaluate_script('window.__ddActivated')
  end

  def menu_tabindexes
    all("[data-ui--dropdown-kind-value='menu'] [role='menuitem']", visible: true).map { |item| item['tabindex'] }
  end

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
