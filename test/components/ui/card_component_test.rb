# frozen_string_literal: true

require 'test_helper'

module Ui
  class CardComponentTest < ViewComponent::TestCase
    PART_SLOTS = %w[card-header card-title card-description card-action card-content card-footer].freeze

    def classes_for(slot)
      page.find("[data-slot='#{slot}']")['class'].split
    end

    def render_full_card
      render_inline(Ui::CardComponent.new) do |card|
        card.with_header do |header|
          header.with_title { 'Billing' }
          header.with_description { 'Manage your plan' }
          header.with_action { '<button>Edit</button>'.html_safe }
        end
        card.with_body { 'Body' }
        card.with_footer { 'Footer' }
      end
    end

    test 'renders the root with the card data-slot and token classes' do
      render_inline(Ui::CardComponent.new) { 'x' }

      assert_selector "div[data-slot='card']"
      assert_includes classes_for('card'), 'bg-card'
      assert_includes classes_for('card'), 'text-card-foreground'
      assert_includes classes_for('card'), 'border-border'
      assert_includes classes_for('card'), 'rounded-xl'
    end

    test 'renders every part with its data-slot' do
      render_full_card

      PART_SLOTS.each { |slot| assert_selector "[data-slot='card'] [data-slot='#{slot}']", count: 1 }
    end

    test 'renders parts in the fixed anatomy order regardless of call order' do
      render_inline(Ui::CardComponent.new) do |card|
        card.with_footer { 'Footer' }
        card.with_body { 'Body' }
        card.with_header { 'Header' }
      end

      order = page.all("[data-slot='card'] > [data-slot]").map { |node| node['data-slot'] }
      assert_equal %w[card-header card-content card-footer], order
    end

    test 'nests title, description and action inside the header' do
      render_full_card

      assert_selector "[data-slot='card-header'] > [data-slot='card-title']", text: 'Billing'
      assert_selector "[data-slot='card-header'] > [data-slot='card-description']", text: 'Manage your plan'
      assert_selector "[data-slot='card-header'] > [data-slot='card-action'] button", text: 'Edit'
    end

    test 'omitted parts render no element' do
      render_inline(Ui::CardComponent.new) { |card| card.with_body { 'Only body' } }

      assert_selector "[data-slot='card-content']", text: 'Only body'
      (PART_SLOTS - ['card-content']).each { |slot| assert_no_selector "[data-slot='#{slot}']" }
    end

    test 'omitted header parts render no element' do
      render_inline(Ui::CardComponent.new) { |card| card.with_header { |header| header.with_title { 'Title' } } }

      assert_selector "[data-slot='card-title']", text: 'Title'
      assert_no_selector "[data-slot='card-description']"
      assert_no_selector "[data-slot='card-action']"
    end

    test 'a bare block renders directly inside the card' do
      render_inline(Ui::CardComponent.new) { '<p>Anything</p>'.html_safe }

      assert_selector "[data-slot='card'] > p", text: 'Anything'
      assert_no_selector "[data-slot='card'] > [data-slot]"
    end

    test 'a block that only sets parts leaves no stray text in the card' do
      render_full_card

      root_text = page.find("[data-slot='card']").native.xpath('text()').map(&:text).join
      assert_equal '', root_text.strip
    end

    test 'header lays out a second column only when an action is present' do
      render_full_card

      assert_includes classes_for('card-header'), 'grid-cols-[1fr_auto]'
      assert_includes classes_for('card-action'), 'col-start-2'
    end

    test 'action centers on the title row instead of spanning the description' do
      render_full_card

      assert_includes classes_for('card-action'), 'row-start-1'
      assert_includes classes_for('card-action'), 'self-center'
      assert_includes classes_for('card-action'), 'h-0'
      assert_not_includes classes_for('card-action'), 'row-span-2'
    end

    test 'header without an action keeps a single column' do
      render_inline(Ui::CardComponent.new) do |card|
        card.with_header do |header|
          header.with_title { 'Billing' }
          header.with_description { 'Manage your plan' }
        end
      end

      assert_not_includes classes_for('card-header'), 'grid-cols-[1fr_auto]'
      assert_includes classes_for('card-header'), 'grid'
    end

    test 'caller class on the root wins over a conflicting default' do
      render_inline(Ui::CardComponent.new(class: 'rounded-none py-2')) { 'x' }

      assert_includes classes_for('card'), 'rounded-none'
      assert_includes classes_for('card'), 'py-2'
      assert_not_includes classes_for('card'), 'rounded-xl'
      assert_not_includes classes_for('card'), 'py-6'
    end

    test 'caller class on a part wins over a conflicting default' do
      render_inline(Ui::CardComponent.new) do |card|
        card.with_header { |header| header.with_description(class: 'text-foreground') { 'Desc' } }
        card.with_body(class: 'px-2') { 'Body' }
        card.with_footer(class: 'justify-end items-start') { 'Footer' }
      end

      assert_includes classes_for('card-content'), 'px-2'
      assert_not_includes classes_for('card-content'), 'px-6'
      assert_includes classes_for('card-description'), 'text-foreground'
      assert_not_includes classes_for('card-description'), 'text-muted-foreground'
      assert_includes classes_for('card-footer'), 'items-start'
      assert_includes classes_for('card-footer'), 'justify-end'
      assert_not_includes classes_for('card-footer'), 'items-center'
    end

    test 'forwards html attributes to the root element' do
      render_inline(Ui::CardComponent.new(id: 'billing', data: { testid: 'card' }, aria: { labelledby: 'billing-title' })) { 'x' }

      assert_selector "div#billing[data-slot='card'][data-testid='card'][aria-labelledby='billing-title']"
    end

    test 'forwards html attributes to a part' do
      render_inline(Ui::CardComponent.new) do |card|
        card.with_header { |header| header.with_title(id: 'billing-title', data: { testid: 'title' }) { 'Billing' } }
        card.with_footer(data: { controller: 'form-change' }) { 'Footer' }
      end

      assert_selector "div#billing-title[data-slot='card-title'][data-testid='title']"
      assert_selector "div[data-slot='card-footer'][data-controller='form-change']"
    end

    test 'nested parts compose from an erb template' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::CardComponent.new(id: "erb-card") do |card| %>
            <% card.with_header do |header| %>
              <% header.with_title { "Billing" } %>
              <% header.with_action do %>
                <%= render(Ui::ButtonComponent.new(variant: :ghost, size: :icon)) { "Edit" } %>
              <% end %>
            <% end %>
            <% card.with_body do %><p>Plan details</p><% end %>
            <% card.with_footer(class: "justify-end") { "Footer" } %>
          <% end %>
        ERB
      end

      assert_selector "#erb-card > [data-slot='card-header'] > [data-slot='card-title']", text: 'Billing'
      assert_selector "[data-slot='card-action'] > [data-slot='button']", text: 'Edit'
      assert_selector "#erb-card > [data-slot='card-content'] > p", text: 'Plan details'
      assert_selector "#erb-card > [data-slot='card-footer'].justify-end", text: 'Footer'
      assert_equal 1, page.all("[data-slot='card-title']").size
    end
  end
end
