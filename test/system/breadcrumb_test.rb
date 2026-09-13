# frozen_string_literal: true

require 'application_system_test_case'

class BreadcrumbTest < ApplicationSystemTestCase
  setup do
    visit breadcrumb_path
    disable_transitions
  end

  test 'link and current-page text reach 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      link = preview.first('[data-slot=breadcrumb-link]')
      link_ratio = contrast_ratio(color_of(:text, link), color_of(:background, preview))
      assert_operator link_ratio, :>=, 4.5, "link is #{link_ratio.round(2)}:1 on #{surface} in #{mode} mode"

      page_item = preview.first('[data-slot=breadcrumb-page]')
      page_ratio = contrast_ratio(color_of(:text, page_item), color_of(:background, preview))
      assert_operator page_ratio, :>=, 4.5, "current page is #{page_ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'every link keeps a focus indicator that survives forced colours and reaches 3:1' do
    preview.all('[data-slot=breadcrumb-link]').each do |link|
      assert_focus_outline_in_forced_colors(link, link.text)
    end
  end

  test 'the focus ring reaches 3:1 against the surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      link = preview.first('[data-slot=breadcrumb-link]')
      focus_visibly(link)
      ratio = contrast_ratio(color_of(:outline, link), color_of(:background, preview))
      assert_operator ratio, :>=, 3, "focus ring is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'separators are hidden from assistive tech and the ellipsis keeps an accessible name' do
    separator = preview.first('[data-slot=breadcrumb-separator]', visible: :all)
    assert_equal 'true', separator['aria-hidden']

    ellipsis = preview.find('[data-slot=breadcrumb-ellipsis]')
    assert_equal '2 hidden pages', ellipsis['aria-label']
  end

  test 'the breadcrumb preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#breadcrumb-preview')

    use_dark_mode(true)
    assert_accessible(within: '#breadcrumb-preview')
  end

  private

  def preview
    find_by_id('breadcrumb-preview')
  end
end
