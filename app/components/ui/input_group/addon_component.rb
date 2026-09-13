# frozen_string_literal: true

module Ui
  module InputGroup
    # Text, an icon, or a Ui::ButtonComponent alongside the group's control. Its
    # own `align` stamps a `data-align` attribute the parent group's `has-[]`
    # selectors read (rule 3: the parent still draws the structural layout,
    # not the caller) -- inline-start/inline-end sit beside the control in the
    # group's row, block-start/block-end span the full width above or below it,
    # which is also what flips the group from a row to a column.
    class AddonComponent < Ui::Base
      data_slot 'input-group-addon'

      class_variants(
        base: 'flex items-center gap-2 px-3 py-1 text-sm text-muted-foreground ' \
              '[&_svg]:pointer-events-none [:where(&_svg)]:size-4',
        variants: {
          align: {
            'inline-start': 'order-first',
            'inline-end': 'order-last',
            'block-start': 'order-first w-full basis-full border-b border-border',
            'block-end': 'order-last w-full basis-full border-t border-border'
          }
        },
        defaults: { align: :'inline-start' }
      )

      attr_reader :align

      # `align:` accepts a symbol or string; nil means the default.
      def initialize(align: :'inline-start', **html_attributes)
        @align = align
        super(**html_attributes)
      end

      def variant_values
        { align: align }
      end

      def call
        content_tag(:div, content, root_attributes(data: { align: align.to_s }))
      end
    end
  end
end
