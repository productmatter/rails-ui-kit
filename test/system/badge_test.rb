# frozen_string_literal: true

require 'application_system_test_case'

class BadgeTest < ApplicationSystemTestCase
  VARIANTS = %w[default secondary destructive outline].freeze

  setup do
    visit badge_path
    disable_transitions
  end

  test 'every variant label reaches 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      VARIANTS.each do |variant|
        badge = preview_badge(variant)
        ratio = contrast_ratio(color_of(:text, badge), color_of(:background, badge))
        assert_operator ratio, :>=, 4.5, "#{variant} label is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
      end
    end
  end

  test 'the outline variant border reaches 3:1 against its fill and the surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      badge = preview_badge('outline')
      border = color_of(:border, badge)
      { 'fill' => color_of(:background, badge), 'surface' => color_of(:background, preview) }.each do |against, color|
        ratio = contrast_ratio(border, color)
        assert_operator ratio, :>=, 3, "outline border is #{ratio.round(2)}:1 against its #{against} on #{surface} in #{mode} mode"
      end
    end
  end

  test 'the focus indicator on a link badge survives forced-colors mode' do
    assert_focus_outline_in_forced_colors(preview_link_badge, 'link badge')
  end

  test 'the focus ring on a link badge reaches 3:1 against the surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      badge = preview_link_badge
      focus_visibly(badge)
      assert_not_equal 'none', outline_of(badge)['style'], 'link badge draws no focus outline'
      ratio = contrast_ratio(color_of(:outline, badge), color_of(:background, preview))
      assert_operator ratio, :>=, 3, "link badge focus ring is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'the badge preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#badge-preview')

    use_dark_mode(true)
    assert_accessible(within: '#badge-preview')
  end

  private

  def preview
    find_by_id('badge-preview')
  end

  def preview_badge(variant)
    preview.find('[data-slot=badge]', exact_text: variant.capitalize)
  end

  def preview_link_badge
    preview.find('a[data-slot=badge]')
  end
end
