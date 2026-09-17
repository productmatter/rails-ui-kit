# frozen_string_literal: true

require 'test_helper'

module Ui
  class PopoverComponentTest < ViewComponent::TestCase
    test 'renders trigger and panel slots' do
      render_inline(Ui::PopoverComponent.new) do |popover|
        popover.with_trigger { '<button>Open</button>'.html_safe }
        popover.with_panel { '<p>Popover content</p>'.html_safe }
      end

      assert_selector "div[data-controller~='ui--popover'][data-controller~='ui--overlay'][data-controller~='ui--anchor']"
      assert_selector "div[data-ui--popover-target='trigger'][data-ui--overlay-target='trigger'] button", text: 'Open'
      assert_selector "div[data-ui--popover-target='content'][data-ui--overlay-target='content'] p",
                      text: 'Popover content', visible: :all
    end

    # The panel is a layer in the browser's top layer, positioned by ui--anchor.
    test 'the panel is an overlay layer and the anchor\'s floating element' do
      render_inline(Ui::PopoverComponent.new) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      assert_selector "div[data-ui--overlay-mode-value='layer']"
      assert_selector "div[data-ui--anchor-strategy-value='fixed']"
      assert_selector "[data-ui--popover-target='content'][data-ui--anchor-target='floating'][hidden]", visible: :all
    end

    test 'default placement is bottom' do
      render_inline(Ui::PopoverComponent.new) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      assert_selector "div[data-ui--anchor-placement-value='bottom']"
    end

    test 'accepts valid placement' do
      render_inline(Ui::PopoverComponent.new(placement: 'top-start')) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      assert_selector "div[data-ui--anchor-placement-value='top-start']"
    end

    # Behaves as Ui::PopoverComponent does outside development and test.
    class LenientPopoverComponent < Ui::PopoverComponent
      def self.raise_on_unknown_variant?
        false
      end
    end

    test 'an unknown placement raises in development and test, naming the placements' do
      error = assert_raises(Ui::Base::UnknownVariantError) { Ui::PopoverComponent.new(placement: 'invalid') }

      assert_includes error.message, 'placement: "invalid"'
      assert_includes error.message, '"right-end"'
    end

    test 'outside development and test an unknown placement logs and falls back to bottom' do
      log = StringIO.new
      original_logger = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(log)

      render_inline(LenientPopoverComponent.new(placement: 'invalid')) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      assert_selector "div[data-ui--anchor-placement-value='bottom']"
      assert_match(/placement: "invalid"/, log.string)
    ensure
      Rails.logger = original_logger
    end

    # placement: :top beside size: :sm used to be silently ignored.
    test 'a placement given as a symbol, with underscores for hyphens, resolves' do
      { top: 'top', bottom_start: 'bottom-start', 'left-end': 'left-end' }.each do |given, rendered|
        render_inline(Ui::PopoverComponent.new(placement: given)) do |popover|
          popover.with_trigger { 'x' }
          popover.with_panel { 'y' }
        end

        assert_selector "div[data-ui--anchor-placement-value='#{rendered}']"
      end
    end

    test 'the root carries data-slot, a caller class and forwarded data without losing its controllers' do
      render_inline(Ui::PopoverComponent.new(class: 'inline-block', data: { controller: 'host', testid: 'p' })) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      root = page.find("div[data-slot='popover']")
      assert_selector "[data-slot='popover-trigger'] + [data-slot='popover-panel']", visible: :all
      assert_equal 'inline-block', root[:class]
      assert_equal 'p', root['data-testid']
      assert_equal %w[ui--popover ui--overlay ui--anchor host], root['data-controller'].split
    end

    test 'with_panel(class:) merges over the panel defaults, so a token colour replaces the default' do
      render_inline(Ui::PopoverComponent.new) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel(class: 'w-64 bg-muted rounded-none') { 'y' }
      end

      classes = page.find("[data-slot='popover-panel']", visible: :all)[:class].split
      assert_includes classes, 'w-64'
      assert_includes classes, 'bg-muted'
      refute_includes classes, 'bg-popover'
      refute_includes classes, 'rounded-lg'
    end

    # Guessed at, it would have rendered as a `panel_class="w-64"` attribute and styled nothing.
    test 'a class keyword Popover does not declare raises instead of rendering as an attribute' do
      error = assert_raises(ArgumentError) { Ui::PopoverComponent.new(panel_class: 'w-64') }

      assert_includes error.message, 'Ui::PopoverComponent has no panel_class: keyword'
    end

    test 'with_panel accepts only class' do
      assert_raises(ArgumentError) do
        render_inline(Ui::PopoverComponent.new) { |popover| popover.with_panel(id: 'x') { 'y' } }
      end
    end

    test 'passes offset value' do
      render_inline(Ui::PopoverComponent.new(offset: 16)) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      assert_selector "div[data-ui--anchor-offset-value='16']"
    end

    # The controller binds the click to the focusable control inside the trigger slot, so
    # clicking empty wrapper space beside the button doesn't toggle the panel.
    test 'trigger wrapper does not wire click itself' do
      render_inline(Ui::PopoverComponent.new) do |popover|
        popover.with_trigger { '<button>Open</button>'.html_safe }
        popover.with_panel { 'y' }
      end

      assert_nil page.find("[data-ui--popover-target='trigger']")['data-action']
    end

    test 'merges panel_classes onto content wrapper' do
      assert_deprecated(/panel_classes: is deprecated; pass with_panel\(class: \.\.\.\)/, RailsUiKit.deprecator) do
        render_inline(Ui::PopoverComponent.new(panel_classes: 'w-64 p-4')) do |popover|
          popover.with_trigger { 'x' }
          popover.with_panel { 'y' }
        end
      end

      classes = page.find("[data-ui--popover-target='content']", visible: :all)['class']
      assert_includes classes, 'w-64'
      assert_includes classes, 'p-4'
    end

    # Replace-not-merge let `panel_classes: "bg-muted"` race the default background in stylesheet order.
    test 'panel_classes merges, so its colour replaces the default rather than racing it' do
      assert_deprecated(RailsUiKit.deprecator) do
        render_inline(Ui::PopoverComponent.new(panel_classes: 'bg-muted')) do |popover|
          popover.with_trigger { 'x' }
          popover.with_panel(class: 'bg-accent') { 'y' }
        end
      end

      classes = page.find("[data-ui--popover-target='content']", visible: :all)['class'].split
      assert_includes classes, 'bg-accent'
      refute_includes classes, 'bg-muted'
      refute_includes classes, 'bg-popover'
    end
  end
end
