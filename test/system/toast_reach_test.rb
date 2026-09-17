# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'toast_helpers'

# A toast with an action is never taken away by a default, and a keyboard user can reach it
# (docs/specs/ui-toast, § Behavior, items 10 and 12; § Business rules, rules 7 and 9).
#
# Time is advanced with a clock the test controls, not a real sleep: timers of 1.5 s or more --
# every toast duration, and nothing Turbo or Primitive D uses -- are held and run on demand. A
# toast without actions, fired alongside, is the control that proves the clock does dismiss.
class ToastReachTest < ApplicationSystemTestCase
  include ToastHelpers

  CLOCK = <<~JS
    (() => {
      if (window.__advance) return
      const realSetTimeout = window.setTimeout.bind(window)
      const realClearTimeout = window.clearTimeout.bind(window)
      const realNow = Date.now
      let offset = 0
      let held = []
      let sequence = 1e9
      Date.now = () => realNow() + offset
      window.setTimeout = (callback, delay = 0, ...args) => {
        if (delay < 1500) return realSetTimeout(callback, delay, ...args)
        const id = ++sequence
        held.push({ id, at: Date.now() + delay, callback, args })
        return id
      }
      window.clearTimeout = (id) => { held = held.filter((timer) => timer.id !== id); realClearTimeout(id) }
      window.__advance = (ms) => {
        offset += ms
        const due = held.filter((timer) => timer.at <= Date.now())
        held = held.filter((timer) => timer.at > Date.now())
        due.forEach((timer) => timer.callback(...timer.args))
      }
    })()
  JS

  test 'TR1: an action toast outlives every default, F8 reaches it, and its patch Undo arrives with a CSRF header' do
    visit toast_path
    wait_for_toast_api
    page.execute_script(CLOCK)

    trigger_toast(ToastsController.scenario('archived'))
    trigger_toast(type: 'error', description: 'No action: 20 s by default')
    assert_selector TOAST, count: 2

    page.execute_script('window.__advance(25000)')
    assert_no_selector TOAST, text: 'No action', wait: 3
    assert_selector TOAST, text: 'Project archived', count: 1

    focus_on('#toast-js-title')
    press :f8
    assert_equal 'View', page.evaluate_script('document.activeElement.textContent.trim()')

    press :tab
    assert_equal 'Undo', page.evaluate_script('document.activeElement.textContent.trim()')
    press :enter

    assert_selector '[data-slot=toast-description]', text: 'Undone: PATCH with a valid CSRF token.'
    assert_no_selector TOAST, text: 'Project archived'
    assert_equal 'toast-js-title', focused_id, 'closing the toast that held focus did not return it to where F8 came from'
  end

  test 'TR2: Escape closes the focused toast and returns focus to the element focused before F8' do
    visit toast_path
    trigger_toast(ToastsController.scenario('archived'))
    settled_toast

    focus_on('#toast-js-both')
    press :f8
    assert page.evaluate_script("document.activeElement.closest('[data-slot=toast]') !== null"), 'F8 did not move focus into the toast'

    press :escape
    assert_no_selector TOAST
    assert_equal 'toast-js-both', focused_id
  end

  test 'TR3: with no toast, F8 is not intercepted and focus stays put' do
    visit toast_path
    wait_for_toast_api
    focus_on('#toast-js-both')
    page.execute_script("window.__f8 = null; document.addEventListener('keydown', (e) => { if (e.key === 'F8') window.__f8 = e.defaultPrevented })")

    press :f8

    wait_until('window.__f8 !== null')
    assert_equal false, page.evaluate_script('window.__f8')
    assert_equal 'toast-js-both', focused_id
  end

  private

  def focus_on(selector)
    page.execute_script('document.querySelector(arguments[0]).focus()', selector)
    assert_equal selector.delete('#'), focused_id
  end
end
