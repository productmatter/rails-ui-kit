# frozen_string_literal: true

module Ui
  module Select
    # The listbox half of Select's two renderings of one option model: the same options the
    # native <select> holds, as `role="option"` elements a combobox can point
    # aria-activedescendant at. It never holds the value — choosing writes the select, and
    # the select is what every visible state is derived from (ui-select § Business rules,
    # rules 1 and 7).
    #
    # `id` is the control's id, not the listbox's: every id inside is derived from it so the
    # ids a re-render produces are the ids the previous one produced.
    class ListboxComponent < Ui::Base
      data_slot 'select-listbox'

      OPTION_CLASSES = 'group relative flex w-full cursor-default select-none items-center gap-2 ' \
                       'rounded-sm py-1.5 ps-2 pe-8 text-sm text-popover-foreground outline-none ' \
                       'aria-disabled:pointer-events-none aria-disabled:opacity-50'

      GROUP_CLASSES = 'px-2 py-1.5 text-xs font-medium text-muted-foreground'

      class_variants(base: 'max-h-64 overflow-y-auto overscroll-contain p-1')

      attr_reader :control_id, :option_set, :labelledby

      def initialize(id:, option_set: nil, labelledby: nil, **attributes)
        @control_id = id.to_s
        @labelledby = labelledby
        @option_set = option_set || Ui::Select::OptionSet.new(**attributes.extract!(*Ui::Select::OptionSet::KEYS))
        super(**attributes)
      end

      def listbox_id
        "#{control_id}-listbox"
      end

      def items
        option_set.items
      end

      # Items in DOM order, chunked by the group they belong to, each still carrying the
      # index its id is derived from. An ungrouped list is one chunk with a blank label --
      # blank rather than nil because Enumerable#chunk drops a nil key's elements entirely.
      def groups
        @groups ||= items.each_with_index.chunk { |item, _index| item.group.to_s }.to_a
      end

      # A labelled group wraps its own options. An unlabelled one wraps nothing: a generic
      # element between the listbox and its options would break the role's required
      # children, which is also why remote search's frame wraps the listbox rather than
      # sitting inside it (§ Behavior, item 27).
      def group_tag(label, index, options)
        tag.div(role: 'group', aria: { labelledby: group_id(index) }) do
          safe_join([tag.div(label, id: group_id(index), class: GROUP_CLASSES), options])
        end
      end

      def option_id(index)
        "#{control_id}-option-#{index}"
      end

      def group_id(index)
        "#{control_id}-group-#{index}"
      end

      # aria-selected marks where visual focus is, never what the value is, so it is false on
      # every option until the combobox makes one active (§ Behavior, item 19). The current
      # value is marked separately, with data-selected, which is what draws the check.
      #
      # Hover moves the active option through the primitive rather than through a second
      # implementation here; the click writes the select and closes.
      def option_attributes(item, index)
        {
          id: option_id(index), role: 'option', class: OPTION_CLASSES,
          data: { value: item.value, selected: ('true' if item.selected),
                  'ui--roving-focus-target': 'item',
                  action: 'click->ui--select#choose mouseenter->ui--roving-focus#activate' }.compact,
          aria: { selected: 'false', disabled: ('true' if item.disabled) }.compact
        }
      end
    end
  end
end
