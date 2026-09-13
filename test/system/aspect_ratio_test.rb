# frozen_string_literal: true

require 'application_system_test_case'

class AspectRatioTest < ApplicationSystemTestCase
  # Doc order in the preview: square, video, portrait, classic.
  EXPECTED_RATIOS = [1.0, 9.0 / 16, 4.0 / 3, 3.0 / 4].freeze

  setup do
    visit aspect_ratio_path
    disable_transitions
  end

  test 'each ratio box is exactly as tall as its width times its ratio' do
    boxes = preview.all('[data-slot=aspect-ratio]')
    assert_equal EXPECTED_RATIOS.size, boxes.size

    boxes.zip(EXPECTED_RATIOS).each_with_index do |(box, expected_ratio), index|
      rect = page.evaluate_script('arguments[0].getBoundingClientRect()', box)
      assert_in_delta expected_ratio, rect['height'].to_f / rect['width'], 0.02, "box #{index} is not the expected ratio"
    end
  end

  test 'the aspect ratio preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#aspect_ratio-preview')

    use_dark_mode(true)
    assert_accessible(within: '#aspect_ratio-preview')
  end

  private

  def preview
    find_by_id('aspect_ratio-preview')
  end
end
