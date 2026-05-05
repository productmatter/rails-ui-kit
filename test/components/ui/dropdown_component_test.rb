# frozen_string_literal: true

require 'test_helper'

module Ui
  class DropdownComponentTest < ViewComponent::TestCase
    test 'renders trigger and menu slots' do
      render_inline(Ui::DropdownComponent.new) do |dropdown|
        dropdown.with_trigger { '<button>Toggle</button>'.html_safe }
        dropdown.with_menu { "<a href='#'>Item</a>".html_safe }
      end

      assert_selector "div[data-controller='ui--dropdown']"
      assert_selector "div[data-ui--dropdown-target='trigger'] button", text: 'Toggle'
      assert_selector "div[data-ui--dropdown-target='content'] a", text: 'Item'
    end

    test 'default kind is menu' do
      render_inline(Ui::DropdownComponent.new) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_menu { 'y' }
      end

      assert_selector "div[data-ui--dropdown-kind-value='menu']"
      assert_selector "div[role='menu']"
    end

    test 'kind: :listbox sets aria role on content' do
      render_inline(Ui::DropdownComponent.new(kind: :listbox)) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_menu { 'y' }
      end

      assert_selector "div[role='listbox']"
    end

    test 'passes placement and offset values' do
      render_inline(Ui::DropdownComponent.new(placement: 'top-end', offset: 8)) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_menu { 'y' }
      end

      assert_selector "div[data-ui--dropdown-placement-value='top-end']"
      assert_selector "div[data-ui--dropdown-offset-value='8']"
    end
  end
end
