# frozen_string_literal: true

require 'test_helper'

module Ui
  class PopoverComponentTest < ViewComponent::TestCase
    test 'renders trigger and panel slots' do
      render_inline(Ui::PopoverComponent.new) do |popover|
        popover.with_trigger { '<button>Open</button>'.html_safe }
        popover.with_panel { '<p>Popover content</p>'.html_safe }
      end

      assert_selector "div[data-controller='ui--popover']"
      assert_selector "div[data-ui--popover-target='trigger'] button", text: 'Open'
      assert_selector "div[data-ui--popover-target='content'] p", text: 'Popover content'
    end

    test 'default placement is bottom' do
      render_inline(Ui::PopoverComponent.new) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      assert_selector "div[data-ui--popover-placement-value='bottom']"
    end

    test 'accepts valid placement' do
      render_inline(Ui::PopoverComponent.new(placement: 'top-start')) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      assert_selector "div[data-ui--popover-placement-value='top-start']"
    end

    test 'falls back to bottom for invalid placement' do
      render_inline(Ui::PopoverComponent.new(placement: 'invalid')) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      assert_selector "div[data-ui--popover-placement-value='bottom']"
    end

    test 'passes offset value' do
      render_inline(Ui::PopoverComponent.new(offset: 16)) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      assert_selector "div[data-ui--popover-offset-value='16']"
    end

    test 'trigger wrapper wires click to toggle' do
      render_inline(Ui::PopoverComponent.new) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      action = page.find("[data-ui--popover-target='trigger']")['data-action']
      assert_includes action, 'click->ui--popover#toggle'
    end

    test 'merges panel_classes onto content wrapper' do
      render_inline(Ui::PopoverComponent.new(panel_classes: 'w-64 p-4')) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      classes = page.find("[data-ui--popover-target='content']")['class']
      assert_includes classes, 'w-64'
      assert_includes classes, 'p-4'
    end
  end
end
