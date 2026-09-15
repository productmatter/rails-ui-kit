# frozen_string_literal: true

require 'test_helper'

module Ui
  class TooltipComponentTest < ViewComponent::TestCase
    test 'renders trigger and tooltip text' do
      render_inline(Ui::TooltipComponent.new(text: 'Save changes')) do |tooltip|
        tooltip.with_trigger { '<button>Save</button>'.html_safe }
      end

      assert_selector "div[data-controller~='ui--tooltip'][data-controller~='ui--overlay'][data-controller~='ui--anchor']"
      assert_selector "div[data-ui--tooltip-target='trigger'][data-ui--anchor-target='anchor'] button", text: 'Save'
      assert_selector "div[data-ui--tooltip-target='content'][data-ui--overlay-target='content']",
                      text: 'Save changes', visible: :all
    end

    test 'default placement is top' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip')) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      assert_selector "div[data-ui--anchor-placement-value='top']"
    end

    test 'accepts valid placement' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip', placement: 'bottom-end')) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      assert_selector "div[data-ui--anchor-placement-value='bottom-end']"
    end

    # Behaves as Ui::TooltipComponent does outside development and test.
    class LenientTooltipComponent < Ui::TooltipComponent
      def self.raise_on_unknown_variant?
        false
      end
    end

    test 'an unknown placement raises in development and test' do
      error = assert_raises(Ui::Base::UnknownVariantError) { Ui::TooltipComponent.new(text: 'Tip', placement: 'invalid') }

      assert_includes error.message, 'placement: "invalid"'
    end

    test 'outside development and test an unknown placement logs and falls back to top' do
      log = StringIO.new
      original_logger = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(log)

      render_inline(LenientTooltipComponent.new(text: 'Tip', placement: 'invalid')) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      assert_selector "div[data-ui--anchor-placement-value='top']"
      assert_match(/placement: "invalid"/, log.string)
    ensure
      Rails.logger = original_logger
    end

    test 'a placement given as a symbol resolves' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip', placement: :bottom_end)) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      assert_selector "div[data-ui--anchor-placement-value='bottom-end']"
    end

    test 'the root carries data-slot, a caller class and forwarded aria and data' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip', class: 'inline-flex', data: { testid: 't' })) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      root = page.find("div[data-slot='tooltip']")
      assert_selector "[data-slot='tooltip-trigger'] + [data-slot='tooltip-content'] > [data-slot='tooltip-arrow']", visible: :all
      assert_equal 'inline-flex', root[:class]
      assert_equal 't', root['data-testid']
      assert_equal %w[ui--tooltip ui--overlay ui--anchor], root['data-controller'].split
    end

    test 'the tooltip and its arrow take their colour from the tokens, inverted' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip')) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      content = page.find("[data-ui--tooltip-target='content']", visible: :all)
      assert_includes content[:class].split, 'bg-foreground'
      assert_includes content[:class].split, 'text-background'
      assert_includes content.find("[data-ui--anchor-target='arrow']", visible: :all)[:class].split, 'bg-foreground'
    end

    test 'passes offset value' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip', offset: 12)) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      assert_selector "div[data-ui--anchor-offset-value='12']"
    end

    # A hint in the browser's top layer, positioned by ui--anchor, with its own arrow.
    test 'the tooltip is an overlay hint and the anchor\'s floating element' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip')) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      assert_selector "div[data-ui--overlay-mode-value='hint']"
      assert_selector "div[data-ui--anchor-strategy-value='fixed']"
      assert_selector "[data-ui--tooltip-target='content'][data-ui--anchor-target='floating'][hidden]", visible: :all
      assert_selector "[data-ui--anchor-target='arrow']", visible: :all
    end

    test 'tooltip content accepts pointer events so the pointer can move onto it' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip')) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      classes = page.find("[data-ui--tooltip-target='content']", visible: :all)['class']
      refute_includes classes, 'pointer-events-none'
    end
  end
end
