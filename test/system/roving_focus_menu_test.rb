# frozen_string_literal: true

require 'application_system_test_case'
require 'primitives_helpers'

# The roving model: real DOM focus, one tab stop, and the keyboard behaviour the shipped Dropdown
# established in 032b33c -- arrows with wrap, Home and End, disabled items focusable but inert.
class RovingFocusMenuTest < ApplicationSystemTestCase
  include PrimitivesHelpers

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit primitives_navigation_path
    page.execute_script("document.querySelector('#roving-menu').scrollIntoView({ block: 'center' })")
  end

  test 'RM1: the group is one tab stop, and it is the first enabled item' do
    assert_single_tab_stop('#roving-menu', 'primitive-menu-edit')
    assert_equal %w[0 -1 -1 -1], menu_tabindexes
  end

  test 'RM2: a trigger opens the group onto the first or the last item' do
    trigger = find('#roving-menu-trigger')
    tab_to(trigger)
    assert focused?(trigger)

    press :arrow_down
    assert_focused_item 'Edit'

    page.execute_script('arguments[0].focus()', trigger)
    press :arrow_up
    assert_focused_item 'Delete'
  end

  test 'RM3: arrows move real DOM focus and wrap at both ends, disabled items included' do
    focus_item('primitive-menu-edit')

    press :arrow_down
    assert_focused_item 'Duplicate'
    press :arrow_down
    assert_focused_item 'Archive' # aria-disabled, and navigable: this group leaves skipDisabled at its default
    press :arrow_down
    assert_focused_item 'Delete'
    press :arrow_down
    assert_focused_item 'Edit' # wrapped

    press :arrow_up
    assert_focused_item 'Delete'
    press :arrow_up
    assert_focused_item 'Archive'
  end

  test 'RM4: Home and End jump to the ends' do
    focus_item('primitive-menu-duplicate')

    press :end
    assert_focused_item 'Delete'
    press :home
    assert_focused_item 'Edit'
  end

  test 'RM5: the tab stop follows the focused item, and Tab leaves the group' do
    focus_item('primitive-menu-edit')
    press :arrow_down
    assert_focused_item 'Duplicate'
    assert_single_tab_stop('#roving-menu', 'primitive-menu-duplicate')

    press :tab
    assert_equal false, page.evaluate_script("!!document.activeElement.closest('[role=\"menu\"]')"),
                 'Tab left focus inside the group'
  end

  test 'RM6: a disabled item takes focus but is never activated' do
    record_clicks
    focus_item('primitive-menu-archive')

    press :enter
    press :space
    assert_focused_item 'Archive'
    assert_empty recorded_clicks, 'Enter or Space activated a disabled item'

    # A pointer click reaches it, and is cancelled before anything can act on it.
    find('#primitive-menu-archive').click
    assert_equal [true], recorded_clicks

    # An enabled item is activated normally: the click is not cancelled.
    reset_clicks
    find('#primitive-menu-edit').click
    assert_equal [false], recorded_clicks
  end

  test 'RM7: pointer interaction keeps the active item in step' do
    focus_item('primitive-menu-edit')

    find('#primitive-menu-delete').hover
    assert_focused_item 'Delete'
    assert_single_tab_stop('#roving-menu', 'primitive-menu-delete')

    # Focus arriving any other way moves the tab stop too.
    page.execute_script("document.querySelector('#primitive-menu-duplicate').focus()")
    assert_single_tab_stop('#roving-menu', 'primitive-menu-duplicate')
  end

  test 'RM8: activating an item announces it' do
    page.execute_script(<<~JS)
      window.__activated = []
      document.querySelector('#roving-menu [data-controller]').addEventListener('ui--roving-focus:activated', (event) => {
        window.__activated.push([event.detail.id, event.detail.index])
      })
    JS

    focus_item('primitive-menu-edit')
    press :arrow_down

    assert_equal [['primitive-menu-duplicate', 1]], page.evaluate_script('window.__activated').last(1)
  end

  test 'RM9: a horizontal group answers to the left and right arrows only, skips disabled items and clamps' do
    focus_item('roving-toolbar-bold')

    press :arrow_down
    assert_focused_item 'Bold' # vertical keys are not this group's

    press :arrow_right
    assert_focused_item 'Italic'
    press :arrow_right
    assert_focused_item 'Strike' # Underline is disabled, and this group skips disabled items
    press :arrow_right
    assert_focused_item 'Strike' # loop is off: the end clamps

    press :arrow_left
    assert_focused_item 'Italic'
    press :arrow_left
    assert_focused_item 'Bold'
    press :arrow_left
    assert_focused_item 'Bold'
  end

  test 'RM10: a skipped disabled item is never the tab stop, and Home and End skip it too' do
    focus_item('roving-toolbar-italic')

    press :end
    assert_focused_item 'Strike'
    press :home
    assert_focused_item 'Bold'

    assert_single_tab_stop('#roving-toolbar', 'roving-toolbar-bold')
    assert_equal '-1', find('#roving-toolbar-underline')['tabindex']
  end

  test 'RM12: a natively disabled item is never focused and never the tab stop, though an aria-disabled one is' do
    page.execute_script(<<~JS)
      const group = document.createElement('div')
      group.id = 'roving-native-disabled'
      group.setAttribute('role', 'menu')
      group.setAttribute('aria-label', 'Native disabled')
      group.setAttribute('data-controller', 'ui--roving-focus')
      group.innerHTML = `
        <button type="button" role="menuitem" id="native-one" data-ui--roving-focus-target="item">One</button>
        <button type="button" role="menuitem" id="native-two" disabled data-ui--roving-focus-target="item">Two</button>
        <button type="button" role="menuitem" id="native-three" aria-disabled="true" data-ui--roving-focus-target="item">Three</button>`
      document.querySelector('#roving-menu').appendChild(group)
    JS

    assert_single_tab_stop('#roving-native-disabled', 'native-one')
    focus_item('native-one')

    # A `disabled` control cannot take focus or be tabbed to, so it would be a dead end in both
    # directions; aria-disabled is the attribute that keeps an item discoverable, as Three is.
    press :arrow_down
    assert_focused_item 'Three'
    assert_single_tab_stop('#roving-native-disabled', 'native-three')
    assert_equal '-1', find('#native-two')['tabindex']

    press :arrow_down
    assert_focused_item 'One'
  end

  test 'RM11: a page restored from Turbo\'s cache keeps each group\'s position without pulling focus in' do
    focus_item('primitive-menu-delete')
    input = find('#roving-listbox-input')
    page.execute_script('arguments[0].focus()', input)
    press :arrow_down, :arrow_down

    page.execute_script('Turbo.visit(arguments[0])', installation_path)
    assert_selector 'h1', text: 'Installation'
    page.go_back
    assert_selector 'h1', text: 'Positioning'

    assert_equal false, page.evaluate_script("!!document.activeElement.closest('[data-controller~=\"ui--roving-focus\"]')"),
                 'restoring the page pulled focus into a group'

    # The stored activeId is the position: one tab stop, on the item that had it.
    assert_single_tab_stop('#roving-menu', 'primitive-menu-delete')

    # The listbox's attribute and class agree with each other, not with a stale snapshot.
    restored = find('#roving-listbox-input')
    assert_equal 'roving-option-apple', restored['aria-activedescendant']
    active = all('#roving-listbox [role="option"]').select { |option| option[:class].include?('bg-neutral-900') }
    assert_equal(['roving-option-apple'], active.map { |option| option[:id] })

    # And the controllers are live: the keyboard still works from where it left off.
    focus_item('primitive-menu-delete')
    press :arrow_up
    assert_focused_item 'Archive'
  end

  private

  def menu_tabindexes
    all('#roving-menu [data-ui--roving-focus-target="item"]').map { |item| item['tabindex'] }
  end

  def focus_item(id)
    page.execute_script('document.getElementById(arguments[0]).focus()', id)
    assert focused?(find("##{id}"))
  end

  def record_clicks
    page.execute_script(<<~JS)
      window.__clicks = []
      window.addEventListener('click', (event) => {
        if (event.target.closest('[role="menuitem"]')) window.__clicks.push(event.defaultPrevented)
      })
    JS
  end

  def reset_clicks
    page.execute_script('window.__clicks = []')
  end

  def recorded_clicks
    page.evaluate_script('window.__clicks')
  end
end
