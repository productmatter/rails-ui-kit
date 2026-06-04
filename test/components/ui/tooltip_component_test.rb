# frozen_string_literal: true

require 'test_helper'

module Ui
  class TooltipComponentTest < ViewComponent::TestCase
    test 'renders trigger and tooltip text' do
      render_inline(Ui::TooltipComponent.new(text: 'Save changes')) do |tooltip|
        tooltip.with_trigger { '<button>Save</button>'.html_safe }
      end

      assert_selector "div[data-controller='ui--tooltip']"
      assert_selector "div[data-ui--tooltip-target='trigger'] button", text: 'Save'
      assert_selector "div[data-ui--tooltip-target='content']", text: 'Save changes'
    end

    test 'default placement is top' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip')) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      assert_selector "div[data-ui--tooltip-placement-value='top']"
    end

    test 'accepts valid placement' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip', placement: 'bottom-end')) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      assert_selector "div[data-ui--tooltip-placement-value='bottom-end']"
    end

    test 'falls back to top for invalid placement' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip', placement: 'invalid')) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      assert_selector "div[data-ui--tooltip-placement-value='top']"
    end

    test 'passes offset value' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip', offset: 12)) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      assert_selector "div[data-ui--tooltip-offset-value='12']"
    end

    test 'wires hover and focus actions' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip')) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      action = page.find("[data-controller='ui--tooltip']")['data-action']
      assert_includes action, 'mouseenter->ui--tooltip#show'
      assert_includes action, 'mouseleave->ui--tooltip#hide'
      assert_includes action, 'focusin->ui--tooltip#show'
      assert_includes action, 'focusout->ui--tooltip#hide'
    end

    test 'tooltip content has pointer-events-none' do
      render_inline(Ui::TooltipComponent.new(text: 'Tip')) do |tooltip|
        tooltip.with_trigger { 'x' }
      end

      classes = page.find("[data-ui--tooltip-target='content']")['class']
      assert_includes classes, 'pointer-events-none'
    end
  end
end
