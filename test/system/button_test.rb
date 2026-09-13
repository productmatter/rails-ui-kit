# frozen_string_literal: true

require 'application_system_test_case'

class ButtonTest < ApplicationSystemTestCase
  VARIANTS = %w[default secondary outline ghost link destructive].freeze

  setup do
    visit button_path
    disable_transitions
  end

  # BTN1
  test 'the focus indicator survives forced-colors mode' do
    VARIANTS.each do |variant|
      assert_focus_outline_in_forced_colors(preview_button(variant), variant)
    end
  end

  # BTN2 (the link variant) and the label of every other variant, on every surface, in both modes.
  test 'every variant label reaches 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      VARIANTS.each do |variant|
        button = preview_button(variant)
        ratio = contrast_ratio(color_of(:text, button), color_of(:background, button))
        assert_operator ratio, :>=, 4.5, "#{variant} label is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
      end
    end
  end

  # BTN3
  test 'the outline variant label stays readable inside a host element that sets its own text colour' do
    page.execute_script("arguments[0].style.color = 'rgb(255, 255, 255)'", preview)

    button = preview_button('outline')
    ratio = contrast_ratio(color_of(:text, button), color_of(:background, button))
    assert_operator ratio, :>=, 4.5, "outline label is #{ratio.round(2)}:1 inside white host text"
  end

  # BTN4, including the destructive variant.
  test 'the focus ring reaches 3:1 against the surface on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      VARIANTS.each do |variant|
        button = preview_button(variant)
        focus_visibly(button)
        assert_not_equal 'none', outline_of(button)['style'], "#{variant} draws no focus outline"
        ratio = contrast_ratio(color_of(:outline, button), color_of(:background, preview))
        assert_operator ratio, :>=, 3, "#{variant} focus ring is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
      end
    end
  end

  # The outline variant's border is a control boundary, as an input's is (WCAG 1.4.11).
  test 'the outline variant border reaches 3:1 against its fill and the surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      button = preview_button('outline')
      border = color_of(:border, button)
      { 'fill' => color_of(:background, button), 'surface' => color_of(:background, preview) }.each do |against, color|
        ratio = contrast_ratio(border, color)
        assert_operator ratio, :>=, 3, "outline border is #{ratio.round(2)}:1 against its #{against} on #{surface} in #{mode} mode"
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
end
