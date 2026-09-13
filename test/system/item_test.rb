# frozen_string_literal: true

require 'application_system_test_case'

class ItemTest < ApplicationSystemTestCase
  # Title text of the Variants section's rows, keyed by variant -- distinct from
  # the Sizes section below it, which would otherwise collide on exact_text.
  VARIANTS = %w[Default Outline Muted].freeze

  setup do
    visit item_path
    disable_transitions
  end

  test 'title and description reach 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      VARIANTS.each do |variant|
        item = variant_item(variant)
        title = item.find('[data-slot=item-title]')
        description = item.find('[data-slot=item-description]')

        title_ratio = contrast_ratio(color_of(:text, title), color_of(:background, item))
        assert_operator title_ratio, :>=, 4.5, "#{variant} title is #{title_ratio.round(2)}:1 on #{surface} in #{mode} mode"

        description_ratio = contrast_ratio(color_of(:text, description), color_of(:background, item))
        assert_operator description_ratio, :>=, 4.5, "#{variant} description is #{description_ratio.round(2)}:1 on #{surface} in #{mode} mode"
      end
    end
  end

  test 'the outline variant border reaches 3:1 against its fill and the surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      item = variant_item('Outline')
      border = color_of(:border, item)
      { 'fill' => color_of(:background, item), 'surface' => color_of(:background, preview) }.each do |against, color|
        ratio = contrast_ratio(border, color)
        assert_operator ratio, :>=, 3, "outline border is #{ratio.round(2)}:1 against its #{against} on #{surface} in #{mode} mode"
      end
    end
  end

  test 'the item preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#item-preview')

    use_dark_mode(true)
    assert_accessible(within: '#item-preview')
  end

  private

  def preview
    find_by_id('item-preview')
  end

  def variant_item(title_text)
    preview.find('[data-slot=item-title]', exact_text: title_text).find(:xpath, 'ancestor::*[@data-slot="item"][1]')
  end
end
