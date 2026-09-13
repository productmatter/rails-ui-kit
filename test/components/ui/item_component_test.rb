# frozen_string_literal: true

require 'test_helper'

module Ui
  class ItemComponentTest < ViewComponent::TestCase
    PART_SLOTS = %w[item-header item-media item-content item-title item-description item-actions item-footer].freeze

    VARIANT_MARKERS = {
      default: 'bg-transparent',
      outline: 'border-input',
      muted: 'bg-muted/50'
    }.freeze

    SIZE_MARKERS = {
      default: 'p-4',
      sm: 'px-4'
    }.freeze

    def classes_for(slot)
      page.find("[data-slot='#{slot}']")['class'].split
    end

    def render_full_item(**options)
      render_inline(Ui::ItemComponent.new(**options)) do |item|
        item.with_header { 'Header' }
        item.with_media(variant: :icon) { '<svg></svg>'.html_safe }
        item.with_title { 'Title' }
        item.with_description { 'Description' }
        item.with_actions { 'Actions' }
        item.with_footer { 'Footer' }
      end
    end

    test 'renders the root with the item data-slot and token classes' do
      render_inline(Ui::ItemComponent.new) { |item| item.with_title { 'Title' } }

      assert_selector "div[data-slot='item']"
      assert_includes classes_for('item'), 'rounded-md'
    end

    test 'renders every part with its data-slot' do
      render_full_item

      PART_SLOTS.each { |slot| assert_selector "[data-slot='item'] [data-slot='#{slot}']", count: 1 }
    end

    test 'renders parts in the fixed anatomy order regardless of call order' do
      render_inline(Ui::ItemComponent.new) do |item|
        item.with_footer { 'Footer' }
        item.with_actions { 'Actions' }
        item.with_description { 'Description' }
        item.with_title { 'Title' }
        item.with_media { 'Media' }
        item.with_header { 'Header' }
      end

      order = page.all("[data-slot='item'] > [data-slot]").map { |node| node['data-slot'] }
      assert_equal %w[item-header item-media item-content item-actions item-footer], order
    end

    test 'title and description nest inside the item-content wrapper' do
      render_full_item

      assert_selector "[data-slot='item-content'] > [data-slot='item-title']", text: 'Title'
      assert_selector "[data-slot='item-content'] > [data-slot='item-description']", text: 'Description'
    end

    test 'the item-content wrapper renders nothing when title and description are both omitted' do
      render_inline(Ui::ItemComponent.new) { |item| item.with_media { 'Media' } }

      assert_no_selector "[data-slot='item-content']"
    end

    test 'the item-content wrapper renders with only a title' do
      render_inline(Ui::ItemComponent.new) { |item| item.with_title { 'Title only' } }

      assert_selector "[data-slot='item-content'] > [data-slot='item-title']", text: 'Title only'
      assert_no_selector "[data-slot='item-description']"
    end

    VARIANT_MARKERS.each do |variant, marker|
      test "renders the #{variant} variant" do
        render_inline(Ui::ItemComponent.new(variant: variant)) { |item| item.with_title { 'Title' } }

        assert_includes classes_for('item'), marker
      end
    end

    SIZE_MARKERS.each do |size, marker|
      test "renders the #{size} size" do
        render_inline(Ui::ItemComponent.new(size: size)) { |item| item.with_title { 'Title' } }

        assert_includes classes_for('item'), marker
      end
    end

    test 'an unknown variant raises in development and test' do
      assert_raises(Ui::Base::UnknownVariantError) do
        render_inline(Ui::ItemComponent.new(variant: :fancy)) { |item| item.with_title { 'Title' } }
      end
    end

    test 'an unknown size raises in development and test' do
      assert_raises(Ui::Base::UnknownVariantError) do
        render_inline(Ui::ItemComponent.new(size: :lg)) { |item| item.with_title { 'Title' } }
      end
    end

    MEDIA_VARIANT_MARKERS = {
      default: 'bg-transparent',
      icon: 'rounded-sm',
      image: 'overflow-hidden'
    }.freeze

    MEDIA_VARIANT_MARKERS.each do |variant, marker|
      test "renders the #{variant} media variant" do
        render_inline(Ui::ItemComponent.new) { |item| item.with_media(variant: variant) { 'Media' } }

        assert_includes classes_for('item-media'), marker
      end
    end

    test 'omitted parts render no element' do
      render_inline(Ui::ItemComponent.new) { |item| item.with_title { 'Only title' } }

      assert_selector "[data-slot='item-title']", text: 'Only title'
      (PART_SLOTS - %w[item-content item-title]).each { |slot| assert_no_selector "[data-slot='#{slot}']" }
    end

    test 'caller class on the root wins over a conflicting default' do
      render_inline(Ui::ItemComponent.new(class: 'rounded-none')) { |item| item.with_title { 'Title' } }

      assert_includes classes_for('item'), 'rounded-none'
      assert_not_includes classes_for('item'), 'rounded-md'
    end

    test 'caller class on a part wins over a conflicting default' do
      render_inline(Ui::ItemComponent.new) do |item|
        item.with_title(class: 'text-base') { 'Title' }
        item.with_actions(class: 'gap-4') { 'Actions' }
      end

      assert_includes classes_for('item-title'), 'text-base'
      assert_not_includes classes_for('item-title'), 'text-sm'
      assert_includes classes_for('item-actions'), 'gap-4'
      assert_not_includes classes_for('item-actions'), 'gap-2'
    end

    test 'forwards html attributes to the root element' do
      render_inline(Ui::ItemComponent.new(id: 'row-1', data: { testid: 'item' })) { |item| item.with_title { 'Title' } }

      assert_selector "div#row-1[data-slot='item'][data-testid='item']"
    end

    test 'forwards html attributes to a part' do
      render_inline(Ui::ItemComponent.new) do |item|
        item.with_title(id: 'row-title') { 'Title' }
        item.with_actions(data: { controller: 'demo' }) { 'Actions' }
      end

      assert_selector "div#row-title[data-slot='item-title']"
      assert_selector "div[data-slot='item-actions'][data-controller='demo']"
    end

    test 'nested parts compose from an erb template' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::ItemComponent.new(id: "erb-item", variant: :outline) do |item| %>
            <% item.with_media(variant: :icon) do %>
              <svg viewBox="0 0 24 24"></svg>
            <% end %>
            <% item.with_title { "Billing" } %>
            <% item.with_description { "Manage your plan" } %>
            <% item.with_actions do %>
              <%= render(Ui::ButtonComponent.new(variant: :outline, size: :sm)) { "Edit" } %>
            <% end %>
          <% end %>
        ERB
      end

      assert_selector "#erb-item > [data-slot='item-media']"
      assert_selector "#erb-item > [data-slot='item-content'] > [data-slot='item-title']", text: 'Billing'
      assert_selector "[data-slot='item-actions'] > [data-slot='button']", text: 'Edit'
      assert_equal 1, page.all("[data-slot='item-title']").size
    end

    test 'group renders items and separators in call order under item-group' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::Item::GroupComponent.new do %>
            <%= render(Ui::ItemComponent.new) { |item| item.with_title { "One" } } %>
            <%= render(Ui::Item::SeparatorComponent.new) %>
            <%= render(Ui::ItemComponent.new) { |item| item.with_title { "Two" } } %>
          <% end %>
        ERB
      end

      assert_selector "[data-slot='item-group']"
      order = page.all("[data-slot='item-group'] > [data-slot]").map { |node| node['data-slot'] }
      assert_equal %w[item item-separator item], order
    end

    test 'the separator delegates to the shared separator component, relabelled' do
      render_inline(Ui::Item::SeparatorComponent.new)

      assert_selector "[data-slot='item-separator']"
      assert_no_selector "[data-slot='separator']"
      assert_includes page.find('[data-slot=item-separator]')['class'].split, 'bg-border'
    end

    test 'group caller class wins over its conflicting default' do
      render_inline(Ui::Item::GroupComponent.new(class: 'gap-2'))

      classes = page.find('[data-slot=item-group]')['class'].split
      assert_includes classes, 'gap-2'
    end

    test 'group forwards html attributes to its root element' do
      render_inline(Ui::Item::GroupComponent.new(id: 'items', data: { testid: 'group' }))

      assert_selector "#items[data-slot='item-group'][data-testid='group']"
    end
  end
end
