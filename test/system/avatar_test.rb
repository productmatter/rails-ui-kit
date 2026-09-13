# frozen_string_literal: true

require 'application_system_test_case'

class AvatarTest < ApplicationSystemTestCase
  setup do
    visit avatar_path
    disable_transitions
  end

  test 'fallback initials reach 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      preview.all('[data-slot=avatar-fallback]', visible: :all).each do |fallback|
        ratio = contrast_ratio(color_of(:text, fallback), color_of(:background, fallback))
        assert_operator ratio, :>=, 4.5, "fallback is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
      end
    end
  end

  test 'an avatar whose image fails to load still shows readable initials' do
    avatar = preview.find('[data-slot=avatar][aria-label="Alex Rivera"]')
    fallback = avatar.find('[data-slot=avatar-fallback]', visible: :all)

    assert_equal 'AR', fallback.text(normalize_ws: true)
    ratio = contrast_ratio(color_of(:text, fallback), color_of(:background, fallback))
    assert_operator ratio, :>=, 4.5, "fallback behind a failed image is #{ratio.round(2)}:1"
  end

  test 'the avatar preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#avatar-preview')

    use_dark_mode(true)
    assert_accessible(within: '#avatar-preview')
  end

  private

  def preview
    find_by_id('avatar-preview')
  end
end
