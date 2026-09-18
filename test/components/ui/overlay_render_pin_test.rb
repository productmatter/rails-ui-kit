# frozen_string_literal: true

require 'test_helper'

# Render pins for the four overlay components, written against their output before they move onto
# Ui::Base and the tokens (ui-foundation-retrofit). Each pin asserts what the retrofit must carry
# through unchanged: the element structure, the Stimulus wiring, the ARIA and the classes that are
# not palette literals. Classes the retrofit removes on purpose are listed beside each pin and
# deliberately not asserted. A pin is never edited to make the retrofit pass.
module Ui
  class OverlayRenderPinTest < ViewComponent::TestCase
    # Expected to change: `backdrop:bg-black/50` (the scrim, a literal the token rule is checked
    # against); `max-h-none`/`max-w-none`, which the center position's own max-h/max-w override and
    # a class merge drops; the two `data-ui--modal-confirm-*-value` names, renamed to their locale
    # keys' leaves. Centring is `inset-x-0 mx-auto`, not the `left-1/2` this pin first recorded:
    # the stress page found `left-1/2` follows the inline start, so a centred 320px dialog sat at
    # x = -160 in RTL (modal_test M10 pins the fix).
    # 2026-09-18, after the retrofit: Modal joined the kit's other floating surfaces -- bg-popover
    # with a border -- because on the page's own token with no edge it vanished in dark mode. The
    # pin moved with that decision; it was not edited to make anything pass.
    MODAL_DIALOG_CLASSES = %w[
      fixed p-0 m-0 bg-popover text-popover-foreground border border-border shadow-2xl
      opacity-0 data-[state=open]:opacity-100 transition-all duration-300 ease-in-out focus-visible:outline-none
      backdrop:backdrop-blur-sm backdrop:opacity-0 data-[state=open]:backdrop:opacity-100
      backdrop:transition-opacity backdrop:duration-300 backdrop:ease-in-out
      top-1/2 inset-x-0 mx-auto modal-center-hidden w-full sm:w-[42rem] max-w-full sm:max-w-[42rem] max-h-[90vh]
      rounded-none sm:rounded-lg overflow-y-auto
    ].freeze

    # Expected to change: `bg-white dark:bg-neutral-900 border-neutral-200 dark:border-neutral-700`.
    POPOVER_PANEL_CLASSES = %w[
      overflow-visible text-inherit outline-none transition duration-100 ease-out origin-top
      data-[state=closed]:opacity-0 data-[state=closed]:scale-95
      data-[state=closing]:opacity-0 data-[state=closing]:scale-95
      border rounded-lg shadow-lg
    ].freeze

    # Expected to change: `bg-neutral-900 text-white dark:bg-white dark:text-neutral-900` on the
    # tooltip and `bg-neutral-900 dark:bg-white` on its arrow.
    TOOLTIP_CONTENT_CLASSES = %w[
      overflow-visible transition-opacity duration-100 ease-out
      data-[state=closed]:opacity-0 data-[state=closing]:opacity-0
      px-2 py-1 text-xs font-medium rounded shadow-sm max-w-xs text-pretty
    ].freeze
    TOOLTIP_ARROW_CLASSES = %w[absolute h-2 w-2 rotate-45].freeze

    # Expected to change: `hidden absolute z-50 opacity-0 scale-95`, the hand-rolled open state
    # that moves onto ui--overlay's `hidden` attribute and data-state, and the z-index it deletes.
    DROPDOWN_CONTENT_CLASSES = %w[transition duration-100 ease-out origin-top].freeze

    test 'RP1: Modal renders its wrapper wiring and dialog as at v0.3.0 HEAD' do
      render_inline(Ui::ModalComponent.new(aria: { label: 'Edit record' })) { 'hello' }

      root = page.find('div[data-controller]')
      assert_tokens root['data-controller'], %w[ui--modal ui--overlay]
      assert_equal 'false', root['data-ui--modal-track-changes-value']
      assert_equal 'true', root['data-ui--modal-close-on-backdrop-value']
      assert_equal 'modal', root['data-ui--overlay-mode-value']
      assert_equal 'true', root['data-ui--overlay-open-value']
      assert_equal 'true', root['data-ui--overlay-scroll-lock-value']
      assert_tokens root['data-action'],
                    %w[ui--overlay:dismiss->ui--modal#guardDismiss:self ui--overlay:closed->ui--modal#remove:self]

      dialog = root.find(:xpath, './dialog')
      assert_equal 'content', dialog['data-ui--overlay-target']
      assert_equal 'Edit record', dialog['aria-label']
      assert_tokens dialog[:class], MODAL_DIALOG_CLASSES
      assert_equal 'hello', dialog.text.strip
    end

    test 'RP2: Popover renders its trigger wrapper and hidden panel as at v0.3.0 HEAD' do
      render_inline(Ui::PopoverComponent.new) do |popover|
        popover.with_trigger { '<button>Open</button>'.html_safe }
        popover.with_panel { '<p>Panel</p>'.html_safe }
      end

      root = page.find('div[data-controller]')
      assert_tokens root['data-controller'], %w[ui--popover ui--overlay ui--anchor]
      assert_equal 'layer', root['data-ui--overlay-mode-value']
      assert_equal 'bottom', root['data-ui--anchor-placement-value']
      assert_equal '8', root['data-ui--anchor-offset-value']
      assert_equal 'fixed', root['data-ui--anchor-strategy-value']

      trigger, panel = root.all(:xpath, './div', visible: :all).to_a
      assert_equal %w[trigger trigger anchor],
                   attribute_values(trigger, 'data-ui--popover-target', 'data-ui--overlay-target', 'data-ui--anchor-target')
      assert_nil trigger['data-action']
      assert trigger.has_selector?(:xpath, './button', text: 'Open')

      assert_equal %w[content content floating],
                   attribute_values(panel, 'data-ui--popover-target', 'data-ui--overlay-target', 'data-ui--anchor-target')
      assert panel.native.key?('hidden')
      assert_tokens panel[:class], POPOVER_PANEL_CLASSES
      assert panel.has_selector?(:xpath, './p', text: 'Panel', visible: :all)
    end

    test 'RP3: Tooltip renders its trigger wrapper, hidden hint and arrow as at v0.3.0 HEAD' do
      render_inline(Ui::TooltipComponent.new(text: 'Save changes')) do |tooltip|
        tooltip.with_trigger { '<button>Save</button>'.html_safe }
      end

      root = page.find('div[data-controller]')
      assert_tokens root['data-controller'], %w[ui--tooltip ui--overlay ui--anchor]
      assert_equal 'hint', root['data-ui--overlay-mode-value']
      assert_equal 'false', root['data-ui--overlay-restore-focus-value']
      assert_equal 'top', root['data-ui--anchor-placement-value']
      assert_equal '6', root['data-ui--anchor-offset-value']
      assert_equal 'fixed', root['data-ui--anchor-strategy-value']

      trigger, content = root.all(:xpath, './div', visible: :all).to_a
      assert_equal %w[trigger anchor], attribute_values(trigger, 'data-ui--tooltip-target', 'data-ui--anchor-target')
      assert trigger.has_selector?(:xpath, './button', text: 'Save')

      assert_equal %w[content content floating],
                   attribute_values(content, 'data-ui--tooltip-target', 'data-ui--overlay-target', 'data-ui--anchor-target')
      assert content.native.key?('hidden')
      assert_tokens content[:class], TOOLTIP_CONTENT_CLASSES
      refute_includes content[:class].split, 'pointer-events-none'
      assert_equal 'Save changes', content.native.children.select(&:text?).map(&:text).join.strip

      arrow = content.native.at_xpath('./div')
      assert_equal 'arrow', arrow['data-ui--anchor-target']
      assert_tokens arrow['class'], TOOLTIP_ARROW_CLASSES
    end

    test 'RP4: Dropdown renders its trigger wrapper and content, for both kinds, as at v0.3.0 HEAD' do
      render_inline(Ui::DropdownComponent.new) do |dropdown|
        dropdown.with_trigger { '<button>Actions</button>'.html_safe }
        dropdown.with_menu { '<a href="#">Edit</a>'.html_safe }
      end

      root = page.find('div[data-controller~="ui--dropdown"]')
      assert_tokens root['data-controller'], %w[ui--dropdown ui--anchor]
      assert_equal 'menu', root['data-ui--dropdown-kind-value']
      assert_equal 'bottom-start', root['data-ui--anchor-placement-value']
      assert_equal '4', root['data-ui--anchor-offset-value']
      assert_equal 'false', root['data-ui--anchor-match-width-value']

      trigger, content = root.all(:xpath, './div', visible: :all).to_a
      assert_equal %w[trigger anchor], attribute_values(trigger, 'data-ui--dropdown-target', 'data-ui--anchor-target')
      assert trigger.has_selector?(:xpath, './button', text: 'Actions')

      assert_equal %w[content floating], attribute_values(content, 'data-ui--dropdown-target', 'data-ui--anchor-target')
      assert_equal 'menu', content['role']
      assert_tokens content['data-controller'], %w[ui--roving-focus]
      assert_equal 'true', content['data-ui--roving-focus-typeahead-value']
      assert_nil content['aria-label']
      assert_tokens content[:class], DROPDOWN_CONTENT_CLASSES
      assert content.has_selector?(:xpath, './a', text: 'Edit', visible: :all)

      render_inline(Ui::DropdownComponent.new(kind: :dialog, label: 'Filter results')) do |dropdown|
        dropdown.with_trigger { '<button>Filter</button>'.html_safe }
        dropdown.with_menu { '<input type="search">'.html_safe }
      end

      root = page.find('div[data-controller~="ui--dropdown"]')
      assert_equal 'dialog', root['data-ui--dropdown-kind-value']
      content = root.all(:xpath, './div', visible: :all).to_a.last
      assert_equal 'dialog', content['role']
      assert_equal 'Filter results', content['aria-label']
      refute_includes content['data-controller'].to_s.split, 'ui--roving-focus'
      assert content.has_selector?(:xpath, './input', visible: :all)
    end

    private

    def attribute_values(node, *names)
      names.map { |name| node[name] }
    end

    def assert_tokens(actual, expected)
      missing = expected - actual.to_s.split
      assert_empty missing, "missing #{missing.inspect} from #{actual.inspect}"
    end
  end
end
