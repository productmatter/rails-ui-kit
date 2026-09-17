# frozen_string_literal: true

require 'test_helper'
require 'action_dispatch/system_test_case'
require 'selenium-webdriver'
require 'axe/core'
require 'axe/api'
require 'kit_invariants'
require_relative 'support/browser_helpers'

Capybara.register_driver :rails_ui_kit_headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Base class for browser tests under test/system/. Never require this file, or
# anything it requires, from test/test_helper.rb -- that would pull Capybara and
# Selenium into the unit lane. See docs/specs/ui-test-harness/spec.md.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  SCREEN_SIZE = [1400, 1400].freeze

  driven_by :rails_ui_kit_headless_chrome, screen_size: SCREEN_SIZE

  # One forked worker per core, each with its own Puma and Chrome; PARALLEL_WORKERS=n caps it.
  parallelize(workers: :number_of_processors)

  # driven_by applies screen_size only to a driver Rails registers itself, and this one is
  # registered above, so the window came up at Chrome's default (about 756x413). Every test starts
  # with a viewport of the registered size instead -- including after a test that resized the
  # shared window.
  setup { resize_viewport_to(*SCREEN_SIZE) }

  # Sizes the viewport, not the window: the window's own frame is measured and added, so
  # innerWidth and innerHeight are what was asked for. A driver with no window -- rack_test, which
  # the no-JavaScript checks run under -- is left alone rather than raised at, the way the CDP
  # switch above leaves it alone.
  def resize_viewport_to(width, height)
    window = browser_window
    return unless window

    window.resize_to(width, height)
    # An object, not an array: a driver that hands an array back as a Hash would make the
    # arithmetic below fail in setup, which is where every test would then die.
    frame = page.evaluate_script('({ width: outerWidth - innerWidth, height: outerHeight - innerHeight })')
    extra_width = frame['width'].to_i
    extra_height = frame['height'].to_i
    window.resize_to(width + extra_width, height + extra_height) unless extra_width.zero? && extra_height.zero?
  end

  # The real browser window, or nil where the driver has none.
  def browser_window
    browser = page.driver.respond_to?(:browser) ? page.driver.browser : nil
    browser.manage.window if browser.respond_to?(:manage)
  end

  # assert_kit_invariants, capture_console and record_arrival (docs/specs/ui-stress-page).
  include KitInvariants

  # press, focused?, click_at, state_of/rect_of and friends -- shared browser probes every
  # test/system/*_test.rb file used to copy for itself (test/support/browser_helpers.rb).
  include BrowserHelpers

  # The slow lane, on demand:
  #
  #   SLOW=1 bundle exec rake test:system TEST=test/system/select_form_submission_test.rb
  #   SLOW=1 SLOW_LATENCY=800 bundle exec rake test:system
  #
  # A test that reads a value before the response that changes it passes on a fast machine and
  # fails on a slow one, and a green run never says which kind of test it is. SLOW=1 emulates
  # network latency through the driver's CDP session, so that read loses the race every time --
  # it is what reproduced the race in select_form_submission_test.rb that CPU throttling could
  # not. Off unless asked for, never set by CI, and never read by a test to decide what to
  # assert (docs/specs/ui-test-harness, § Business rules, rule 7).
  #
  # Reach for it on a file you have just written when that file submits a form, swaps a frame,
  # renders a stream or navigates: those four shapes are where an element outlives the response
  # that changes it, and they produced the only race this suite has had.
  SLOW_LATENCY_MS = 400

  setup { emulate_slow_network if slow_lane? }

  def slow_lane?
    ENV['SLOW'].present? && ENV['SLOW'] != '0'
  end

  def slow_latency_ms
    (ENV['SLOW_LATENCY'].presence || SLOW_LATENCY_MS).to_i
  end

  def emulate_slow_network(driver: page.driver)
    browser = cdp_browser(driver)
    return unless browser

    browser.execute_cdp('Network.enable')
    browser.execute_cdp('Network.emulateNetworkConditions', offline: false, latency: slow_latency_ms,
                                                            downloadThroughput: -1, uploadThroughput: -1)
  end

  # The driver's CDP session, or nil where there is none -- rack_test, which the no-JavaScript
  # checks run under. Such a lane is left at full speed rather than raised at: a switch that
  # breaks a lane it cannot slow is worse than one that quietly does nothing there.
  def cdp_browser(driver = page.driver)
    browser = driver.respond_to?(:browser) ? driver.browser : nil

    browser if browser.respond_to?(:execute_cdp)
  end

  # Runs a real axe-core audit against the current Capybara page and fails with
  # axe's own violation report -- not a bare boolean -- when it finds violations.
  # `within` narrows the audit to a CSS selector, mirroring axe's own `context`.
  def assert_accessible(within: nil)
    run = Axe::API::Run.new
    run = run.within(within) if within

    audit = Axe::Core.new(page).call(run)
    assert audit.passed?, audit.failure_message
  end

  # --- Colour and focus probes (docs/specs/ui-presentational-components, rule 5) ---
  #
  #   disable_transitions
  #   each_token_surface(preview) do |mode, surface|
  #     ratio = contrast_ratio(color_of(:text, badge), color_of(:background, badge))
  #     assert_operator ratio, :>=, 4.5, "label is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
  #   end
  #   assert_focus_outline_in_forced_colors(find('[data-slot=input]'))
  #
  # A control's boundary is color_of(:border, control), measured against both
  # color_of(:background, control) (its own fill) and the background of its parent.

  TOKEN_SURFACES = %w[--background --card --popover --muted].freeze

  # Resolves a colour the way the browser paints it: every background from <html>
  # down to the element composited onto a canvas, then the colour on top, read back
  # as sRGB. Handles oklch() and translucent colours without parsing either. A border
  # composites over the element's own background (background-clip: border-box); an
  # outline over its parent's, since the offset gap shows the parent.
  COLOR_PROBE = <<~JS
    ((kind, element) => {
      const paint = (layers) => {
        const canvas = document.createElement('canvas')
        canvas.width = canvas.height = 1
        const context = canvas.getContext('2d', { willReadFrequently: true })
        context.fillStyle = '#ffffff'
        context.fillRect(0, 0, 1, 1)
        layers.forEach((color) => { context.fillStyle = color; context.fillRect(0, 0, 1, 1) })
        return Array.from(context.getImageData(0, 0, 1, 1).data).slice(0, 3)
      }
      const backgrounds = (node) => {
        const chain = []
        for (; node; node = node.parentElement) chain.unshift(getComputedStyle(node).backgroundColor)
        return chain
      }
      const style = getComputedStyle(element)
      switch (kind) {
        case 'background': return paint(backgrounds(element))
        case 'text': return paint([...backgrounds(element), style.color])
        case 'border': return paint([...backgrounds(element), style.borderTopColor])
        case 'outline': return paint([...backgrounds(element.parentElement), style.outlineColor])
      }
      throw new Error(`unknown colour kind: ${kind}`)
    })(arguments[0], arguments[1])
  JS

  # The painted sRGB colour, [r, g, b], of an element's :text, :background, :border or :outline.
  def color_of(kind, element)
    page.evaluate_script(COLOR_PROBE, kind.to_s, element)
  end

  # The WCAG contrast ratio between two [r, g, b] colours, in either order.
  def contrast_ratio(first, second)
    lighter, darker = [relative_luminance(first), relative_luminance(second)].sort.reverse
    (lighter + 0.05) / (darker + 0.05)
  end

  # Yields [mode, surface] once per token surface in light and then dark mode, with
  # `container`'s background set to that surface.
  def each_token_surface(container)
    { 'light' => false, 'dark' => true }.each do |mode, dark|
      use_dark_mode(dark)
      TOKEN_SURFACES.each do |surface|
        page.execute_script("arguments[0].style.backgroundColor = 'var(#{surface})'", container)
        yield mode, surface
      end
    end
  end

  def use_dark_mode(enabled)
    page.execute_script("document.documentElement.classList.toggle('dark', #{enabled})")
  end

  # Components animate colour changes; measurements must see settled colours, not a
  # frame of the transition that toggling dark mode or focusing starts. Call after visit.
  def disable_transitions
    page.execute_script(<<~JS)
      const style = document.createElement('style')
      style.textContent = '*, *::before, *::after { transition: none !important }'
      document.head.appendChild(style)
    JS
  end

  # A key press puts Chrome in keyboard modality, so the focus that follows is :focus-visible.
  def focus_visibly(element)
    element.send_keys(:shift)
    page.execute_script('arguments[0].focus()', element)
    assert page.evaluate_script('arguments[0].matches(":focus-visible")', element), 'element is not :focus-visible'
  end

  # The computed outline: { 'style' => 'solid', 'width' => '2px', 'color' => 'oklch(…)' }.
  def outline_of(element)
    page.evaluate_script(<<~JS, element)
      (() => { const style = getComputedStyle(arguments[0]); return { style: style.outlineStyle, width: style.outlineWidth, color: style.outlineColor } })()
    JS
  end

  # Forced-colors mode (Windows High Contrast) drops box-shadows, so a focus ring drawn
  # with one vanishes there. Asserts `element` has no outline until focused, then a
  # visible outline at least 2px wide, with forced colours emulated.
  def assert_focus_outline_in_forced_colors(element, name = element.text)
    emulate_forced_colors(true)
    assert_equal 'none', outline_of(element)['style'], "#{name} has an outline before it is focused"

    focus_visibly(element)
    outline = outline_of(element)
    assert_not_equal 'none', outline['style'], "#{name} loses its focus indicator in forced colours"
    assert_operator outline['width'].to_f, :>=, 2, "#{name} focus outline is too thin"
    assert_not_equal 'rgba(0, 0, 0, 0)', outline['color'], "#{name} focus outline is transparent"
  ensure
    emulate_forced_colors(false)
  end

  private

  def emulate_forced_colors(active)
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [{ name: 'forced-colors', value: active ? 'active' : 'none' }])
    assert_equal active, page.evaluate_script("matchMedia('(forced-colors: active)').matches"), 'forced colours emulation did not apply'
  end

  def relative_luminance(rgb)
    red, green, blue = rgb.map do |channel|
      value = channel / 255.0
      value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
    end
    (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
  end
end
