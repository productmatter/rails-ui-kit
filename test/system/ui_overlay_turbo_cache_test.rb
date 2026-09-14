# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

class UiOverlayTurboCacheTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  setup { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test 'Back to a page whose modal was open restores it closed, unlocked, with focus left alone' do
    visit primitives_overlay_path
    collect_errors
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    assert scroll_locked?

    # The open dialog's backdrop blocks every click, so drive the visit the way a real
    # navigation would arrive.
    page.execute_script('Turbo.visit(arguments[0])', installation_path)
    assert_selector 'h1', text: 'Installation'

    page.go_back
    assert_selector 'h1', text: 'Overlay & Presence'

    assert_equal 'closed', state_of('#modal-content')
    assert page.evaluate_script("document.querySelector('#modal-content').hasAttribute('hidden')")
    assert_not page.evaluate_script("document.querySelector('#modal-content').open")
    assert_not scroll_locked?
    assert_not page.evaluate_script("document.querySelector('#modal-content').contains(document.activeElement)")
    assert_equal 'false', find('#modal-trigger')['aria-expanded']

    # And it still opens a real modal afterwards -- no stale `open` attribute, no exception.
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    assert page.evaluate_script("document.querySelector('#modal-content').matches(':modal')")
    assert_empty errors
  end

  test 'a presence element caught mid-transition is cached closed, not mid-transition' do
    visit primitives_overlay_path
    find('#fade-open').click
    assert_state '#fade-panel', 'open'

    page.execute_script(<<~JS, installation_path)
      document.querySelector('#fade-panel').setAttribute('data-ui--presence-open-value', 'false')
      Turbo.visit(arguments[0])
    JS
    assert_selector 'h1', text: 'Installation'

    page.go_back
    assert_selector 'h1', text: 'Overlay & Presence'
    assert_equal 'closed', state_of('#fade-panel')
    assert hidden?('#fade-panel')
    assert_equal 'false', page.evaluate_script("document.querySelector('#fade-panel').getAttribute('data-ui--presence-open-value')")
  end

  test 'turbo:before-cache returns an open overlay and a closing presence element to their resting state at once' do
    visit primitives_overlay_path
    find('#fade-open').click
    assert_state '#fade-panel', 'open'
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    page.execute_script("document.querySelector('#fade-panel').setAttribute('data-ui--presence-open-value', 'false')")
    assert_equal 'closing', state_of('#fade-panel')

    page.execute_script("document.dispatchEvent(new CustomEvent('turbo:before-cache'))")

    # At once: no exit animation to wait out, and no pending timer that could fire later.
    assert_equal 'closed', state_of('#modal-content')
    assert_equal 'closed', state_of('#fade-panel')
    assert_not page.evaluate_script("document.querySelector('#modal-content').open")
    assert_not scroll_locked?
    assert_equal 'false', page.evaluate_script("document.querySelector('#modal-overlay').getAttribute('data-ui--overlay-open-value')")

    sleep 0.6
    assert_equal 'closed', state_of('#modal-content')
    assert_equal 'closed', state_of('#fade-panel')
  end

  test 'a layer caught between a light dismiss and its recovery is reset, not put back' do
    visit primitives_overlay_path
    find('#menu-trigger').click
    assert_state '#menu-content', 'open'

    # The browser hides the popover, and turbo:before-cache lands in the same task -- before the
    # frame in which the overlay would have put it back to animate it out.
    page.execute_script(<<~JS)
      document.querySelector('#menu-content').hidePopover()
      document.dispatchEvent(new CustomEvent('turbo:before-cache'))
    JS

    sleep 0.3
    assert_equal 'closed', state_of('#menu-content')
    assert_not page.evaluate_script("document.querySelector('#menu-content').matches(':popover-open')")
    assert_equal 'false', find('#menu-trigger')['aria-expanded']
  end

  test 'showModal() is never called on a dialog restored with a stale open attribute' do
    visit primitives_overlay_path
    collect_errors
    page.execute_script("document.querySelector('#modal-content').setAttribute('open', '')")

    find('#modal-trigger').click

    assert_state '#modal-content', 'open'
    assert page.evaluate_script("document.querySelector('#modal-content').matches(':modal')")
    assert_empty errors
  end

  test 'an overlay rendered open by the server opens after connecting, from the closed resting state' do
    visit primitives_overlay_path
    record_states

    page.execute_script(<<~JS)
      const wrapper = document.createElement('div')
      wrapper.setAttribute('data-controller', 'ui--overlay')
      wrapper.setAttribute('data-ui--overlay-mode-value', 'modal')
      wrapper.setAttribute('data-ui--overlay-open-value', 'true')
      wrapper.innerHTML = '<dialog id="rendered-open" data-ui--overlay-target="content" class="m-auto p-4"><p>Delivered open</p></dialog>'
      document.body.appendChild(wrapper)
    JS

    assert_state '#rendered-open', 'open'
    assert page.evaluate_script("document.querySelector('#rendered-open').matches(':modal')")
    assert_equal 'rendered-open', focused_id
  end

  test 'a presence element rendered open by the server opens after connecting' do
    visit primitives_overlay_path
    page.execute_script(<<~JS)
      const panel = document.createElement('div')
      panel.id = 'rendered-panel'
      panel.setAttribute('data-controller', 'ui--presence')
      panel.setAttribute('data-ui--presence-open-value', 'true')
      panel.setAttribute('hidden', '')
      panel.textContent = 'Delivered open'
      document.body.appendChild(panel)
    JS

    assert_state '#rendered-panel', 'open'
    assert_not hidden?('#rendered-panel')
  end

  private

  def collect_errors
    page.execute_script(<<~JS)
      window.__errors = []
      window.addEventListener('error', (event) => window.__errors.push(String(event.message)))
      window.addEventListener('unhandledrejection', (event) => window.__errors.push(String(event.reason)))
    JS
  end

  def errors
    page.evaluate_script('window.__errors')
  end

  def record_states
    page.execute_script('window.__states = []')
  end
end
