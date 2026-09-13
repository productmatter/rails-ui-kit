# frozen_string_literal: true

require 'test_helper'

module Ui
  class PaginationComponentTest < ViewComponent::TestCase
    def render_full_pagination
      render_inline(Ui::PaginationComponent.new) do |pagination|
        pagination.with_link(href: '#prev', aria: { label: 'Go to previous page' }) { '‹' }
        pagination.with_link(href: '#1') { '1' }
        pagination.with_link(href: '#2', active: true) { '2' }
        pagination.with_ellipsis
        pagination.with_link(href: '#10') { '10' }
        pagination.with_link(href: '#next', aria: { label: 'Go to next page' }) { '›' }
      end
    end

    test 'renders a nav with the pagination data-slot, labelled and holding a ul' do
      render_inline(Ui::PaginationComponent.new) { |pagination| pagination.with_link(href: '#1') { '1' } }

      assert_selector "nav[data-slot='pagination'][aria-label='pagination'] > ul"
    end

    test 'renders every item type with its data-slot' do
      render_full_pagination

      assert_selector "[data-slot='pagination'] [data-slot='pagination-link']", count: 5
      assert_selector "[data-slot='pagination'] [data-slot='pagination-ellipsis']", count: 1
    end

    test 'a link renders through Ui::ButtonComponent, never a private copy of its class table' do
      render_inline(Ui::PaginationComponent.new) { |pagination| pagination.with_link(href: '#1') { '1' } }

      assert_selector "[data-slot='pagination-link'] > a[data-slot='button']"
    end

    test 'items render in call order' do
      render_full_pagination

      items = page.all('ul > li').map { |li| li.text.strip }
      assert_equal %w[‹ 1 2 … 10 ›], items
    end

    test 'a non-active link is ghost and carries no aria-current' do
      render_inline(Ui::PaginationComponent.new) { |pagination| pagination.with_link(href: '#1') { '1' } }

      link = page.find("[data-slot='pagination-link'] [data-slot='button']")
      assert_nil link['aria-current']
      assert_not_includes link['class'].split, 'border-input'
    end

    test 'the active link carries aria-current="page" and the outline variant' do
      render_inline(Ui::PaginationComponent.new) { |pagination| pagination.with_link(href: '#2', active: true) { '2' } }

      link = page.find("[data-slot='pagination-link'] [data-slot='button']")
      assert_equal 'page', link['aria-current']
      assert_includes link['class'].split, 'border-input'
    end

    test 'previous and next carry their own accessible names' do
      render_full_pagination

      assert_selector "[data-slot='button'][aria-label='Go to previous page']", text: '‹'
      assert_selector "[data-slot='button'][aria-label='Go to next page']", text: '›'
    end

    test 'the ellipsis is decorative' do
      render_full_pagination

      assert_selector "[data-slot='pagination-ellipsis'][aria-hidden='true']"
    end

    test 'caller class on a link styles its own li, not the nested button' do
      render_inline(Ui::PaginationComponent.new) { |pagination| pagination.with_link(href: '#1', class: 'mx-1') { '1' } }

      li = page.find("[data-slot='pagination-link']")
      assert_includes li['class'].split, 'mx-1'
      assert_not_includes li.find("[data-slot='button']")['class'].split, 'mx-1'
    end

    test 'forwards html attributes to the nested button' do
      render_inline(Ui::PaginationComponent.new) { |pagination| pagination.with_link(href: '#1', id: 'page-1', data: { testid: 'page-1' }) { '1' } }

      assert_selector "a#page-1[data-slot='button'][href='#1'][data-testid='page-1']"
    end

    test 'forwards html attributes to the root nav' do
      render_inline(Ui::PaginationComponent.new(id: 'results-pagination')) { |pagination| pagination.with_link(href: '#1') { '1' } }

      assert_selector "nav#results-pagination[data-slot='pagination']"
    end

    test 'nested parts compose from an erb template' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::PaginationComponent.new(id: "erb-pagination") do |pagination| %>
            <% pagination.with_link(href: "#1") { "1" } %>
            <% pagination.with_link(href: "#2", active: true) { "2" } %>
            <% pagination.with_ellipsis %>
          <% end %>
        ERB
      end

      assert_selector "#erb-pagination [data-slot='pagination-link']", count: 2
      assert_selector "#erb-pagination [data-slot='button'][aria-current='page']", text: '2'
      assert_equal 1, page.all("[data-slot='pagination-ellipsis']").size
    end
  end
end
