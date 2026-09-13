# frozen_string_literal: true

require 'application_system_test_case'

class PaginationTest < ApplicationSystemTestCase
  setup do
    visit pagination_path
    disable_transitions
  end

  test 'the current and other page labels reach 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      active = preview.find('[data-slot=button][aria-current=page]')
      active_ratio = contrast_ratio(color_of(:text, active), color_of(:background, active))
      assert_operator active_ratio, :>=, 4.5, "active page label is #{active_ratio.round(2)}:1 on #{surface} in #{mode} mode"

      other = preview.find('[data-slot=button]', exact_text: '1')
      other_ratio = contrast_ratio(color_of(:text, other), color_of(:background, preview))
      assert_operator other_ratio, :>=, 4.5, "page label is #{other_ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test "the active page's border reaches 3:1 against its fill and the surface in light and dark mode" do
    each_token_surface(preview) do |mode, surface|
      active = preview.find('[data-slot=button][aria-current=page]')
      border = color_of(:border, active)
      { 'fill' => color_of(:background, active), 'surface' => color_of(:background, preview) }.each do |against, color|
        ratio = contrast_ratio(border, color)
        assert_operator ratio, :>=, 3, "active page border is #{ratio.round(2)}:1 against its #{against} on #{surface} in #{mode} mode"
      end
    end
  end

  test 'every link keeps a focus indicator that survives forced colours and reaches 3:1' do
    preview.all('[data-slot=pagination-link] [data-slot=button]').each do |link|
      assert_focus_outline_in_forced_colors(link, link['aria-label'] || link.text)
    end
  end

  test 'previous and next carry their own accessible name and the ellipsis is decorative' do
    assert_selector "[data-slot=button][aria-label='Go to previous page']"
    assert_selector "[data-slot=button][aria-label='Go to next page']"

    ellipsis = preview.find('[data-slot=pagination-ellipsis]', visible: :all)
    assert_equal 'true', ellipsis['aria-hidden']
  end

  test 'the pagination preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#pagination-preview')

    use_dark_mode(true)
    assert_accessible(within: '#pagination-preview')
  end

  private

  def preview
    find_by_id('pagination-preview')
  end
end
