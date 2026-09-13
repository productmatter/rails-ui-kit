# frozen_string_literal: true

require 'test_helper'

module Ui
  class KbdComponentTest < ViewComponent::TestCase
    def kbd_classes
      page.find('[data-slot=kbd]')['class'].split
    end

    test 'renders a kbd element' do
      render_inline(Ui::KbdComponent.new) { 'K' }

      assert_selector "kbd[data-slot='kbd']", text: 'K'
    end

    test 'renders shared base classes' do
      render_inline(Ui::KbdComponent.new) { 'K' }

      assert_includes kbd_classes, 'bg-muted'
      assert_includes kbd_classes, 'text-muted-foreground'
      assert_includes kbd_classes, 'rounded-sm'
    end

    test 'caller class wins over a conflicting default' do
      render_inline(Ui::KbdComponent.new(class: 'bg-primary')) { 'K' }

      assert_includes kbd_classes, 'bg-primary'
      assert_not_includes kbd_classes, 'bg-muted'
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(Ui::KbdComponent.new(id: 'save-key', data: { testid: 'kbd' })) { 'S' }

      assert_selector "kbd#save-key[data-slot='kbd'][data-testid='kbd']"
    end

    test 'forwards data and aria attributes to the root element' do
      render_inline(Ui::KbdComponent.new(aria: { hidden: 'true' })) { 'K' }

      assert_selector "kbd[data-slot='kbd'][aria-hidden='true']"
    end

    test 'group renders each key in call order under a kbd-group data-slot' do
      render_inline(Ui::Kbd::GroupComponent.new) do |group|
        group.with_key { '⌘' }
        group.with_key { 'K' }
      end

      assert_selector "[data-slot='kbd-group'] > [data-slot='kbd']", count: 2
      keys = page.all("[data-slot='kbd-group'] > [data-slot='kbd']").map(&:text)
      assert_equal %w[⌘ K], keys
    end

    test 'group keys stay in call order whatever order the caller sets them in' do
      render_inline(Ui::Kbd::GroupComponent.new) do |group|
        group.with_key { 'K' }
        group.with_key { '⌘' }
      end

      keys = page.all("[data-slot='kbd-group'] > [data-slot='kbd']").map(&:text)
      assert_equal %w[K ⌘], keys
    end

    test 'group caller class wins over its conflicting default' do
      render_inline(Ui::Kbd::GroupComponent.new(class: 'gap-2')) { |group| group.with_key { 'K' } }

      assert_includes page.find('[data-slot=kbd-group]')['class'].split, 'gap-2'
      assert_not_includes page.find('[data-slot=kbd-group]')['class'].split, 'gap-1'
    end

    test 'group forwards html attributes to its root element' do
      render_inline(Ui::Kbd::GroupComponent.new(id: 'open-command', data: { testid: 'chord' })) do |group|
        group.with_key { '⌘' }
        group.with_key { 'K' }
      end

      assert_selector "#open-command[data-slot='kbd-group'][data-testid='chord']"
    end

    test 'group nests parts from an erb template' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::Kbd::GroupComponent.new(id: "chord") do |group| %>
            <% group.with_key { "⌘" } %>
            <% group.with_key { "K" } %>
          <% end %>
        ERB
      end

      assert_selector "#chord > [data-slot='kbd'] + [data-slot='kbd']"
      keys = page.all("#chord [data-slot='kbd']").map(&:text)
      assert_equal %w[⌘ K], keys
    end
  end
end
