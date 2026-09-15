# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

class UiOverlayRemovalTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  test "removing an open overlay's content releases the scroll lock and gives focus back" do
    visit primitives_overlay_path
    find('#removable-trigger').click
    assert_state '#removable-content', 'open'
    assert scroll_locked?

    find('#remove-overlay').click

    assert_no_selector '#removable-content'
    assert_not scroll_locked?
    assert_equal '', body_style('overflow')
    assert_equal 'removable-trigger', focused_id
    # Nothing left behind that would swallow a click on the page.
    find('#fade-open').click
    assert_state '#fade-panel', 'open'
  end

  test 'removing the whole overlay element while it is open leaves the page usable' do
    visit primitives_overlay_path
    find('#removable-trigger').click
    assert_state '#removable-content', 'open'
    assert scroll_locked?

    page.execute_script("document.querySelector('#removable-overlay').remove()")

    assert_no_selector '#removable-overlay'
    assert_not scroll_locked?
    assert_not page.evaluate_script("!!document.querySelector('dialog[open]')")
    find('#fade-open').click
    assert_state '#fade-panel', 'open'
  end

  test 'another open overlay keeps the page locked when one is removed' do
    visit primitives_overlay_path
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    assert scroll_locked?

    # A second lock-requesting overlay, opened while the first is up, then taken out of the page
    # without ever being closed.
    page.execute_script("document.querySelector('#removable-overlay').setAttribute('data-ui--overlay-open-value', 'true')")
    assert_state '#removable-content', 'open'
    page.execute_script("document.querySelector('#removable-overlay').remove()")
    assert_no_selector '#removable-overlay'

    assert scroll_locked?, 'the removed overlay released a lock the open one still holds'

    find('#modal-close').click
    assert_state '#modal-content', 'closed'
    assert_not scroll_locked?
  end

  test 'a presence element removed mid-transition leaves no timer behind to touch it later' do
    visit primitives_overlay_path
    find('#fade-open').click
    assert_state '#fade-panel', 'open'

    page.execute_script(<<~JS)
      const panel = document.querySelector('#fade-panel')
      panel.setAttribute('data-ui--presence-open-value', 'false')
      window.__detached = panel
      panel.remove()
    JS

    sleep 0.8
    assert_no_selector '#fade-panel'
    assert_equal 'closed', page.evaluate_script('window.__detached.dataset.state')
    assert page.evaluate_script('window.__detached.hasAttribute("hidden")')
  end
end
