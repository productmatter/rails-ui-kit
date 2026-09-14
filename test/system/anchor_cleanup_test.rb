# frozen_string_literal: true

require 'application_system_test_case'
require 'primitives_helpers'

# Nothing a primitive registers outlives its element. The component audit found all three shipped
# positioning implementations leaking their scroll and resize listeners; these are the tests that
# stop ui--anchor from repeating it.
class AnchorCleanupTest < ApplicationSystemTestCase
  include PrimitivesHelpers

  # Counts scroll/resize listeners and observer instances that are live, and creates an anchored
  # element afterwards, so everything it registers is attributable to it.
  PROBE = <<~JS
    window.__probe = { listeners: [], observers: [] }

    const add = EventTarget.prototype.addEventListener
    const remove = EventTarget.prototype.removeEventListener

    EventTarget.prototype.addEventListener = function (type, listener, options) {
      if (type === 'scroll' || type === 'resize') window.__probe.listeners.push({ target: this, type, listener })
      return add.call(this, type, listener, options)
    }

    EventTarget.prototype.removeEventListener = function (type, listener, options) {
      const index = window.__probe.listeners.findIndex(
        (entry) => entry.target === this && entry.type === type && entry.listener === listener
      )
      if (index !== -1) window.__probe.listeners.splice(index, 1)
      return remove.call(this, type, listener, options)
    }

    // Scoped to the probe's own host: autoUpdate only ever calls observe() with the reference or
    // floating element (or, for IntersectionObserver, re-creates a fresh instance and re-observes
    // the reference on every layout-shift refresh -- both cases stay inside this element). Without
    // this check the page-wide count also catches other still-connected anchors elsewhere on the
    // page re-arming their own observers, which have nothing to do with this element's cleanup.
    const track = (Observer) => class extends Observer {
      disconnect() {
        const index = window.__probe.observers.indexOf(this)
        if (index !== -1) window.__probe.observers.splice(index, 1)
        return super.disconnect()
      }

      observe(target, ...rest) {
        if ((target === host || host.contains(target)) && !window.__probe.observers.includes(this)) {
          window.__probe.observers.push(this)
        }
        return super.observe(target, ...rest)
      }
    }

    window.ResizeObserver = track(window.ResizeObserver)
    window.IntersectionObserver = track(window.IntersectionObserver)

    const host = document.createElement('div')
    host.id = 'probe-host'
    host.style.cssText = 'position:relative;margin:40px'
    host.innerHTML = `
      <div data-controller="ui--anchor"
           data-ui--anchor-placement-value="bottom-start"
           data-ui--anchor-active-value="true">
        <button type="button" data-ui--anchor-target="anchor" id="probe-control">Probe</button>
        <div data-ui--anchor-target="floating" id="probe-floating" class="absolute">probe</div>
      </div>`
    document.body.appendChild(host)
  JS

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit primitives_navigation_path
    assert_selector '[data-ui--anchor-target="floating"][data-side]', minimum: 12, wait: 20
  end

  test 'AC1: an active anchor registers scroll, resize and observer work, and disconnecting releases all of it' do
    page.execute_script(PROBE)
    # Appended at the end of the page, so which side it lands on is flip's business, not ours.
    assert_selector '#probe-floating[data-side]', wait: 10

    assert_operator probe_counts['listeners'], :>, 0, 'expected autoUpdate to register scroll/resize listeners'
    assert_operator probe_counts['observers'], :>, 0, 'expected autoUpdate to register a resize/intersection observer'

    page.execute_script("document.querySelector('#probe-host').remove()")

    eventually do
      assert_equal 0, probe_counts['listeners'], 'a scroll or resize listener outlived the anchor element'
      assert_equal 0, probe_counts['observers'], 'an observer outlived the anchor element'
    end
  end

  test 'AC2: a removed anchor computes nothing further on scroll or resize' do
    counted = install_counter('#anchor-block [data-controller="ui--anchor"]')
    churn
    eventually { assert_operator counted.call, :>, 0 }

    page.execute_script("document.querySelector('#anchor-block [data-controller=\"ui--anchor\"]').remove()")
    before = counted.call

    churn
    sleep 0.5

    assert_equal before, counted.call, 'ui--anchor:positioned fired after the element left the document'
  end

  test 'AC3: setting active to false stops the work, and setting it back resumes it' do
    counted = install_counter('#anchor-block [data-controller="ui--anchor"]')
    anchor = find('#anchor-block [data-controller="ui--anchor"]', visible: :all)

    page.execute_script("arguments[0].setAttribute('data-ui--anchor-active-value', 'false')", anchor)
    sleep 0.2
    before = counted.call

    churn
    sleep 0.5
    assert_equal before, counted.call, 'an inactive anchor kept positioning'

    page.execute_script("arguments[0].setAttribute('data-ui--anchor-active-value', 'true')", anchor)
    eventually { assert_operator counted.call, :>, before }
  end

  test 'AC4: a page restored from Turbo\'s cache positions from live controllers, not stale attributes' do
    control = find('#anchor-block-control')
    floating = find('#anchor-block-floating')
    eventually { assert_in_delta rect(control)['right'], rect(floating)['right'], 2 }

    page.execute_script('Turbo.visit(arguments[0])', installation_path)
    assert_selector 'h1', text: 'Installation'

    page.go_back
    assert_selector 'h1', text: 'Positioning'

    # The restored snapshot carries the old inline left/top; what matters is that the controller
    # reconnected and is positioning again, which a resize proves.
    assert_selector '[data-ui--anchor-target="floating"][data-side]', minimum: 12, wait: 20
    page.driver.browser.manage.window.resize_to(1000, 900)

    restored_control = find('#anchor-block-control')
    restored_floating = find('#anchor-block-floating')
    eventually do
      assert_in_delta rect(restored_control)['right'], rect(restored_floating)['right'], 2
      assert_in_delta rect(restored_control)['bottom'] + 6, rect(restored_floating)['top'], 2
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  private

  def probe_counts
    page.evaluate_script('({ listeners: window.__probe.listeners.length, observers: window.__probe.observers.length })')
  end

  # Counts ui--anchor:positioned events on one controller's element. Listening on the element
  # itself, not the document: once the element is detached its events no longer reach document.
  def install_counter(selector)
    page.execute_script(<<~JS, selector)
      window.__positioned = 0
      document.querySelector(arguments[0]).addEventListener('ui--anchor:positioned', () => { window.__positioned++ })
    JS
    -> { page.evaluate_script('window.__positioned') }
  end

  # Scroll and resize: the two things that make a live anchor recompute.
  def churn
    page.execute_script('window.scrollBy(0, 200); window.dispatchEvent(new Event("resize"))')
    page.driver.browser.manage.window.resize_to(1200, 1000)
    page.execute_script('window.scrollBy(0, -200)')
  end
end
