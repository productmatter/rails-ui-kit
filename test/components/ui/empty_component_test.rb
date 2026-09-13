# frozen_string_literal: true

require 'test_helper'

module Ui
  class EmptyComponentTest < ViewComponent::TestCase
    PART_SLOTS = %w[empty-header empty-media empty-title empty-description empty-content].freeze

    def classes_for(slot)
      page.find("[data-slot='#{slot}']")['class'].split
    end

    def render_full_empty
      render_inline(Ui::EmptyComponent.new) do |empty|
        empty.with_header do |header|
          header.with_media(variant: :icon) { '<svg></svg>'.html_safe }
          header.with_title { 'No results' }
          header.with_description { 'Try a different search.' }
        end
        empty.with_body { 'Clear filters' }
      end
    end

    test 'renders the root with the empty data-slot and token classes' do
      render_inline(Ui::EmptyComponent.new) { |empty| empty.with_header { |header| header.with_title { 'Nothing here' } } }

      assert_selector "div[data-slot='empty']"
      assert_includes classes_for('empty'), 'rounded-lg'
    end

    test 'renders every part with its data-slot' do
      render_full_empty

      PART_SLOTS.each { |slot| assert_selector "[data-slot='empty'] [data-slot='#{slot}']", count: 1 }
    end

    test 'renders header then body in the fixed anatomy order regardless of call order' do
      render_inline(Ui::EmptyComponent.new) do |empty|
        empty.with_body { 'Body' }
        empty.with_header { |header| header.with_title { 'Title' } }
      end

      order = page.all("[data-slot='empty'] > [data-slot]").map { |node| node['data-slot'] }
      assert_equal %w[empty-header empty-content], order
    end

    test 'nests media, title and description inside the header in that order' do
      render_full_empty

      order = page.all("[data-slot='empty-header'] > [data-slot]").map { |node| node['data-slot'] }
      assert_equal %w[empty-media empty-title empty-description], order
    end

    test 'renders the default media variant' do
      render_inline(Ui::EmptyComponent.new) do |empty|
        empty.with_header { |header| header.with_media { 'icon' } }
      end

      assert_includes classes_for('empty-media'), 'bg-transparent'
    end

    test 'renders the icon media variant' do
      render_inline(Ui::EmptyComponent.new) do |empty|
        empty.with_header { |header| header.with_media(variant: :icon) { '<svg></svg>'.html_safe } }
      end

      assert_includes classes_for('empty-media'), 'bg-muted'
      assert_includes classes_for('empty-media'), 'rounded-lg'
    end

    test 'an unknown media variant raises in development and test' do
      assert_raises(Ui::Base::UnknownVariantError) do
        render_inline(Ui::EmptyComponent.new) { |empty| empty.with_header { |header| header.with_media(variant: :photo) { 'x' } } }
      end
    end

    test 'omitted parts render no element' do
      render_inline(Ui::EmptyComponent.new) { |empty| empty.with_header { |header| header.with_title { 'Only title' } } }

      assert_selector "[data-slot='empty-title']", text: 'Only title'
      (PART_SLOTS - %w[empty-header empty-title]).each { |slot| assert_no_selector "[data-slot='#{slot}']" }
    end

    test 'caller class on the root wins over a conflicting default' do
      render_inline(Ui::EmptyComponent.new(class: 'rounded-none')) { |empty| empty.with_header { |header| header.with_title { 'Title' } } }

      assert_includes classes_for('empty'), 'rounded-none'
      assert_not_includes classes_for('empty'), 'rounded-lg'
    end

    test 'caller class on a part wins over a conflicting default' do
      render_inline(Ui::EmptyComponent.new) do |empty|
        empty.with_header { |header| header.with_title(class: 'text-xl') { 'Title' } }
        empty.with_body(class: 'gap-2') { 'Body' }
      end

      assert_includes classes_for('empty-title'), 'text-xl'
      assert_not_includes classes_for('empty-title'), 'text-lg'
      assert_includes classes_for('empty-content'), 'gap-2'
      assert_not_includes classes_for('empty-content'), 'gap-4'
    end

    test 'forwards html attributes to the root element' do
      render_inline(Ui::EmptyComponent.new(id: 'no-results', data: { testid: 'empty' })) do |empty|
        empty.with_header { |header| header.with_title { 'Title' } }
      end

      assert_selector "div#no-results[data-slot='empty'][data-testid='empty']"
    end

    test 'forwards html attributes to a part' do
      render_inline(Ui::EmptyComponent.new) do |empty|
        empty.with_header { |header| header.with_title(id: 'empty-heading') { 'Title' } }
        empty.with_body(data: { testid: 'actions' }) { 'Body' }
      end

      assert_selector "div#empty-heading[data-slot='empty-title']"
      assert_selector "div[data-slot='empty-content'][data-testid='actions']"
    end

    test 'nested parts compose from an erb template' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::EmptyComponent.new(id: "erb-empty") do |empty| %>
            <% empty.with_header do |header| %>
              <% header.with_media(variant: :icon) do %>
                <svg viewBox="0 0 24 24"></svg>
              <% end %>
              <% header.with_title { "No results" } %>
            <% end %>
            <% empty.with_body do %>
              <%= render(Ui::ButtonComponent.new) { "Clear filters" } %>
            <% end %>
          <% end %>
        ERB
      end

      assert_selector "#erb-empty > [data-slot='empty-header'] > [data-slot='empty-title']", text: 'No results'
      assert_selector "#erb-empty > [data-slot='empty-content'] > [data-slot='button']", text: 'Clear filters'
      assert_equal 1, page.all("[data-slot='empty-title']").size
    end
  end
end
