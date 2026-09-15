# frozen_string_literal: true

require 'application_system_test_case'
require 'primitives_helpers'

# Turbo Stream updates are the normal case for a group's items, not an edge case: after any of
# them the group still has exactly one tab stop, and a removed active item does not strand focus.
class RovingFocusDynamicTest < ApplicationSystemTestCase
  include PrimitivesHelpers

  setup do
    visit primitives_navigation_path
    page.execute_script("document.querySelector('#roving-menu').scrollIntoView({ block: 'center' })")
  end

  test 'RD1: removing the focused active item moves the position, and focus, to the next one' do
    focus_item('primitive-menu-duplicate')
    assert_single_tab_stop('#roving-menu', 'primitive-menu-duplicate')

    stream(%(<turbo-stream action="remove" target="primitive-menu-duplicate"></turbo-stream>))
    assert_no_selector '#primitive-menu-duplicate'

    assert_focused_item 'Archive'
    assert_single_tab_stop('#roving-menu', 'primitive-menu-archive')
  end

  test 'RD2: removing the last item clamps back to the previous one' do
    focus_item('primitive-menu-delete')

    stream(%(<turbo-stream action="remove" target="primitive-menu-delete"></turbo-stream>))
    assert_no_selector '#primitive-menu-delete'

    assert_single_tab_stop('#roving-menu', 'primitive-menu-archive')
  end

  test 'RD3: removing an item that is not the active one leaves the position alone' do
    focus_item('primitive-menu-edit')

    stream(%(<turbo-stream action="remove" target="primitive-menu-delete"></turbo-stream>))
    assert_no_selector '#primitive-menu-delete'

    assert_single_tab_stop('#roving-menu', 'primitive-menu-edit')
    assert focused?(find('#primitive-menu-edit'))
  end

  test 'RD4: removing the active item while focus is elsewhere does not pull focus into the group' do
    focus_item('primitive-menu-edit')
    trigger = find('#roving-menu-trigger')
    page.execute_script('arguments[0].focus()', trigger)

    stream(%(<turbo-stream action="remove" target="primitive-menu-edit"></turbo-stream>))
    assert_no_selector '#primitive-menu-edit'

    assert focused?(trigger), 'focus was pulled into the group by a Turbo Stream update'
    assert_single_tab_stop('#roving-menu', 'primitive-menu-duplicate')
  end

  test 'RD5: an appended item joins the group and the group still has one tab stop' do
    stream(<<~HTML)
      <turbo-stream action="append" target="roving-menu-items"><template>
        <button type="button" role="menuitem" id="primitive-menu-export"
                class="block w-full text-left rounded px-3 py-1.5 text-sm"
                data-ui--roving-focus-target="item">Export</button>
      </template></turbo-stream>
    HTML

    assert_selector '#primitive-menu-export'
    assert_single_tab_stop('#roving-menu', 'primitive-menu-edit')

    focus_item('primitive-menu-delete')
    press :arrow_down
    assert_focused_item 'Export'
    assert_single_tab_stop('#roving-menu', 'primitive-menu-export')
  end

  test 'RD6: replacing the whole list leaves exactly one tabbable item' do
    focus_item('primitive-menu-delete')

    stream(<<~HTML)
      <turbo-stream action="update" target="roving-menu-items"><template>
        <button type="button" role="menuitem" id="primitive-menu-one" data-ui--roving-focus-target="item">One</button>
        <button type="button" role="menuitem" id="primitive-menu-two" data-ui--roving-focus-target="item">Two</button>
      </template></turbo-stream>
    HTML

    assert_selector '#primitive-menu-one'
    assert_no_selector '#primitive-menu-delete'
    assert_single_tab_stop('#roving-menu', 'primitive-menu-one')
  end

  test 'RD7: in a group that skips disabled items, an update never leaves the tab stop on one' do
    assert_single_tab_stop('#roving-toolbar', 'roving-toolbar-bold')

    page.execute_script(<<~JS)
      document.querySelector('#roving-toolbar-bold').setAttribute('aria-disabled', 'true')
      Turbo.renderStreamMessage('<turbo-stream action="remove" target="roving-toolbar-strike"></turbo-stream>')
    JS

    assert_no_selector '#roving-toolbar-strike'
    # Bold is disabled now and Underline already was: the nearest enabled item is Italic.
    assert_single_tab_stop('#roving-toolbar', 'roving-toolbar-italic')
  end

  private

  def stream(html)
    page.execute_script('Turbo.renderStreamMessage(arguments[0])', html)
  end

  def focus_item(id)
    page.execute_script('document.getElementById(arguments[0]).focus()', id)
    assert focused?(find("##{id}"))
  end
end
