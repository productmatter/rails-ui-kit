# frozen_string_literal: true

require 'application_system_test_case'
require 'primitives_helpers'

class RovingFocusTypeaheadTest < ApplicationSystemTestCase
  include PrimitivesHelpers

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit primitives_navigation_path
    page.execute_script("document.querySelector('#roving-menu').scrollIntoView({ block: 'center' })")
  end

  test 'RT1: typing moves to the item that starts with what was typed' do
    focus_item('primitive-menu-edit')

    press 'd', 'u'
    assert_focused_item 'Duplicate'
  end

  test 'RT2: a fresh single character steps through the items that share an initial' do
    focus_item('primitive-menu-edit')

    press 'd'
    assert_focused_item 'Duplicate'
    idle
    press 'd'
    assert_focused_item 'Delete'
    idle
    press 'd'
    assert_focused_item 'Duplicate'
  end

  test 'RT3: the same character repeated inside the timeout also steps, rather than matching nothing' do
    focus_item('primitive-menu-edit')

    press 'd', 'd'
    assert_focused_item 'Delete'
  end

  test 'RT4: the buffer resets after typeaheadTimeout' do
    focus_item('primitive-menu-edit')

    press 'd', 'e'
    assert_focused_item 'Delete'

    # Inside the timeout the buffer would be "dea", which matches nothing and leaves focus put.
    press 'a'
    assert_focused_item 'Delete'

    idle
    press 'a'
    assert_focused_item 'Archive' # a fresh buffer; disabled, and reachable, in this group
  end

  test 'RT5: aria-label is matched ahead of the visible text' do
    page.execute_script("document.getElementById('primitive-menu-delete').setAttribute('aria-label', 'Remove permanently')")
    focus_item('primitive-menu-edit')

    press 'r'
    assert_focused_item 'Delete'

    idle
    press 'd'
    assert_focused_item 'Duplicate' # "Delete" is no longer its name
  end

  test 'RT6: a group that skips disabled items skips them in typeahead too' do
    page.execute_script(<<~JS)
      const group = document.createElement('div')
      group.id = 'typeahead-skip'
      group.setAttribute('role', 'toolbar')
      group.setAttribute('aria-label', 'Typeahead skip')
      group.setAttribute('data-controller', 'ui--roving-focus')
      group.setAttribute('data-ui--roving-focus-typeahead-value', 'true')
      group.setAttribute('data-ui--roving-focus-skip-disabled-value', 'true')
      group.innerHTML = `
        <button type="button" id="skip-copy" data-ui--roving-focus-target="item">Copy</button>
        <button type="button" id="skip-cut" aria-disabled="true" data-ui--roving-focus-target="item">Cut</button>
        <button type="button" id="skip-crop" data-ui--roving-focus-target="item">Crop</button>`
      document.querySelector('#roving-menu').appendChild(group)
    JS
    assert_selector '#skip-copy[tabindex="0"]'
    focus_item('skip-copy')

    press 'c'
    assert_focused_item 'Crop'
    idle
    press 'c'
    assert_focused_item 'Copy'
  end

  test 'RT7: typeahead is off unless the group asks for it' do
    page.execute_script("document.querySelector('#roving-toolbar').scrollIntoView({ block: 'center' })")
    focus_item('roving-toolbar-bold')

    press 'i'
    assert_focused_item 'Bold'
  end

  test 'RT8: modified keys are not typeahead' do
    focus_item('primitive-menu-edit')

    page.driver.browser.action.key_down(:control).send_keys('d').key_up(:control).perform
    assert_focused_item 'Edit'
  end

  private

  # Longer than the demo groups' 500ms typeaheadTimeout.
  def idle
    sleep 0.6
  end

  def focus_item(id)
    page.execute_script('document.getElementById(arguments[0]).focus()', id)
    assert focused?(find("##{id}"))
  end
end
