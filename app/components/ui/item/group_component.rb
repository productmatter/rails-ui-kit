# frozen_string_literal: true

module Ui
  module Item
    # A stack of items, block content in call order -- Items and
    # Ui::Item::SeparatorComponent interleaved however the caller places them.
    # No `role="list"` (rule 4, no invented roles): shadcn sets one, but an ARIA
    # list's direct children must be `listitem`, and an Item is a plain row that
    # also renders standalone outside a group, so it never carries that role --
    # imposing it here would trade one violation for another.
    class GroupComponent < Ui::Base
      data_slot 'item-group'

      class_variants(base: 'group/item-group flex flex-col')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
