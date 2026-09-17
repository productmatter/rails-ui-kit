# frozen_string_literal: true

require 'application_system_test_case'

# The SLOW=1 switch itself (docs/specs/ui-test-harness, § Behavior). It is the tool that makes a
# race reproducible on a fast machine, so it has to be provably on when asked for and provably
# absent when not -- a switch that silently does nothing would be worse than no switch, because
# a lane run under it would report false confidence.
class SlowLaneTest < ApplicationSystemTestCase
  setup do
    visit installation_path # warms the app, so the first-request cost is never what is measured
  end

  test 'SL1: the switch slows requests when it is set, and leaves them alone when it is not' do
    measured = fetch_duration(installation_path)

    if slow_lane?
      assert_operator measured, :>=, slow_latency_ms * 0.8,
                      "SLOW=1 asked for #{slow_latency_ms}ms of latency; the request took #{measured.round}ms"
    else
      # Measured against the latency the switch would add, not a guess at how fast an unslowed
      # request should be: that guess failed at 268ms on a machine busy with other test runs,
      # while an applied latency can never come in under the latency itself.
      assert_operator measured, :<, SLOW_LATENCY_MS,
                      "the lane is slow (#{measured.round}ms) without SLOW being set"
    end
  end

  test 'SL2: the switch is inert for a driver with no CDP session, rather than an error' do
    without_cdp = Struct.new(:browser).new(Object.new)

    assert_nil cdp_browser(without_cdp), 'a driver with no CDP session was treated as if it had one'
    assert_nothing_raised { emulate_slow_network(driver: without_cdp) }
    assert cdp_browser, 'the browser lane own driver has no CDP session'
  end

  test 'SL3: SLOW_LATENCY overrides the default delay' do
    assert_equal ApplicationSystemTestCase::SLOW_LATENCY_MS, slow_latency_ms unless ENV['SLOW_LATENCY']

    with_env('SLOW_LATENCY', '1234') { assert_equal 1234, slow_latency_ms }
    with_env('SLOW', nil) { assert_not slow_lane? }
    with_env('SLOW', '0') { assert_not slow_lane?, 'SLOW=0 turned the slow lane on' }
    with_env('SLOW', '1') { assert slow_lane? }
  end

  private

  # One request, measured in the page, so the number is the request's cost rather than a whole
  # navigation's assets.
  def fetch_duration(path)
    page.driver.browser.execute_async_script(<<~JS, path)
      const path = arguments[0]
      const done = arguments[arguments.length - 1]
      const started = performance.now()
      fetch(path, { cache: 'no-store' }).then(() => done(performance.now() - started))
    JS
  end

  def with_env(name, value)
    previous = ENV.fetch(name, nil)
    ENV[name] = value
    yield
  ensure
    ENV[name] = previous
  end
end
