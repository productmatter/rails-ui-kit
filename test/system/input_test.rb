# frozen_string_literal: true

require 'application_system_test_case'

class InputTest < ApplicationSystemTestCase
  setup do
    visit input_path
    disable_transitions
  end

  test 'the focus indicator survives forced-colors mode' do
    assert_focus_outline_in_forced_colors(field('focused-input'), 'input')
  end

  test 'entered text and placeholder text reach 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      value_field = field('default-input')
      ratio = contrast_ratio(color_of(:text, value_field), color_of(:background, value_field))
      assert_operator ratio, :>=, 4.5, "entered text is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"

      placeholder_field = field('placeholder-input')
      ratio = contrast_ratio(color_of(:text, placeholder_field), color_of(:background, placeholder_field))
      assert_operator ratio, :>=, 4.5, "placeholder text is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'the focus ring reaches 3:1 against the surface on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      input = field('focused-input')
      focus_visibly(input)
      assert_not_equal 'none', outline_of(input)['style'], 'input draws no focus outline'
      ratio = contrast_ratio(color_of(:outline, input), color_of(:background, preview))
      assert_operator ratio, :>=, 3, "focus ring is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'the control boundary reaches 3:1 against its fill and the surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      input = field('default-input')
      border = color_of(:border, input)
      { 'fill' => color_of(:background, input), 'surface' => color_of(:background, preview) }.each do |against, color|
        ratio = contrast_ratio(border, color)
        assert_operator ratio, :>=, 3, "boundary is #{ratio.round(2)}:1 against its #{against} on #{surface} in #{mode} mode"
      end
    end
  end

  test 'the input preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#input-preview')

    use_dark_mode(true)
    assert_accessible(within: '#input-preview')
  end

  private

  def preview
    find_by_id('input-preview')
  end

  def field(id)
    preview.find_field(id: id)
  end
end
