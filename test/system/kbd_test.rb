# frozen_string_literal: true

require 'application_system_test_case'

class KbdTest < ApplicationSystemTestCase
  setup do
    visit kbd_path
    disable_transitions
  end

  test 'key cap text reaches 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      preview.all('[data-slot=kbd]').each do |kbd|
        ratio = contrast_ratio(color_of(:text, kbd), color_of(:background, kbd))
        assert_operator ratio, :>=, 4.5, "kbd text is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
      end
    end
  end

  test 'the kbd preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#kbd-preview')

    use_dark_mode(true)
    assert_accessible(within: '#kbd-preview')
  end

  private

  def preview
    find_by_id('kbd-preview')
  end
end
