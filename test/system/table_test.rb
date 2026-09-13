# frozen_string_literal: true

require 'application_system_test_case'

class TableTest < ApplicationSystemTestCase
  setup do
    visit table_path
    disable_transitions
  end

  test 'the caption, header and cell text reach 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      caption = preview.find('[data-slot=table-caption]')
      caption_ratio = contrast_ratio(color_of(:text, caption), color_of(:background, preview))
      assert_operator caption_ratio, :>=, 4.5, "caption is #{caption_ratio.round(2)}:1 on #{surface} in #{mode} mode"

      head = preview.first('[data-slot=table-head]')
      head_ratio = contrast_ratio(color_of(:text, head), color_of(:background, preview))
      assert_operator head_ratio, :>=, 4.5, "header cell is #{head_ratio.round(2)}:1 on #{surface} in #{mode} mode"

      cell = preview.first('[data-slot=table-cell]')
      cell_ratio = contrast_ratio(color_of(:text, cell), color_of(:background, preview))
      assert_operator cell_ratio, :>=, 4.5, "body cell is #{cell_ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'the table preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#table-preview')

    use_dark_mode(true)
    assert_accessible(within: '#table-preview')
  end

  private

  def preview
    find_by_id('table-preview')
  end
end
