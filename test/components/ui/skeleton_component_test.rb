# frozen_string_literal: true

require 'test_helper'

module Ui
  class SkeletonComponentTest < ViewComponent::TestCase
    def skeleton_classes
      page.find('[data-slot=skeleton]')['class'].split
    end

    test 'renders a div element' do
      render_inline(Ui::SkeletonComponent.new)

      assert_selector 'div'
    end

    test 'stamps data-slot on the root element' do
      render_inline(Ui::SkeletonComponent.new)

      assert_selector "div[data-slot='skeleton']"
    end

    test 'is hidden from assistive technology since it is decorative' do
      render_inline(Ui::SkeletonComponent.new)

      assert_selector "div[aria-hidden='true']"
    end

    test 'pulses by default and stops under reduced motion' do
      render_inline(Ui::SkeletonComponent.new)

      assert_includes skeleton_classes, 'animate-pulse'
      assert_includes skeleton_classes, 'motion-reduce:animate-none'
    end

    test 'renders block content' do
      render_inline(Ui::SkeletonComponent.new) { '<span>Line</span>'.html_safe }

      assert_selector "[data-slot='skeleton'] span", text: 'Line'
    end

    test 'caller class wins over a conflicting default' do
      render_inline(Ui::SkeletonComponent.new(class: 'rounded-full'))

      assert_includes skeleton_classes, 'rounded-full'
      assert_not_includes skeleton_classes, 'rounded-md'
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(Ui::SkeletonComponent.new(id: 'avatar-skeleton', data: { testid: 'skeleton' }))

      assert_selector "div#avatar-skeleton[data-slot='skeleton'][data-testid='skeleton']"
    end

    test 'a caller aria hash still merges alongside the component default' do
      render_inline(Ui::SkeletonComponent.new(aria: { label: 'Loading users' }))

      assert_selector "div[aria-hidden='true'][aria-label='Loading users']"
    end
  end
end
