# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

class UiPresenceTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  FADE_PANEL = '#fade-panel'
  INSTANT_PANEL = '#instant-panel'

  test 'an element with an exit animation stays visible and laid out at data-state=closing until it finishes' do
    visit primitives_overlay_path
    record_presence_events(FADE_PANEL)

    find('#fade-open').click
    assert_state FADE_PANEL, 'open'
    assert_not hidden?(FADE_PANEL)

    find('#fade-close').click
    # Mid-exit: still rendered, still taking up space, still not hidden.
    assert_equal 'closing', state_of(FADE_PANEL)
    assert_not hidden?(FADE_PANEL)
    assert_operator page.evaluate_script("document.querySelector('#{FADE_PANEL}').getBoundingClientRect().height"), :>, 0

    assert_state FADE_PANEL, 'closed'
    assert hidden?(FADE_PANEL)
    assert_equal %w[opened closing closed], presence_events
  end

  test 'the wait is the element\'s own animation: 500ms declared, 500ms held' do
    visit primitives_overlay_path
    find('#fade-open').click
    assert_state FADE_PANEL, 'open'

    assert_operator close_duration(FADE_PANEL), :>=, 450, 'closed before its own transition had finished'
  end

  test 'an element with no declared transition closes in the same frame, without waiting out a timeout' do
    visit primitives_overlay_path
    find('#instant-open').click
    assert_state INSTANT_PANEL, 'open'

    assert_operator close_duration(INSTANT_PANEL), :<, 50, 'waited on an animation that was never declared'
    assert hidden?(INSTANT_PANEL)
  end

  test 'under prefers-reduced-motion the wait is skipped, and the setting is read per transition' do
    visit primitives_overlay_path
    find('#fade-open').click
    assert_state FADE_PANEL, 'open'

    emulate_media('prefers-reduced-motion', 'reduce')
    assert_operator close_duration(FADE_PANEL), :<, 50, 'held the element through its exit animation under reduced motion'

    # Read at transition time, not at connect: turning the preference off again restores the wait
    # without the controller reconnecting.
    emulate_media('prefers-reduced-motion', 'no-preference')
    find('#fade-open').click
    assert_state FADE_PANEL, 'open'
    assert_operator close_duration(FADE_PANEL), :>=, 450
  ensure
    emulate_media('prefers-reduced-motion', 'no-preference')
  end

  test 'an interrupted close -> open -> close settles closed, with no orphaned timer' do
    visit primitives_overlay_path
    find('#fade-open').click
    assert_state FADE_PANEL, 'open'

    set_presence(FADE_PANEL, false, true, false)

    assert_state FADE_PANEL, 'closed'
    assert hidden?(FADE_PANEL)
    # Settled: nothing arrives later to undo it.
    sleep 0.6
    assert_equal 'closed', state_of(FADE_PANEL)
  end

  test 'an interrupted open -> close -> open settles open and visible' do
    visit primitives_overlay_path
    set_presence(FADE_PANEL, true, false, true)

    assert_state FADE_PANEL, 'open'
    assert_not hidden?(FADE_PANEL)
    sleep 0.6
    assert_equal 'open', state_of(FADE_PANEL)
    assert_equal 1, page.evaluate_script("getComputedStyle(document.querySelector('#{FADE_PANEL}')).opacity").to_f
  end

  test 'a fast close -> open reverses in place rather than snapping back to the closed state' do
    visit primitives_overlay_path
    find('#fade-open').click
    assert_state FADE_PANEL, 'open'

    # Halfway through the 500ms exit, ask for it back: it must resume from where it is, so the
    # opacity it was painting at never falls back to 0.
    opacity = page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      const panel = document.querySelector('#{FADE_PANEL}')
      panel.setAttribute('data-ui--presence-open-value', 'false')
      setTimeout(() => {
        panel.setAttribute('data-ui--presence-open-value', 'true')
        requestAnimationFrame(() => done(parseFloat(getComputedStyle(panel).opacity)))
      }, 250)
    JS

    assert_operator opacity, :>, 0, 'the reversed entry restarted from the closed state'
    assert_state FADE_PANEL, 'open'
  end

  private

  # Milliseconds between asking the element to close and its own ui--presence:closed event --
  # measured in the page, so no Capybara round trip lands inside the measurement.
  def close_duration(selector)
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      const panel = document.querySelector('#{selector}')
      const started = performance.now()
      panel.addEventListener('ui--presence:closed', () => done(performance.now() - started), { once: true })
      panel.setAttribute('data-ui--presence-open-value', 'false')
    JS
  end

  def set_presence(selector, *values)
    page.execute_script(<<~JS, values.map(&:to_s))
      const panel = document.querySelector('#{selector}')
      arguments[0].forEach((value) => panel.setAttribute('data-ui--presence-open-value', value))
    JS
  end

  def record_presence_events(selector)
    page.execute_script(<<~JS)
      window.__presence = []
      const panel = document.querySelector('#{selector}')
      for (const name of ['opened', 'closing', 'closed']) {
        panel.addEventListener(`ui--presence:${name}`, () => window.__presence.push(name))
      }
    JS
  end

  def presence_events
    page.evaluate_script('window.__presence')
  end
end
