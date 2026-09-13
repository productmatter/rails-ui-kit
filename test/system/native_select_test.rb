# frozen_string_literal: true

require 'application_system_test_case'

class NativeSelectTest < ApplicationSystemTestCase
  setup do
    visit native_select_path
    disable_transitions
  end

  test 'the focus indicator survives forced-colors mode' do
    assert_focus_outline_in_forced_colors(field('focused-select'), 'select')
  end

  test 'the selected value reaches 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      select = field('default-select')
      ratio = contrast_ratio(color_of(:text, select), color_of(:background, select))
      assert_operator ratio, :>=, 4.5, "selected value is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'the focus ring reaches 3:1 against the surface on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      select = field('focused-select')
      focus_visibly(select)
      assert_not_equal 'none', outline_of(select)['style'], 'select draws no focus outline'
      ratio = contrast_ratio(color_of(:outline, select), color_of(:background, preview))
      assert_operator ratio, :>=, 3, "focus ring is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'the control boundary reaches 3:1 against its fill and the surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      select = field('default-select')
      border = color_of(:border, select)
      { 'fill' => color_of(:background, select), 'surface' => color_of(:background, preview) }.each do |against, color|
        ratio = contrast_ratio(border, color)
        assert_operator ratio, :>=, 3, "boundary is #{ratio.round(2)}:1 against its #{against} on #{surface} in #{mode} mode"
      end
    end
  end

  test 'the chevron is hidden from the accessibility tree' do
    chevron = preview.first('svg', visible: :all)
    assert_equal 'true', chevron['aria-hidden']
  end

  test 'the native_select preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#native_select-preview')

    use_dark_mode(true)
    assert_accessible(within: '#native_select-preview')
  end

  private

  def preview
    find_by_id('native_select-preview')
  end

  def field(id)
    preview.find_field(id: id)
  end
end
