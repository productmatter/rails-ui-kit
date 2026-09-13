# frozen_string_literal: true

require 'application_system_test_case'

class ButtonTest < ApplicationSystemTestCase
  VARIANTS = %w[default secondary outline ghost link destructive].freeze
  SURFACES = %w[--background --card --popover --muted].freeze

  # Resolves colours the way the browser paints them: every background from <html>
  # down to the element composited onto a canvas, then the colour on top, read back
  # as sRGB. Handles oklch() and translucent colours without parsing either.
  COLOR_PROBE = <<~JS
    window.colorProbe = {
      paint(layers) {
        const canvas = document.createElement('canvas')
        canvas.width = canvas.height = 1
        const context = canvas.getContext('2d', { willReadFrequently: true })
        context.fillStyle = '#ffffff'
        context.fillRect(0, 0, 1, 1)
        layers.forEach((color) => { context.fillStyle = color; context.fillRect(0, 0, 1, 1) })
        return Array.from(context.getImageData(0, 0, 1, 1).data).slice(0, 3)
      },
      backgrounds(element) {
        const chain = []
        for (let node = element; node; node = node.parentElement) chain.unshift(getComputedStyle(node).backgroundColor)
        return chain
      },
      background(element) { return this.paint(this.backgrounds(element)) },
      text(element) { return this.paint([...this.backgrounds(element), getComputedStyle(element).color]) },
      outline(element) { return this.paint([...this.backgrounds(element.parentElement), getComputedStyle(element).outlineColor]) }
    }
  JS

  # Buttons animate colour changes; measurements must see the settled colours, not a
  # frame of the transition that toggling dark mode or focusing starts.
  NO_TRANSITIONS = <<~JS
    const style = document.createElement('style')
    style.textContent = '*, *::before, *::after { transition: none !important }'
    document.head.appendChild(style)
  JS

  setup do
    visit button_path
    page.execute_script(COLOR_PROBE)
    page.execute_script(NO_TRANSITIONS)
  end

  teardown do
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [{ name: 'forced-colors', value: 'none' }])
  end

  # BTN1
  test 'the focus indicator survives forced-colors mode' do
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [{ name: 'forced-colors', value: 'active' }])
    assert page.evaluate_script("matchMedia('(forced-colors: active)').matches"), 'forced colours must be emulated'

    VARIANTS.each do |variant|
      button = preview_button(variant)
      assert_equal 'none', outline_of(button)['style'], "#{variant} has no outline before it is focused"

      focus_visibly(button)
      outline = outline_of(button)
      assert_not_equal 'none', outline['style'], "#{variant} loses its focus indicator in forced colours"
      assert_operator outline['width'].to_f, :>=, 2, "#{variant} focus outline is too thin"
      assert_not_equal 'rgba(0, 0, 0, 0)', outline['color'], "#{variant} focus outline is transparent"
    end
  end

  # BTN2 (the link variant) and the label of every other variant, on every surface, in both modes.
  test 'every variant label reaches 4.5:1 on every token surface in light and dark mode' do
    each_mode_and_surface do |mode, surface|
      VARIANTS.each do |variant|
        button = preview_button(variant)
        ratio = contrast(color_of(:text, button), color_of(:background, button))
        assert_operator ratio, :>=, 4.5, "#{variant} label is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
      end
    end
  end

  # BTN3
  test 'the outline variant label stays readable inside a host element that sets its own text colour' do
    page.execute_script("arguments[0].style.color = 'rgb(255, 255, 255)'", preview)

    button = preview_button('outline')
    ratio = contrast(color_of(:text, button), color_of(:background, button))
    assert_operator ratio, :>=, 4.5, "outline label is #{ratio.round(2)}:1 inside white host text"
  end

  # BTN4, including the destructive variant.
  test 'the focus ring reaches 3:1 against the surface on every token surface in light and dark mode' do
    each_mode_and_surface do |mode, surface|
      VARIANTS.each do |variant|
        button = preview_button(variant)
        focus_visibly(button)
        assert_not_equal 'none', outline_of(button)['style'], "#{variant} draws no focus outline"
        ratio = contrast(color_of(:outline, button), color_of(:background, preview))
        assert_operator ratio, :>=, 3, "#{variant} focus ring is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
      end
    end
  end

  # BTN6
  test 'icon sizing defaults a direct svg, yields to the caller sizing classes, and skips nested svgs' do
    button = preview_button('default')
    page.execute_script(<<~JS, button)
      const button = arguments[0]
      const icon = '<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 5v14"/></svg>'
      button.innerHTML = icon + icon.replace('<svg', '<svg class="h-5 w-5"') + icon.replace('<svg', '<svg class="size-6"') +
        '<span class="inline-flex">' + icon + '</span>'
    JS

    sizes = page.evaluate_script(<<~JS, button)
      Array.from(arguments[0].querySelectorAll('svg')).map((svg) => svg.getBoundingClientRect().width)
    JS

    assert_equal [16, 20, 24, 24], sizes
  end

  test 'the button preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#button-preview')

    use_dark_mode(true)
    assert_accessible(within: '#button-preview')
  end

  private

  def preview
    find_by_id('button-preview')
  end

  def preview_button(variant)
    preview.find('[data-slot=button]', exact_text: variant.capitalize)
  end

  def each_mode_and_surface
    { 'light' => false, 'dark' => true }.each do |mode, dark|
      use_dark_mode(dark)
      SURFACES.each do |surface|
        page.execute_script("arguments[0].style.backgroundColor = 'var(#{surface})'", preview)
        yield mode, surface
      end
    end
  end

  def use_dark_mode(enabled)
    page.execute_script("document.documentElement.classList.toggle('dark', #{enabled})")
  end

  def focus_visibly(element)
    element.send_keys(:shift) # a key press puts Chrome in keyboard modality, so focus is :focus-visible
    page.execute_script('arguments[0].focus()', element)
    assert page.evaluate_script('arguments[0].matches(":focus-visible")', element)
  end

  def outline_of(element)
    page.evaluate_script(<<~JS, element)
      (() => { const style = getComputedStyle(arguments[0]); return { style: style.outlineStyle, width: style.outlineWidth, color: style.outlineColor } })()
    JS
  end

  def color_of(kind, element)
    page.evaluate_script("colorProbe.#{kind}(arguments[0])", element)
  end

  def contrast(first, second)
    lighter, darker = [luminance(first), luminance(second)].sort.reverse
    (lighter + 0.05) / (darker + 0.05)
  end

  def luminance(rgb)
    red, green, blue = rgb.map do |channel|
      value = channel / 255.0
      value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
    end
    (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
  end
end
