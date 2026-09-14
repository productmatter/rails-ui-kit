# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

class UiOverlayNestingTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  # The registered driver's screen_size isn't honoured for the actual window on every machine
  # (see dropdown_test.rb); the paint-order probe below needs the layer and dialog on screen.
  setup { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test 'a layer opened inside a modal paints above the dialog and is not clipped by its scroll box' do
    visit primitives_overlay_path
    open_modal_with_inner_layer

    dialog = rect_of('#modal-content')
    layer = rect_of('#inner-layer-content')
    # A scrolling dialog with a transform -- the shape of the kit's own centred Modal -- clips
    # any descendant that is not in the top layer, position: fixed or not.
    assert_equal 'auto', page.evaluate_script("getComputedStyle(document.querySelector('#modal-content')).overflowY")
    assert_not_equal 'none', page.evaluate_script("getComputedStyle(document.querySelector('#modal-content')).scale")
    assert_operator layer['bottom'], :>, dialog['bottom'], 'the demo layer should extend past the dialog, or clipping is unobservable'

    # The point at the layer's centre lies outside the dialog's box. Hit-testing there reaches
    # the layer only if it is painted above the dialog and its ::backdrop and nothing clips it.
    center_x = layer['left'] + (layer['width'] / 2)
    center_y = layer['bottom'] - 4
    assert_operator center_y, :>, dialog['bottom']
    assert page.evaluate_script(
      "document.querySelector('#inner-layer-content').contains(document.elementFromPoint(arguments[0], arguments[1]))",
      center_x, center_y
    ), 'the nested layer is hidden behind, or clipped by, the modal'

    # Placed by the top layer, not by a number.
    assert page.evaluate_script("document.querySelector('#inner-layer-content').matches(':popover-open')")
    assert_equal 'auto', page.evaluate_script("getComputedStyle(document.querySelector('#inner-layer-content')).zIndex")
  end

  test 'the first Escape closes only the nested layer, the second closes the modal' do
    visit primitives_overlay_path
    open_modal_with_inner_layer

    press :escape
    assert_state '#inner-layer-content', 'closed'
    assert page.evaluate_script("document.querySelector('#modal-content').matches(':modal')"), 'the modal closed with the layer'
    assert_equal 'open', state_of('#modal-content')
    assert_equal 'inner-layer-trigger', focused_id

    press :escape
    assert_state '#modal-content', 'closed'
    assert_not page.evaluate_script("document.querySelector('#modal-content').open")
    assert_equal 'modal-trigger', focused_id
  end

  test 'a second modal opened inside the first takes the first Escape, and the first modal the next' do
    visit primitives_overlay_path
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    find('#nested-modal-trigger').click
    assert_state '#nested-modal-content', 'open'

    press :escape
    assert_state '#nested-modal-content', 'closed'
    assert_equal 'open', state_of('#modal-content')
    assert_equal 'nested-modal-trigger', focused_id

    press :escape
    assert_state '#modal-content', 'closed'
  end

  test 'a layer nested inside another layer closes first on Escape, and both come back together on an outside click' do
    visit primitives_overlay_path
    inject_nested_layer
    find('#menu-trigger').click
    assert_state '#menu-content', 'open'
    find('#submenu-trigger').click
    assert_state '#submenu-content', 'open'

    press :escape
    assert_state '#submenu-content', 'closed'
    assert_equal 'open', state_of('#menu-content')
    assert page.evaluate_script("document.querySelector('#menu-content').matches(':popover-open')")

    # Both are dismissed by one click outside. They are put back outermost-first to animate out,
    # so neither re-show closes the other and neither is left stranded open.
    find('#submenu-trigger').click
    assert_state '#submenu-content', 'open'
    page.driver.browser.action.move_to_location(1340, 1240).click.perform

    assert_state '#submenu-content', 'closed'
    assert_state '#menu-content', 'closed'
    sleep 0.3
    assert_not page.evaluate_script("document.querySelector('#menu-content').matches(':popover-open')")
    assert_not page.evaluate_script("document.querySelector('#submenu-content').matches(':popover-open')")
  end

  test 'a hint appearing does not dismiss the open layer, and Escape on it closes only the hint' do
    visit primitives_overlay_path
    find('#menu-trigger').click
    assert_state '#menu-content', 'open'

    # A hint appears on hover or focus, never by clicking outside the menu.
    page.execute_script("document.querySelector('#hint-overlay').setAttribute('data-ui--overlay-open-value', 'true')")
    assert_state '#hint-content', 'open'
    assert page.evaluate_script("document.querySelector('#menu-content').matches(':popover-open')"), 'the hint closed the layer'
    assert_equal 'open', state_of('#menu-content')

    press :escape
    assert_state '#hint-content', 'closed'
    assert_equal 'open', state_of('#menu-content')

    press :escape
    assert_state '#menu-content', 'closed'
  end

  test 'a hint inside a modal takes the first Escape, and the modal is left open' do
    visit primitives_overlay_path
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    inject_hint_in_modal
    page.execute_script("document.querySelector('#modal-hint-overlay').setAttribute('data-ui--overlay-open-value', 'true')")
    assert_state '#modal-hint-content', 'open'

    # A tooltip is popover="manual", so it has no top-layer Escape ordering to inherit and
    # consumes the key itself. Nothing else may act on that same key -- least of all the dialog
    # it is inside (WCAG 1.4.13).
    press :escape
    assert_state '#modal-hint-content', 'closed'
    assert_equal 'open', state_of('#modal-content')
    assert page.evaluate_script("document.querySelector('#modal-content').matches(':modal')")

    press :escape
    assert_state '#modal-content', 'closed'
  end

  private

  # A submenu: a second layer whose own markup lives inside the first one's content.
  def inject_nested_layer
    page.execute_script(<<~JS)
      const wrapper = document.createElement('div')
      wrapper.id = 'submenu-overlay'
      wrapper.setAttribute('data-controller', 'ui--overlay')
      wrapper.innerHTML = `
        <button id="submenu-trigger" data-ui--overlay-target="trigger" data-action="click->ui--overlay#toggle">More</button>
        <div id="submenu-content" data-ui--overlay-target="content" role="menu" aria-label="Submenu"
             class="m-auto mt-64 bg-white p-2 transition duration-200 data-[state=closed]:opacity-0 data-[state=closing]:opacity-0">
          <button role="menuitem">Move to…</button>
        </div>`
      document.querySelector('#menu-content').appendChild(wrapper)
    JS
    assert_selector '#submenu-trigger', visible: :all
  end

  # A tooltip's markup, inside the dialog, the way a component renders it next to its trigger.
  def inject_hint_in_modal
    page.execute_script(<<~JS)
      const wrapper = document.createElement('div')
      wrapper.id = 'modal-hint-overlay'
      wrapper.setAttribute('data-controller', 'ui--overlay')
      wrapper.setAttribute('data-ui--overlay-mode-value', 'hint')
      wrapper.innerHTML = `
        <button id="modal-hint-trigger" data-ui--overlay-target="trigger">Hinted</button>
        <div id="modal-hint-content" data-ui--overlay-target="content" role="tooltip"
             class="m-auto bg-neutral-900 px-2 py-1 text-xs text-white">Tooltip inside a modal</div>`
      document.querySelector('#modal-content').appendChild(wrapper)
    JS
    assert_selector '#modal-hint-trigger', visible: :all
  end

  def open_modal_with_inner_layer
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    find('#inner-layer-trigger').click
    assert_state '#inner-layer-content', 'open'
  end
end
