# frozen_string_literal: true

require 'test_helper'

module Ui
  class DropdownComponentTest < ViewComponent::TestCase
    test 'renders trigger and menu slots' do
      render_inline(Ui::DropdownComponent.new) do |dropdown|
        dropdown.with_trigger { '<button>Toggle</button>'.html_safe }
        dropdown.with_menu { "<a href='#'>Item</a>".html_safe }
      end

      assert_selector "div[data-controller~='ui--dropdown'][data-controller~='ui--anchor']"
      assert_selector "div[data-ui--dropdown-target='trigger'][data-ui--anchor-target='anchor'] button", text: 'Toggle'
      assert_selector "div[data-ui--dropdown-target='content'][data-ui--anchor-target='floating'] a", text: 'Item', visible: :all
    end

    test 'default kind is menu' do
      render_inline(Ui::DropdownComponent.new) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_menu { 'y' }
      end

      assert_selector "div[data-ui--dropdown-kind-value='menu']"
      # A menu's keyboard navigation is ui--roving-focus's.
      assert_selector "div[role='menu'][data-controller='ui--roving-focus']", visible: :all
    end

    # kind: :listbox is gone (Ui::SelectComponent replaces it). Any kind KINDS doesn't
    # recognise, including the removed one, falls back to :menu rather than raising.
    test 'an unknown kind, including :listbox, falls back to menu' do
      render_inline(Ui::DropdownComponent.new(kind: :listbox)) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_menu { 'y' }
      end

      assert_selector "div[data-ui--dropdown-kind-value='menu']"
      assert_selector "div[role='menu']", visible: :all
    end

    test 'passes placement and offset values' do
      render_inline(Ui::DropdownComponent.new(placement: 'top-end', offset: 8)) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_menu { 'y' }
      end

      # Geometry is ui--anchor's, so placement and offset are its values.
      assert_selector "div[data-ui--anchor-placement-value='top-end']"
      assert_selector "div[data-ui--anchor-offset-value='8']"
    end

    test 'label names the content' do
      render_inline(Ui::DropdownComponent.new(kind: :dialog, label: 'Filter results')) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_menu { 'y' }
      end

      assert_selector "div[role='dialog'][aria-label='Filter results']", visible: :all
    end

    test 'content has no aria-label without a label' do
      render_inline(Ui::DropdownComponent.new) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_menu { 'y' }
      end

      assert_no_selector '[aria-label]', visible: :all
    end
  end
end
