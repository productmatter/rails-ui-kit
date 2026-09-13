# frozen_string_literal: true

require 'application_system_test_case'

class TextareaTest < ApplicationSystemTestCase
  setup do
    visit textarea_path
    disable_transitions
  end

  test 'the focus indicator survives forced-colors mode' do
    assert_focus_outline_in_forced_colors(field('focused-textarea'), 'textarea')
  end

  test 'entered text and placeholder text reach 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      value_field = field('default-textarea')
      ratio = contrast_ratio(color_of(:text, value_field), color_of(:background, value_field))
      assert_operator ratio, :>=, 4.5, "entered text is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"

      placeholder_field = field('placeholder-textarea')
      ratio = contrast_ratio(color_of(:text, placeholder_field), color_of(:background, placeholder_field))
      assert_operator ratio, :>=, 4.5, "placeholder text is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'the focus ring reaches 3:1 against the surface on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      textarea = field('focused-textarea')
      focus_visibly(textarea)
      assert_not_equal 'none', outline_of(textarea)['style'], 'textarea draws no focus outline'
      ratio = contrast_ratio(color_of(:outline, textarea), color_of(:background, preview))
      assert_operator ratio, :>=, 3, "focus ring is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'the control boundary reaches 3:1 against its fill and the surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      textarea = field('default-textarea')
      border = color_of(:border, textarea)
      { 'fill' => color_of(:background, textarea), 'surface' => color_of(:background, preview) }.each do |against, color|
        ratio = contrast_ratio(border, color)
        assert_operator ratio, :>=, 3, "boundary is #{ratio.round(2)}:1 against its #{against} on #{surface} in #{mode} mode"
      end
    end
  end

  test 'the textarea preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#textarea-preview')

    use_dark_mode(true)
    assert_accessible(within: '#textarea-preview')
  end

  private

  def preview
    find_by_id('textarea-preview')
  end

  def field(id)
    preview.find_field(id: id)
  end
end
