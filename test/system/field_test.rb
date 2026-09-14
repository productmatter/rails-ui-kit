# frozen_string_literal: true

require 'application_system_test_case'

class FieldTest < ApplicationSystemTestCase
  setup do
    visit field_path
    disable_transitions
  end

  test 'the field preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#field-preview')

    use_dark_mode(true)
    assert_accessible(within: '#field-preview')
  end

  test 'error text reaches 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      error = preview.find('[data-slot=field-error]')
      ratio = contrast_ratio(color_of(:text, error), color_of(:background, preview))
      assert_operator ratio, :>=, 4.5, "error text is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  private

  def preview
    find_by_id('field-preview')
  end
end
