# frozen_string_literal: true

require 'test_helper'

module Ui
  class AspectRatioComponentTest < ViewComponent::TestCase
    RATIO_MARKERS = {
      square: 'aspect-square',
      video: 'aspect-video',
      portrait: 'aspect-[3/4]',
      classic: 'aspect-[4/3]'
    }.freeze

    def ratio_classes
      page.find('[data-slot=aspect-ratio]')['class'].split
    end

    test 'renders a div element' do
      render_inline(Ui::AspectRatioComponent.new)

      assert_selector 'div'
    end

    test 'stamps data-slot on the root element' do
      render_inline(Ui::AspectRatioComponent.new)

      assert_selector "div[data-slot='aspect-ratio']"
    end

    test 'defaults to the square ratio' do
      render_inline(Ui::AspectRatioComponent.new)

      assert_includes ratio_classes, 'aspect-square'
    end

    RATIO_MARKERS.each do |ratio, marker|
      test "renders the #{ratio} ratio" do
        render_inline(Ui::AspectRatioComponent.new(ratio: ratio))

        assert_includes ratio_classes, marker
      end
    end

    test 'renders only the requested ratio classes' do
      render_inline(Ui::AspectRatioComponent.new(ratio: :video))

      assert_includes ratio_classes, 'aspect-video'
      assert_not_includes ratio_classes, 'aspect-square'
    end

    test 'accepts a string ratio value' do
      render_inline(Ui::AspectRatioComponent.new(ratio: 'portrait'))

      assert_includes ratio_classes, 'aspect-[3/4]'
    end

    test 'nil ratio falls back to the default' do
      render_inline(Ui::AspectRatioComponent.new(ratio: nil))

      assert_includes ratio_classes, 'aspect-square'
    end

    test 'an unknown ratio raises in development and test' do
      assert_raises(Ui::Base::UnknownVariantError) { render_inline(Ui::AspectRatioComponent.new(ratio: :ultrawide)) }
    end

    test 'the child fills the box regardless of its own markup' do
      render_inline(Ui::AspectRatioComponent.new) { '<img src="/photo.jpg">'.html_safe }

      assert_selector "[data-slot='aspect-ratio'] > div.absolute.inset-0 > img[src='/photo.jpg']"
    end

    test 'a ratio outside the fixed set comes from the caller class and wins over the default' do
      render_inline(Ui::AspectRatioComponent.new(class: 'aspect-[21/9]'))

      assert_includes ratio_classes, 'aspect-[21/9]'
      assert_not_includes ratio_classes, 'aspect-square'
    end

    test 'caller class wins over a conflicting default' do
      render_inline(Ui::AspectRatioComponent.new(class: 'w-1/2'))

      assert_includes ratio_classes, 'w-1/2'
      assert_not_includes ratio_classes, 'w-full'
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(Ui::AspectRatioComponent.new(id: 'hero-media', data: { testid: 'ratio' }))

      assert_selector "div#hero-media[data-slot='aspect-ratio'][data-testid='ratio']"
    end
  end
end
