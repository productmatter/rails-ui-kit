# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

# The ~12% of browsers without `popover`. Feature detection is
# HTMLElement.prototype.hasOwnProperty("popover"), so deleting that accessor is a faithful
# stand-in: the controller takes the fallback path exactly as it would on a real one.
class UiOverlayFallbackTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  OUTSIDE = [1340, 1240].freeze

  setup { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test 'without popover support a layer still opens, takes focus and gives it back on Escape' do
    visit primitives_overlay_path
    drop_popover_support
    inject_layer

    find('#fallback-trigger').click
    assert_state '#fallback-content', 'open'
    assert_not hidden?('#fallback-content')
    assert_equal 'fallback-content', focused_id
    assert_equal 'true', find('#fallback-trigger')['aria-expanded']
    # No top layer to be placed in: one stacking value, from the stack module, applied once.
    assert_equal '9999', page.evaluate_script("getComputedStyle(document.querySelector('#fallback-content')).zIndex")

    press :escape
    assert_state '#fallback-content', 'closed'
    assert hidden?('#fallback-content')
    assert_equal 'fallback-trigger', focused_id
  end

  test 'without popover support a click outside still dismisses the layer' do
    visit primitives_overlay_path
    drop_popover_support
    inject_layer

    find('#fallback-trigger').click
    assert_state '#fallback-content', 'open'

    page.driver.browser.action.move_to_location(*OUTSIDE).click.perform

    assert_state '#fallback-content', 'closed'
    assert_equal 'false', find('#fallback-trigger')['aria-expanded']
  end

  private

  def drop_popover_support
    page.execute_script('delete HTMLElement.prototype.popover')
    assert_not page.evaluate_script('HTMLElement.prototype.hasOwnProperty("popover")')
  end

  def inject_layer
    page.execute_script(<<~JS)
      const wrapper = document.createElement('div')
      wrapper.id = 'fallback-overlay'
      wrapper.setAttribute('data-controller', 'ui--overlay')
      wrapper.innerHTML = `
        <button id="fallback-trigger" data-ui--overlay-target="trigger" data-action="click->ui--overlay#toggle">Fallback</button>
        <div id="fallback-content" data-ui--overlay-target="content" role="menu" aria-label="Fallback" class="bg-white p-2">
          <button role="menuitem">Only item</button>
        </div>`
      document.querySelector('#menu-overlay').after(wrapper)
    JS
    assert_selector '#fallback-trigger[aria-expanded="false"]'
  end
end
