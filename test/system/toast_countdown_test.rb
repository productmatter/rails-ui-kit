# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'toast_helpers'

# Every countdown pauses for keyboard focus, the pointer and a hidden page, and resumes with the
# time that was left (docs/specs/ui-toast, § Behavior, items 10 and 14; § Business rules, rule 8).
# These measure real time on purpose: the claim is about what a person waiting sees.
class ToastCountdownTest < ApplicationSystemTestCase
  include ToastHelpers

  DURATION = 2000
  # The allowance the spec gives for resuming and starting the exit.
  SLACK = 300

  teardown { page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [{ name: 'prefers-reduced-motion', value: '' }]) }

  test 'TC1: focus given by F8, with no pointer, pauses it; blur resumes it with the time left' do
    toast = timed_toast
    press :f8
    assert page.evaluate_script('arguments[0].contains(document.activeElement)', toast), 'F8 did not focus the toast'

    assert_paused_for_four_seconds(toast)
    page.execute_script("document.getElementById('toast-js-title').focus()")
    assert_closes_within('Counting down', DURATION + SLACK)
  end

  test 'TC2: the pointer over it pauses it, and leaving resumes it' do
    toast = timed_toast
    page.driver.browser.action.move_to(toast.native).perform

    assert_paused_for_four_seconds(toast)
    page.driver.browser.action.move_to_location(5, 5).perform
    assert_closes_within('Counting down', DURATION + SLACK)
  end

  test 'TC3: a hidden page pauses it, and a visible one resumes it' do
    visit toast_path
    wait_for_toast_api
    page.execute_script(<<~JS)
      window.__visibility = 'visible'
      Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => window.__visibility })
    JS
    toast = timed_toast(visit_page: false)

    page.execute_script("window.__visibility = 'hidden'; document.dispatchEvent(new Event('visibilitychange'))")
    assert_paused_for_four_seconds(toast)
    page.execute_script("window.__visibility = 'visible'; document.dispatchEvent(new Event('visibilitychange'))")
    assert_closes_within('Counting down', DURATION + SLACK)
  end

  test 'TC4: with reduced motion the bar has no transition and steps at most once a second, and the toast still closes on time' do
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [{ name: 'prefers-reduced-motion', value: 'reduce' }])
    visit toast_path
    assert page.evaluate_script("matchMedia('(prefers-reduced-motion: reduce)').matches"), 'reduced motion was not emulated'

    wait_for_toast_api
    started = monotonic
    trigger_toast(type: 'info', description: 'Reduced motion', duration: 3000)
    toast = find(TOAST, text: 'Reduced motion')

    assert_equal '0s', page.evaluate_script('getComputedStyle(arguments[0]).transitionDuration', timer(toast))
    scales = sample_scales(toast, 2.5)
    changes = scales.each_cons(2).count { |before, after| before != after }
    assert_operator changes, :<=, 3, "the bar changed #{changes} times in 2.5 s: #{scales.uniq.inspect}"

    assert_no_selector "#{TOAST}[data-state=open]", text: 'Reduced motion', wait: 3
    assert_in_delta 3.0, monotonic - started, 0.5, 'the toast did not close at its duration'
  end

  private

  def timed_toast(visit_page: true)
    visit toast_path if visit_page
    trigger_toast(type: 'info', description: 'Counting down', duration: DURATION)
    find(TOAST, text: 'Counting down')
  end

  def timer(toast)
    toast.find('[data-ui--toast-target=timer]', visible: :all)
  end

  def scale_of(toast)
    page.evaluate_script('getComputedStyle(arguments[0]).scale', timer(toast))
  end

  # Present and frozen across four seconds -- twice the whole duration. Read by text, not by a held
  # element, so a toast that wrongly closed fails here by name instead of as a stale reference.
  def assert_paused_for_four_seconds(_toast, text = 'Counting down')
    sleep 0.2 # lets a transition that was running when the pause began report its frozen value
    before = open_scale(text)
    sleep 4
    assert_selector "#{TOAST}[data-state=open]", text: text, wait: 0
    assert_equal before, open_scale(text), 'the bar moved while paused'
  end

  def open_scale(text)
    toast = first("#{TOAST}[data-state=open]", text: text, minimum: 0, wait: 0)
    flunk 'the toast closed while it should have been paused' unless toast
    scale_of(toast)
  end

  # Closing is the moment it stops being open: under reduced motion it leaves the page in the same
  # frame, so the element itself can't be held on to.
  def assert_closes_within(text, milliseconds)
    started = monotonic
    assert_no_selector "#{TOAST}[data-state=open]", text: text, wait: (milliseconds / 1000.0) + 1
    assert_operator (monotonic - started) * 1000, :<=, milliseconds, 'it did not resume with the time that was left'
  end

  def sample_scales(toast, seconds)
    deadline = monotonic + seconds
    samples = []
    while monotonic < deadline
      samples << scale_of(toast)
      sleep 0.05
    end
    samples
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
