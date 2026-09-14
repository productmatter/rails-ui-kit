# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

class UiOverlayFocusTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  OUTSIDE = [1340, 1240].freeze

  setup { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test 'modal: focus enters the overlay on open and returns to the trigger on Escape' do
    visit primitives_overlay_path
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    assert_equal 'modal-content', focused_id

    press :escape
    assert_state '#modal-content', 'closed'
    assert_equal 'modal-trigger', focused_id
  end

  test 'modal: focus returns to the trigger after a backdrop dismissal and after a programmatic close' do
    visit primitives_overlay_path
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    click_at(*OUTSIDE)
    assert_state '#modal-content', 'closed'
    assert_equal 'modal-trigger', focused_id

    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    find('#modal-close').click
    assert_state '#modal-content', 'closed'
    assert_equal 'modal-trigger', focused_id
  end

  test 'layer: focus enters on open and returns to the trigger on Escape, outside click and programmatic close' do
    visit primitives_overlay_path

    find('#menu-trigger').click
    assert_state '#menu-content', 'open'
    assert_equal 'menu-content', focused_id
    press :escape
    assert_state '#menu-content', 'closed'
    assert_equal 'menu-trigger', focused_id

    find('#menu-trigger').click
    assert_state '#menu-content', 'open'
    click_at(*OUTSIDE)
    assert_state '#menu-content', 'closed'
    assert_equal 'menu-trigger', focused_id

    find('#menu-trigger').click
    assert_state '#menu-content', 'open'
    page.execute_script("document.querySelector('#menu-overlay').setAttribute('data-ui--overlay-open-value', 'false')")
    assert_state '#menu-content', 'closed'
    assert_equal 'menu-trigger', focused_id
  end

  test 'a dismissal that deliberately moved focus somewhere else keeps it there' do
    visit primitives_overlay_path
    find('#menu-trigger').click
    assert_state '#menu-content', 'open'

    find('#fade-open').click
    assert_state '#menu-content', 'closed'
    assert_equal 'fade-open', focused_id, 'the overlay stole focus back from the element the user clicked'
  end

  test 'an overlay with no focusable children still takes focus and still gives it back' do
    visit primitives_overlay_path
    inject_overlay('empty', %(<p id="empty-text">Nothing focusable in here.</p>))

    find('#empty-trigger').click
    assert_state '#empty-content', 'open'
    assert_equal 'empty-content', focused_id
    assert_equal '-1', page.evaluate_script("document.querySelector('#empty-content').getAttribute('tabindex')")

    press :escape
    assert_state '#empty-content', 'closed'
    assert_equal 'empty-trigger', focused_id
  end

  test 'initialFocus names what takes focus on open, and the trigger still gets it back' do
    visit primitives_overlay_path
    inject_overlay('search', %(<input id="search-field" type="text">), values: { 'initial-focus' => 'input' })

    find('#search-trigger').click
    assert_state '#search-content', 'open'
    assert_equal 'search-field', focused_id

    press :escape
    assert_state '#search-content', 'closed'
    assert_equal 'search-trigger', focused_id
  end

  test 'the trigger is operable from the keyboard alone, and reports its state' do
    visit primitives_overlay_path
    trigger = find('#menu-trigger')
    assert_equal 'menu-content', trigger['aria-controls']
    assert_equal 'false', trigger['aria-expanded']

    page.execute_script('arguments[0].focus()', trigger)
    press :enter
    assert_state '#menu-content', 'open'
    assert_equal 'true', trigger['aria-expanded']
    assert_equal 'menu-content', focused_id

    press :escape
    assert_state '#menu-content', 'closed'
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)
  end

  private

  def click_at(point_x, point_y)
    page.driver.browser.action.move_to_location(point_x.to_i, point_y.to_i).click.perform
  end

  # Builds the markup a component would render, so these cases don't need a demo of their own.
  def inject_overlay(name, inner_html, values: {})
    attributes = values.map { |key, value| %(wrapper.setAttribute('data-ui--overlay-#{key}-value', '#{value}')) }.join("\n")
    page.execute_script(<<~JS)
      const wrapper = document.createElement('div')
      wrapper.id = '#{name}-overlay'
      wrapper.setAttribute('data-controller', 'ui--overlay')
      #{attributes}
      wrapper.innerHTML = `
        <button id="#{name}-trigger" data-ui--overlay-target="trigger" data-action="click->ui--overlay#toggle">#{name}</button>
        <div id="#{name}-content" data-ui--overlay-target="content" class="m-auto bg-white p-4">#{inner_html}</div>`
      document.querySelector('#menu-overlay').after(wrapper)
    JS
    assert_selector "##{name}-trigger[aria-expanded='false']"
  end
end
