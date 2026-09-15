# frozen_string_literal: true

require 'application_system_test_case'

class DropdownTest < ApplicationSystemTestCase
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
    assert_expanded 'false', trigger
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
    assert_expanded 'false', trigger
    assert_focused trigger

    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    find("[role='menu'] a[role='menuitem']", text: 'Edit').send_keys(:enter)
    assert_expanded 'false', trigger
    assert_focused trigger
  end

  test 'DD3: opening one dropdown closes another that was open' do
    visit dropdown_path
    trigger_menu = menu_trigger
    trigger_dialog = find("[data-ui--dropdown-target='trigger'] button", text: 'Dialog')

    trigger_menu.click
    assert_equal 'true', trigger_menu['aria-expanded']

    trigger_dialog.click
    assert_equal 'true', trigger_dialog['aria-expanded']
    assert_expanded 'false', trigger_menu
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
    assert_expanded 'false', trigger
    refute focused?(first_item)

    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    find("[role='menu'] a[role='menuitem']", text: 'Edit').send_keys(%i[shift tab])
    assert_expanded 'false', trigger
    assert_focused trigger
  end

  test 'DD6: the dialog-kind dropdown is named, focuses its input on open, and Escape returns focus to the trigger' do
    visit dropdown_path
    trigger = find("[data-ui--dropdown-target='trigger'] button", text: 'Dialog')
    content = find("[data-ui--dropdown-target='content'][role='dialog']", visible: :all)
    assert_equal 'Filter', content['aria-label']

    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    input = find("[role='dialog'] input")
    assert_focused input

    input.send_keys(:escape)
    assert_expanded 'false', trigger
    assert_focused trigger
  end

  test 'DD7: Escape closes when focus is inside or on the trigger, and honours defaultPrevented' do
    visit dropdown_path
    trigger = menu_trigger

    # 1. Click on plain text inside the content (not an item): focus lands on <body>,
    # and Escape still closes it and returns focus to the trigger.
    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    content_wrapper = find("[data-ui--dropdown-target='content'] > div", visible: true)
    wrapper_rect = page.evaluate_script('arguments[0].getBoundingClientRect()', content_wrapper)
    click_at(wrapper_rect['left'] + (wrapper_rect['width'] / 2), wrapper_rect['top'] + 2)
    assert page.evaluate_script('document.activeElement === document.body')
    find('body').send_keys(:escape)
    assert_expanded 'false', trigger
    assert_focused trigger

    # 2. Open, focus an item, Escape: closed, focus back on the trigger.
    trigger.click
    assert_equal 'true', trigger['aria-expanded']
    find("[role='menu'] a[role='menuitem']", text: 'Edit').send_keys(:escape)
    assert_expanded 'false', trigger
    assert_focused trigger

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
    assert_expanded 'false', trigger
    assert_focused outside
    outside.send_keys(:escape)
    assert_expanded 'false', trigger
    assert_focused outside

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
    # Past the frame a dismissal would take, so a close that was only late can't pass as none.
    sleep 0.3
    assert_equal 'true', trigger['aria-expanded']
    find("[role='menu'] a[role='menuitem']", text: 'Edit').send_keys(:escape)
    assert_expanded 'false', trigger
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
    assert_focused trigger

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
    assert_expanded 'false', trigger
    assert_focused trigger

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
    assert_expanded 'false', trigger
    assert_focused trigger

    open_menu_with_keyboard
    press :space
    assert_equal 'Edit', last_activated_item
    assert_expanded 'false', trigger
    assert_focused trigger
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
    assert_focused trigger
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
    assert_expanded 'false', trigger
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

  test 'DD17: a menu dropdown with a non-default item set is fully operable from the keyboard' do
    visit dropdown_path
    # A real ui--dropdown menu instance, cloned rather than reached via a hosting docs
    # page, so this test's keyboard assertions don't depend on any particular page's markup.
    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--dropdown'][data-ui--dropdown-kind-value='menu']")
      var container = document.createElement('div')
      container.id = 'dd17'
      var clone = original.cloneNode(true)
      var trigger = clone.querySelector("[data-ui--dropdown-target='trigger'] button")
      trigger.textContent = 'Billing options'
      trigger.setAttribute('aria-label', 'Billing options')
      clone.querySelector("[data-ui--dropdown-target='content']").innerHTML = `
        <div class="py-1 min-w-[12rem]">
          <a href="#" role="menuitem" class="flex px-3 py-2 text-sm text-neutral-700 dark:text-neutral-200 hover:bg-neutral-100 dark:hover:bg-neutral-700">Change plan</a>
          <a href="#" role="menuitem" class="flex px-3 py-2 text-sm text-neutral-700 dark:text-neutral-200 hover:bg-neutral-100 dark:hover:bg-neutral-700">Update payment method</a>
          <a href="#" role="menuitem" class="flex px-3 py-2 text-sm text-neutral-700 dark:text-neutral-200 hover:bg-neutral-100 dark:hover:bg-neutral-700">Cancel subscription</a>
        </div>`
      container.appendChild(clone)
      document.body.appendChild(container)
    JS
    prevent_menu_item_navigation
    trigger = find("#dd17 button[aria-label='Billing options']")

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
    assert_expanded 'false', trigger
    assert_focused trigger
  end

  test 'DD18: the open menu passes an axe audit' do
    visit dropdown_path
    open_menu_with_keyboard

    assert_accessible(within: "[data-ui--dropdown-kind-value='menu']")
  end

  test 'DD19: legacy ui--dropdown positioning attributes still position the menu, and each warns once' do
    visit dropdown_path
    install_console_warning_capture
    # The open classes land when the 100ms scale transition starts, not when it ends, so waiting
    # on them alone sometimes measured a menu still scaling in from its origin.
    disable_transitions

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
    assert_selector "#dd19-container [data-ui--dropdown-target='content'][data-state='open']"

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
      // As in DD19: the panel is positioned against the viewport now, and this clone sits at the
      // page's foot, so flip would answer how much room is below rather than which value won.
      clone.setAttribute('data-ui--anchor-flip-value', 'false')
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

  test 'DD21: a menu missing its ui--anchor or ui--roving-focus companion still opens, never throws, and warns once naming each' do
    visit dropdown_path
    install_console_warning_capture
    install_error_capture

    # Markup that dropped ui--anchor from the wrapper and ui--roving-focus from the content --
    # old copy-paste predating 144d104, say. Positioning and roving keyboard nav are gone, but
    # opening the menu must not error, and each missing companion must say so once. ui--overlay,
    # which opens it, stays: the wrapper loses only ui--anchor.
    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--dropdown'][data-ui--dropdown-kind-value='menu']")
      var container = document.createElement('div')
      container.id = 'dd21-container'
      container.style.cssText = 'width:600px;display:block;margin-left:320px'
      var clone = original.cloneNode(true)
      clone.setAttribute('data-controller', 'ui--dropdown ui--overlay')
      clone.querySelector("[data-ui--dropdown-target='content']").removeAttribute('data-controller')
      container.appendChild(clone)
      document.body.appendChild(container)
    JS

    container = find('#dd21-container', visible: :all)
    trigger = container.find("[data-ui--dropdown-target='trigger'] button")
    trigger.click

    assert_selector "#dd21-container [data-ui--dropdown-target='content'][data-state='open']"
    assert_empty captured_errors

    warnings = console_warnings
    assert warnings.any? { |warning| warning.include?('ui--anchor') && warning.include?('positioning') },
           "expected a warning naming the missing ui--anchor companion, got: #{warnings}"
    assert warnings.any? { |warning| warning.include?('ui--roving-focus') && warning.include?('arrow keys') },
           "expected a warning naming the missing ui--roving-focus companion, got: #{warnings}"
  end

  # A correct Dropdown used to warn "no ui--anchor controller found" on every page load: connect
  # looked the anchor up before ui--anchor had connected.
  test 'DD22: a complete Dropdown connects without a missing-companion warning' do
    visit dropdown_path
    install_console_warning_capture

    clone_menu('dd22')
    assert_selector '#dd22 [data-ui--dropdown-target="trigger"] button[aria-haspopup="menu"]'
    find('#dd22 [data-ui--dropdown-target="trigger"] button').click
    assert_selector "#dd22 [data-ui--dropdown-target='content'][data-state='open']"

    assert_empty console_warnings.grep(/ui--dropdown: no /)
  end

  test 'DD23: Dropdown binds its own trigger, and a hand-wired toggle beside it still opens once' do
    visit dropdown_path

    # Markup written before Dropdown bound its trigger carries click->ui--dropdown#toggle too: one
    # click is one toggle, not two that cancel out.
    wired = menu_trigger
    page.execute_script("arguments[0].setAttribute('data-action', 'click->ui--dropdown#toggle')", wired)
    assert_equal 'click->ui--dropdown#toggle', wired['data-action']
    wired.click
    sleep 0.3
    assert_equal 'true', wired['aria-expanded']
    press :escape
    assert_expanded 'false', wired

    clone_menu('dd23')
    page.execute_script("document.querySelector('#dd23 [data-ui--dropdown-target=\"trigger\"] button').removeAttribute('data-action')")
    bare = find('#dd23 [data-ui--dropdown-target="trigger"] button')
    bare.click
    assert_expanded 'true', bare
  end

  test "DD24: Dropdown's lifecycle events are ui--overlay's, including a Tab close" do
    visit dropdown_path
    page.execute_script(<<~JS)
      window.__ddEvents = []
      var dropdown = document.querySelector("[data-controller~='ui--dropdown'][data-ui--dropdown-kind-value='menu']")
      ;['opened', 'dismiss', 'closed'].forEach(function(name) {
        dropdown.addEventListener('ui--overlay:' + name, function(event) {
          if (event.target === dropdown) window.__ddEvents.push(name + (event.detail.reason ? ':' + event.detail.reason : ''))
        })
      })
    JS
    trigger = menu_trigger

    trigger.click
    assert_focused_item 'Edit'
    press :escape
    assert_expanded 'false', trigger
    assert_selector "[data-ui--dropdown-kind-value='menu'] [data-ui--dropdown-target='content'][data-state='closed']", visible: :all
    assert_equal %w[opened dismiss:escape closed], page.evaluate_script('window.__ddEvents')

    trigger.click
    assert_focused_item 'Edit'
    press :tab
    assert_expanded 'false', trigger
    assert_equal %w[opened dismiss:escape closed opened closed], page.evaluate_script('window.__ddEvents')
  end

  # Nesting is not a special case (ui-component-library rule 7): a menu opened inside a modal is
  # painted above it and is the first thing Escape closes.
  test 'DD25: a menu inside a modal is painted above it, and Escape closes the menu before the modal' do
    visit dropdown_path
    page.execute_script(<<~JS)
      var original = document.querySelector("[data-controller~='ui--dropdown'][data-ui--dropdown-kind-value='menu']")
      var wrapper = document.createElement('div')
      Object.entries({
        'id': 'dd25-modal', 'data-controller': 'ui--modal ui--overlay',
        'data-ui--overlay-mode-value': 'modal', 'data-ui--overlay-open-value': 'true',
        'data-action': 'ui--overlay:dismiss->ui--modal#guardDismiss:self ui--overlay:closed->ui--modal#remove:self'
      }).forEach(function([name, value]) { wrapper.setAttribute(name, value) })
      var dialog = document.createElement('dialog')
      dialog.setAttribute('data-ui--overlay-target', 'content')
      dialog.className = 'fixed top-4 left-4 m-0 p-6 w-80 h-40 overflow-hidden'
      dialog.appendChild(original.cloneNode(true))
      wrapper.appendChild(dialog)
      document.body.appendChild(wrapper)
    JS
    assert_selector '#dd25-modal dialog[open]'

    trigger = find('#dd25-modal [data-ui--dropdown-target="trigger"] button')
    trigger.click
    assert_expanded 'true', trigger
    assert_selector "#dd25-modal [role='menuitem']:focus", text: 'Edit'

    content = find("#dd25-modal [data-ui--dropdown-target='content']")
    assert page.evaluate_script("arguments[0].matches(':popover-open')", content)
    # The dialog clips its overflow, so a panel that were painted inside it would be cut off here.
    item = find("#dd25-modal [role='menuitem']", text: 'Delete')
    assert page.evaluate_script(<<~JS, item)
      (function(item) {
        var rect = item.getBoundingClientRect()
        return item.contains(document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2))
      })(arguments[0])
    JS

    press :escape
    assert_expanded 'false', trigger
    assert_selector '#dd25-modal dialog[open]'

    press :escape
    assert_no_selector '#dd25-modal'
  end

  private

  def clone_menu(id)
    page.execute_script(<<~JS, id)
      var original = document.querySelector("[data-controller~='ui--dropdown'][data-ui--dropdown-kind-value='menu']")
      var container = document.createElement('div')
      container.id = arguments[0]
      container.style.cssText = 'position:fixed;top:40px;left:40px;z-index:1000'
      container.appendChild(original.cloneNode(true))
      document.body.appendChild(container)
    JS
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

  # The demo items are href="#" links, which would scroll the page to the top and could
  # take the trigger out of view. Record the activation and cancel it instead.
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

  # ui--overlay closes an Escaped layer on the next frame and returns focus once its exit animation
  # has finished, so these wait the way any Capybara assertion does (as popover_test.rb's do).
  def assert_expanded(expected, trigger)
    trigger.synchronize do
      actual = trigger['aria-expanded']
      raise Capybara::ExpectationNotMet, "aria-expanded is #{actual.inspect}" unless actual == expected
    end
    assert_equal expected, trigger['aria-expanded']
  end

  def assert_focused(element)
    element.synchronize { raise Capybara::ExpectationNotMet, 'not focused' unless focused?(element) }
    assert focused?(element)
  end
end
