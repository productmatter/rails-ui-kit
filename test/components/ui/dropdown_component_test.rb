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

    # Deprecated, not removed: it shipped, so it has to keep working while it says what to move
    # to (ui-select § Behavior, item 36).
    test 'kind: :listbox still renders, and warns exactly once per process' do
      Ui::DropdownComponent.listbox_deprecation_warned = false

      first = capture_stderr { render_listbox }
      assert_selector "div[role='listbox']", visible: :all
      assert_includes first, 'Ui::SelectComponent'
      assert_includes first, 'deprecated'

      second = capture_stderr { render_listbox }
      assert_selector "div[role='listbox']", visible: :all
      assert_empty second, 'the deprecation warned more than once'
    ensure
      Ui::DropdownComponent.listbox_deprecation_warned = false
    end

    test 'the other kinds never warn' do
      Ui::DropdownComponent.listbox_deprecation_warned = false

      output = capture_stderr do
        %i[menu dialog].each do |kind|
          render_inline(Ui::DropdownComponent.new(kind: kind)) do |dropdown|
            dropdown.with_trigger { 'x' }
            dropdown.with_menu { 'y' }
          end
        end
      end

      assert_empty output
    end

    test 'kind: :listbox sets aria role on content' do
      Ui::DropdownComponent.listbox_deprecation_warned = true
      render_inline(Ui::DropdownComponent.new(kind: :listbox)) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_menu { 'y' }
      end

      assert_selector "div[role='listbox']", visible: :all
      assert_no_selector "div[role='listbox'][data-controller]", visible: :all
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
    def render_listbox
      render_inline(Ui::DropdownComponent.new(kind: :listbox)) do |dropdown|
        dropdown.with_trigger { 'x' }
        dropdown.with_menu { 'y' }
      end
    end

    def capture_stderr
      original = $stderr
      $stderr = StringIO.new
      yield
      $stderr.string
    ensure
      $stderr = original
    end
  end
end
