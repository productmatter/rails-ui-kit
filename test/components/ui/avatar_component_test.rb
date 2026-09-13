# frozen_string_literal: true

require 'test_helper'

module Ui
  class AvatarComponentTest < ViewComponent::TestCase
    def render_avatar(**options)
      render_inline(Ui::AvatarComponent.new(**options)) do |avatar|
        avatar.with_image(src: '/jane.png')
        avatar.with_fallback { 'JD' }
      end
    end

    def avatar_classes
      page.find('[data-slot=avatar]')['class'].split
    end

    test 'renders the root with the avatar data-slot and token classes' do
      render_avatar

      assert_selector "span[data-slot='avatar']"
      assert_includes avatar_classes, 'rounded-full'
      assert_includes avatar_classes, 'overflow-hidden'
    end

    test 'renders every part with its data-slot' do
      render_avatar

      assert_selector "[data-slot='avatar'] > [data-slot='avatar-fallback']", count: 1
      assert_selector "[data-slot='avatar'] > [data-slot='avatar-image']", count: 1
    end

    test 'the fallback renders before the image, underneath it' do
      render_avatar

      order = page.all('[data-slot=avatar] > *').map { |node| node['data-slot'] }
      assert_equal %w[avatar-fallback avatar-image], order
    end

    test 'the image is layered over the fallback' do
      render_avatar

      image_classes = page.find('[data-slot=avatar-image]')['class'].split
      assert_includes image_classes, 'absolute'
      assert_includes image_classes, 'inset-0'
    end

    test 'omitted parts render no element' do
      render_inline(Ui::AvatarComponent.new) { |avatar| avatar.with_fallback { 'JD' } }

      assert_selector "[data-slot='avatar-fallback']", text: 'JD'
      assert_no_selector "[data-slot='avatar-image']"
    end

    test 'forwards the src attribute to the image' do
      render_avatar

      assert_selector "[data-slot='avatar-image'][src='/jane.png']"
    end

    test 'without alt: the avatar carries no role or accessible name' do
      render_avatar

      avatar = page.find('[data-slot=avatar]')
      assert_nil avatar['role']
      assert_nil avatar['aria-label']
    end

    test 'without alt: the image has an empty alt so a failed load shows nothing' do
      render_avatar

      assert_equal '', page.find('[data-slot=avatar-image]')['alt']
    end

    test 'without alt: the fallback is hidden from assistive tech' do
      render_avatar

      assert_selector "[data-slot='avatar-fallback'][aria-hidden='true']"
    end

    test 'with alt: the avatar becomes an accessible image with that name' do
      render_avatar(alt: 'Jane Doe')

      assert_selector "[data-slot='avatar'][role='img'][aria-label='Jane Doe']"
    end

    test 'with alt: the image alt stays empty, so the name is never duplicated or flashed on a failed load' do
      render_avatar(alt: 'Jane Doe')

      assert_equal '', page.find('[data-slot=avatar-image]')['alt']
    end

    test 'with alt: the fallback stays hidden from assistive tech, so the name is announced once' do
      render_avatar(alt: 'Jane Doe')

      assert_selector "[data-slot='avatar-fallback'][aria-hidden='true']"
    end

    test 'a caller can mark its fallback as carrying meaning on its own' do
      render_inline(Ui::AvatarComponent.new) do |avatar|
        avatar.with_fallback(aria: { hidden: false }) { 'JD' }
      end

      assert_selector "[data-slot='avatar-fallback'][aria-hidden='false']"
    end

    test 'caller class on the root wins over a conflicting default' do
      render_inline(Ui::AvatarComponent.new(class: 'size-12')) { |avatar| avatar.with_fallback { 'JD' } }

      assert_includes avatar_classes, 'size-12'
      assert_not_includes avatar_classes, 'size-8'
    end

    test 'caller class on a part wins over a conflicting default' do
      render_inline(Ui::AvatarComponent.new) do |avatar|
        avatar.with_fallback(class: 'text-xs') { 'JD' }
      end

      fallback_classes = page.find('[data-slot=avatar-fallback]')['class'].split
      assert_includes fallback_classes, 'text-xs'
      assert_not_includes fallback_classes, 'text-sm'
    end

    test 'forwards html attributes to the root element' do
      render_inline(Ui::AvatarComponent.new(id: 'user-avatar', data: { testid: 'avatar' })) do |avatar|
        avatar.with_fallback { 'JD' }
      end

      assert_selector "span#user-avatar[data-slot='avatar'][data-testid='avatar']"
    end

    test 'forwards html attributes to a part' do
      render_inline(Ui::AvatarComponent.new) do |avatar|
        avatar.with_fallback(id: 'jd-fallback') { 'JD' }
        avatar.with_image(src: '/jane.png', data: { testid: 'photo' })
      end

      assert_selector "span#jd-fallback[data-slot='avatar-fallback']"
      assert_selector "img[data-slot='avatar-image'][data-testid='photo']"
    end

    test 'nested parts compose from an erb template' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::AvatarComponent.new(id: "erb-avatar", alt: "Jane Doe") do |avatar| %>
            <% avatar.with_image(src: "/jane.png") %>
            <% avatar.with_fallback { "JD" } %>
          <% end %>
        ERB
      end

      assert_selector "#erb-avatar > [data-slot='avatar-fallback']", text: 'JD'
      assert_selector "#erb-avatar > [data-slot='avatar-image']"
      assert_equal 1, page.all("[data-slot='avatar-image']").size
    end
  end
end
