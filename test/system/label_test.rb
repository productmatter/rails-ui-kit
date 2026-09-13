# frozen_string_literal: true

require 'application_system_test_case'

class LabelTest < ApplicationSystemTestCase
  setup do
    visit label_path
    disable_transitions
  end

  test 'label text reaches 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      label = preview.find('[data-slot=label]', text: 'Email', match: :first)
      ratio = contrast_ratio(color_of(:text, label), color_of(:background, label))
      assert_operator ratio, :>=, 4.5, "label is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'a label dims when its peer control is disabled' do
    enabled_label = preview.find('[data-slot=label]', text: 'Email')
    disabled_label = preview.find('[data-slot=label]', text: 'Accept the terms')

    assert_equal '1', opacity_of(enabled_label)
    assert_equal '0.5', opacity_of(disabled_label)
  end

  test 'a label dims when its group is disabled' do
    group_label = preview.find('[data-slot=label]', text: 'Notes')

    assert_equal '0.5', opacity_of(group_label)
  end

  test 'the label preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#label-preview')

    use_dark_mode(true)
    assert_accessible(within: '#label-preview')
  end

  private

  def preview
    find_by_id('label-preview')
  end

  def opacity_of(element)
    page.evaluate_script('getComputedStyle(arguments[0]).opacity', element)
  end
end
