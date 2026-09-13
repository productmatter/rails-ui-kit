# frozen_string_literal: true

require 'application_system_test_case'

class EmptyTest < ApplicationSystemTestCase
  setup do
    visit empty_path
    disable_transitions
  end

  test 'title and description reach 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      empty = surface_check
      title = empty.find('[data-slot=empty-title]')
      description = empty.find('[data-slot=empty-description]')

      title_ratio = contrast_ratio(color_of(:text, title), color_of(:background, empty))
      assert_operator title_ratio, :>=, 4.5, "title is #{title_ratio.round(2)}:1 on #{surface} in #{mode} mode"

      description_ratio = contrast_ratio(color_of(:text, description), color_of(:background, empty))
      assert_operator description_ratio, :>=, 4.5, "description is #{description_ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'the empty preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#empty-preview')

    use_dark_mode(true)
    assert_accessible(within: '#empty-preview')
  end

  private

  def preview
    find_by_id('empty-preview')
  end

  # Empty paints no background of its own; this instance sits with nothing else
  # painting between it and #empty-preview, so its rendered background actually
  # tracks each_token_surface instead of a fixed demo box.
  def surface_check
    find_by_id('empty-surface-check').find('[data-slot=empty]')
  end
end
