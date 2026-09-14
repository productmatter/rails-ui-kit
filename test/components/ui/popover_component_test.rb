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

    test 'falls back to bottom for invalid placement' do
      render_inline(Ui::PopoverComponent.new(placement: 'invalid')) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      assert_selector "div[data-ui--anchor-placement-value='bottom']"
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
      render_inline(Ui::PopoverComponent.new(panel_classes: 'w-64 p-4')) do |popover|
        popover.with_trigger { 'x' }
        popover.with_panel { 'y' }
      end

      classes = page.find("[data-ui--popover-target='content']", visible: :all)['class']
      assert_includes classes, 'w-64'
      assert_includes classes, 'p-4'
    end
  end
end
