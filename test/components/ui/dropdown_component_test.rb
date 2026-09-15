# frozen_string_literal: true

require 'test_helper'

module Ui
  class DropdownComponentTest < ViewComponent::TestCase
    test 'renders trigger and panel slots' do
      render_inline(Ui::DropdownComponent.new) do |dropdown|
        dropdown.with_trigger { '<button>Toggle</button>'.html_safe }
        dropdown.with_panel { "<a href='#'>Item</a>".html_safe }
      end

      assert_selector "div[data-controller~='ui--dropdown'][data-controller~='ui--anchor']"
      assert_selector "div[data-ui--dropdown-target='trigger'][data-ui--anchor-target='anchor'] button", text: 'Toggle'
      assert_selector "div[data-ui--dropdown-target='content'][data-ui--anchor-target='floating'] a", text: 'Item', visible: :all
    end

    test 'default kind is menu' do
      render_inline(Ui::DropdownComponent.new) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_panel { 'y' }
      end

      assert_selector "div[data-ui--dropdown-kind-value='menu']"
      # A menu's keyboard navigation is ui--roving-focus's.
      assert_selector "div[role='menu'][data-controller='ui--roving-focus']", visible: :all
    end

    # Behaves as Ui::DropdownComponent does outside development and test.
    class LenientDropdownComponent < Ui::DropdownComponent
      def self.raise_on_unknown_variant?
        false
      end
    end

    # kind: :listbox is gone (Ui::SelectComponent replaces it). Falling back silently rendered a
    # wrong-role menu, so an unknown kind is loud where it can be seen.
    test 'an unknown kind, including the removed :listbox, raises in development and test' do
      error = assert_raises(Ui::Base::UnknownVariantError) { Ui::DropdownComponent.new(kind: :listbox) }

      assert_includes error.message, 'kind: :listbox'
      assert_includes error.message, ':menu, :dialog'
    end

    test 'outside development and test an unknown kind logs and renders a menu' do
      log = StringIO.new
      original_logger = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(log)

      render_inline(LenientDropdownComponent.new(kind: :listbox)) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_panel { 'y' }
      end

      assert_selector "div[data-ui--dropdown-kind-value='menu']"
      assert_selector "div[role='menu']", visible: :all
      assert_match(/kind: :listbox/, log.string)
    ensure
      Rails.logger = original_logger
    end

    test 'kind and placement accept strings and symbols' do
      render_inline(Ui::DropdownComponent.new(kind: 'dialog', placement: :top_end)) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_panel { 'y' }
      end

      assert_selector "div[data-ui--dropdown-kind-value='dialog'][data-ui--anchor-placement-value='top-end']"
    end

    test 'an unknown placement raises in development and test' do
      assert_raises(Ui::Base::UnknownVariantError) { Ui::DropdownComponent.new(placement: 'below') }
    end

    # Opening, closing, light dismiss and the lifecycle events are ui--overlay's, in layer mode.
    test 'the panel is a ui--overlay layer, hidden until opened, and the trigger is its trigger' do
      render_inline(Ui::DropdownComponent.new) do |dropdown|
        dropdown.with_trigger { '<button>Toggle</button>'.html_safe }
        dropdown.with_panel { 'y' }
      end

      assert_selector "div[data-controller~='ui--overlay'][data-ui--overlay-mode-value='layer']" \
                      "[data-ui--overlay-move-focus-value='false'][data-ui--anchor-strategy-value='fixed']"
      assert_selector "div[data-ui--dropdown-target='trigger'][data-ui--overlay-target='trigger']"
      assert_selector "div[data-ui--overlay-target='content'][data-slot='dropdown-panel'][hidden]", visible: :all
      refute_includes page.find("[data-slot='dropdown-panel']", visible: :all)[:class].split, 'z-50'
      assert_nil page.find("[data-ui--dropdown-target='trigger']")['data-action']
    end

    test 'the root carries data-slot, a caller class and forwarded data without losing its controllers' do
      render_inline(Ui::DropdownComponent.new(class: 'inline-block', data: { action: 'ui--overlay:opened->host#track' })) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_panel { 'y' }
      end

      root = page.find("div[data-slot='dropdown']")
      assert_selector "[data-slot='dropdown-trigger'] + [data-slot='dropdown-panel']", visible: :all
      assert_equal 'inline-block', root[:class]
      assert_equal 'ui--overlay:opened->host#track', root['data-action']
      assert_equal %w[ui--dropdown ui--overlay ui--anchor], root['data-controller'].split
    end

    test 'with_panel(class:) merges over the panel defaults' do
      render_inline(Ui::DropdownComponent.new) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_panel(class: 'bg-muted rounded-none') { 'y' }
      end

      classes = page.find("[data-slot='dropdown-panel']", visible: :all)[:class].split
      assert_includes classes, 'bg-muted'
      refute_includes classes, 'bg-popover'
      refute_includes classes, 'rounded-md'
    end

    test 'content_classes is deprecated, and merges rather than racing the defaults' do
      assert_deprecated(/content_classes: is deprecated; pass with_panel\(class: \.\.\.\)/, RailsUiKit.deprecator) do
        render_inline(Ui::DropdownComponent.new(content_classes: 'bg-muted w-64')) do |dropdown|
          dropdown.with_trigger { 'x' }
          dropdown.with_panel { 'y' }
        end
      end

      classes = page.find("[data-slot='dropdown-panel']", visible: :all)[:class].split
      assert_includes classes, 'bg-muted'
      assert_includes classes, 'w-64'
      refute_includes classes, 'bg-popover'
    end

    test 'with_menu is a deprecated alias of with_panel' do
      assert_deprecated(/with_menu is deprecated; call with_panel/, RailsUiKit.deprecator) do
        render_inline(Ui::DropdownComponent.new) do |dropdown|
          dropdown.with_trigger { 'x' }
          dropdown.with_menu(class: 'w-64') { "<a href='#'>Item</a>".html_safe }
        end
      end

      assert_selector "[data-slot='dropdown-panel'].w-64 a", text: 'Item', visible: :all
    end

    test 'passes placement and offset values' do
      render_inline(Ui::DropdownComponent.new(placement: 'top-end', offset: 8)) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_panel { 'y' }
      end

      # Geometry is ui--anchor's, so placement and offset are its values.
      assert_selector "div[data-ui--anchor-placement-value='top-end']"
      assert_selector "div[data-ui--anchor-offset-value='8']"
    end

    test 'label names the content' do
      render_inline(Ui::DropdownComponent.new(kind: :dialog, label: 'Filter results')) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_panel { 'y' }
      end

      assert_selector "div[role='dialog'][aria-label='Filter results']", visible: :all
    end

    test 'content has no aria-label without a label' do
      render_inline(Ui::DropdownComponent.new) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_panel { 'y' }
      end

      assert_no_selector '[aria-label]', visible: :all
    end
  end
end
