# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# The top-layer reachability probe (docs/specs/ui-toast, § Acceptance checks, the first
# agent-loopable check). It uses no toast code: only the platform and the kit's real Modal.
#
# Result, 2026-09-14, headless Chrome 152: **the probe fails.** A popover="manual" element shown
# after a modal <dialog> opens is painted above the dialog, but it is still blocked by the modal:
# it isn't hit-tested, a click at its centre lands on the dialog, and focus() is refused. The
# Modal's own code plays no part (TP2 shows the same on a bare <dialog>). Top-layer promotion
# escapes occlusion but not inertness, so § Behavior item 12 takes the fallback: the toast
# container stays in normal flow, and a toast is unreachable while a Modal is open.
#
# These tests pin that finding rather than the hoped-for result. If they start failing, the
# engine has changed how a modal dialog blocks the top layer, and item 12 is worth revisiting.
class ToastTopLayerProbeTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  test 'TP1: a popover shown over an open kit Modal is not hit-testable, clickable or focusable' do
    open_modal(1)
    insert_probe
    assert_probe_blocked
  end

  test "TP2: a bare <dialog> blocks it the same way, so it is the platform's modal, not the kit Modal's code" do
    page.execute_script(<<~JS)
      const dialog = document.createElement('dialog')
      dialog.id = 'bare-dialog'
      dialog.innerHTML = '<p style="padding: 4rem">Bare dialog</p><button type="button">Inside</button>'
      document.body.appendChild(dialog)
      dialog.showModal()
    JS
    assert_selector '#bare-dialog', text: 'Bare dialog'

    insert_probe
    assert_probe_blocked
  end

  # Proves the measurement can pass: with no modal open, the same probe is hit, clicked and focused.
  test 'TP3: control -- with no modal open, the same probe is hit-testable, clickable and focusable' do
    insert_probe

    assert hit?('#probe-button'), 'the probe is not hit-testable even without a modal: the measurement is broken'
    find('#probe-button').click
    assert_equal 1, page.evaluate_script('window.__probeClicks')
    focus('#probe-button')
    assert focused?(find('#probe-button')), 'the probe did not take focus even without a modal'
  end

  private

  def assert_probe_blocked
    assert page.evaluate_script("document.getElementById('probe').matches(':popover-open')"), 'the probe did not open'
    assert_not page.evaluate_script("!!document.getElementById('probe').closest('[inert]')"),
               'the probe carries an inert attribute: the block would be the page, not the modal'

    %w[#probe-button #probe-link].each { |selector| assert_unreachable(selector) }
    assert_raises(Selenium::WebDriver::Error::ElementClickInterceptedError) { find('#probe-button').click }
    assert_equal 0, page.evaluate_script('window.__probeClicks')
  end

  def assert_unreachable(selector)
    assert_not hit?(selector), "#{selector} is hit-testable over the open modal"
    focus(selector)
    assert_not focused?(find(selector)), "#{selector} took focus over the open modal"
  end

  # A popover="manual" element centred on the viewport, which is over the dialog in both tests, so
  # a hit would mean it is reachable above the dialog itself and not merely above the backdrop.
  def insert_probe
    page.execute_script(<<~JS)
      window.__probeClicks = 0
      const probe = document.createElement('div')
      probe.id = 'probe'
      probe.popover = 'manual'
      probe.style.cssText = 'position: fixed; inset: auto; margin: 0; padding: 8px; top: 50%; left: 50%; transform: translate(-50%, -50%)'
      probe.innerHTML = '<button id="probe-button" type="button">Undo</button> <a id="probe-link" href="#probe">View</a>'
      probe.querySelector('button').addEventListener('click', () => { window.__probeClicks += 1 })
      document.body.appendChild(probe)
      probe.showPopover()
    JS
  end

  def focus(selector)
    page.execute_script('document.querySelector(arguments[0]).focus()', selector)
  end

  # The reference is laid out before its centre is hit-tested: a zero-size box has no centre, and
  # "not hit" would then prove nothing.
  def hit?(selector)
    page.evaluate_script(<<~JS, selector)
      (() => {
        const element = document.querySelector(arguments[0])
        const rect = element.getBoundingClientRect()
        if (rect.width === 0 || rect.height === 0) throw new Error(`${arguments[0]} is not laid out`)
        return document.elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2) === element
      })()
    JS
  end
end
