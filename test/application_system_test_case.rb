# frozen_string_literal: true

require 'test_helper'
require 'action_dispatch/system_test_case'
require 'selenium-webdriver'
require 'axe/core'
require 'axe/api'

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
  driven_by :rails_ui_kit_headless_chrome, screen_size: [1400, 1400]

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
