# frozen_string_literal: true

require 'test_helper'

module Ui
  class BreadcrumbComponentTest < ViewComponent::TestCase
    def classes_for(slot)
      page.find("[data-slot='#{slot}']", match: :first)['class'].split
    end

    # Separator and ellipsis carry their own data-slot on the <li>; link and page
    # carry it on the <a>/<span> the <li> wraps. Either way, this is the one
    # data-slot that identifies the item.
    def item_slot(item)
      item['data-slot'] || item.find('[data-slot]')['data-slot']
    end

    def render_full_breadcrumb
      render_inline(Ui::BreadcrumbComponent.new) do |breadcrumb|
        breadcrumb.with_link(href: '/') { 'Home' }
        breadcrumb.with_ellipsis
        breadcrumb.with_link(href: '/components') { 'Components' }
        breadcrumb.with_page { 'Breadcrumb' }
      end
    end

    test 'renders a nav with the breadcrumb data-slot, labelled and holding an ol' do
      render_inline(Ui::BreadcrumbComponent.new) { |breadcrumb| breadcrumb.with_page { 'Home' } }

      assert_selector "nav[data-slot='breadcrumb'][aria-label='breadcrumb'] > ol"
    end

    test 'renders every item type with its data-slot' do
      render_full_breadcrumb

      assert_selector "[data-slot='breadcrumb'] [data-slot='breadcrumb-link']", count: 2
      assert_selector "[data-slot='breadcrumb'] [data-slot='breadcrumb-ellipsis']", count: 1
      assert_selector "[data-slot='breadcrumb'] [data-slot='breadcrumb-page']", count: 1
    end

    test 'items render in call order' do
      render_full_breadcrumb

      items = page.all('ol > li').reject { |item| item_slot(item) == 'breadcrumb-separator' }.map { |item| item.text.strip }
      assert_equal ['Home', '…', 'Components', 'Breadcrumb'], items
    end

    test 'draws a separator between every pair of items, never a duplicate or a missing one' do
      render_full_breadcrumb

      assert_selector "[data-slot='breadcrumb-separator']", count: 3
    end

    test 'a caller cannot render its own separator -- the component draws it' do
      render_inline(Ui::BreadcrumbComponent.new) do |breadcrumb|
        breadcrumb.with_link(href: '/') { 'Home' }
        breadcrumb.with_page { 'Current' }
      end

      assert_equal(%w[breadcrumb-link breadcrumb-separator breadcrumb-page], page.all('ol > li').map { |item| item_slot(item) })
    end

    test 'a single item renders with no separator' do
      render_inline(Ui::BreadcrumbComponent.new) { |breadcrumb| breadcrumb.with_page { 'Home' } }

      assert_no_selector "[data-slot='breadcrumb-separator']"
    end

    test 'separators are hidden from assistive tech' do
      render_full_breadcrumb

      page.all("[data-slot='breadcrumb-separator']").each do |separator|
        assert_equal 'true', separator['aria-hidden']
        assert_equal 'presentation', separator['role']
      end
    end

    test 'the current page carries aria-current="page"' do
      render_full_breadcrumb

      assert_selector "[data-slot='breadcrumb-page'][aria-current='page']", text: 'Breadcrumb'
    end

    test 'a link is not the current page and carries no aria-current' do
      render_full_breadcrumb

      page.all("[data-slot='breadcrumb-link']").each { |link| assert_nil link['aria-current'] }
    end

    test 'a collapsed ellipsis has an accessible name' do
      render_full_breadcrumb

      assert_selector "[data-slot='breadcrumb-ellipsis'][aria-label='More']"
    end

    test 'a caller can override the ellipsis accessible name' do
      render_inline(Ui::BreadcrumbComponent.new) do |breadcrumb|
        breadcrumb.with_ellipsis(aria: { label: '3 hidden pages' })
        breadcrumb.with_page { 'Current' }
      end

      assert_selector "[data-slot='breadcrumb-ellipsis'][aria-label='3 hidden pages']"
    end

    test 'caller class on a link wins over a conflicting default' do
      render_inline(Ui::BreadcrumbComponent.new) { |breadcrumb| breadcrumb.with_link(href: '/', class: 'text-primary') { 'Home' } }

      assert_includes classes_for('breadcrumb-link'), 'text-primary'
    end

    test 'forwards html attributes to a link' do
      render_inline(Ui::BreadcrumbComponent.new) do |breadcrumb|
        breadcrumb.with_link(href: '/', id: 'home-crumb', data: { testid: 'home' }) { 'Home' }
      end

      assert_selector "a#home-crumb[data-slot='breadcrumb-link'][href='/'][data-testid='home']"
    end

    test 'forwards html attributes to the root nav' do
      render_inline(Ui::BreadcrumbComponent.new(id: 'checkout-crumbs')) { |breadcrumb| breadcrumb.with_page { 'Home' } }

      assert_selector "nav#checkout-crumbs[data-slot='breadcrumb']"
    end

    test 'nested parts compose from an erb template' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::BreadcrumbComponent.new(id: "erb-breadcrumb") do |breadcrumb| %>
            <% breadcrumb.with_link(href: "/") { "Home" } %>
            <% breadcrumb.with_link(href: "/components") { "Components" } %>
            <% breadcrumb.with_page { "Breadcrumb" } %>
          <% end %>
        ERB
      end

      assert_selector "#erb-breadcrumb [data-slot='breadcrumb-link']", count: 2
      assert_selector "#erb-breadcrumb [data-slot='breadcrumb-page']", text: 'Breadcrumb'
      assert_equal 1, page.all("[data-slot='breadcrumb-page']").size
    end
  end
end
