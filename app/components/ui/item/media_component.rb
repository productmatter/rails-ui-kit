# frozen_string_literal: true

module Ui
  module Item
    # Sits beside the title/description column; when a description is present it
    # nudges down and self-aligns to the top instead of centering on the whole
    # row, so it lines up with the title's baseline rather than the pair's midpoint.
    class MediaComponent < Ui::Base
      data_slot 'item-media'

      class_variants(
        base: 'flex shrink-0 items-center justify-center gap-2 [&_svg]:pointer-events-none ' \
              'group-has-[[data-slot=item-description]]/item:translate-y-0.5 ' \
              'group-has-[[data-slot=item-description]]/item:self-start',
        variants: {
          variant: {
            default: 'bg-transparent',
            icon: 'size-8 rounded-sm border bg-muted [&_svg:not([class*="size-"])]:size-4',
            image: 'size-10 overflow-hidden rounded-sm [&_img]:size-full [&_img]:object-cover'
          }
        },
        defaults: { variant: :default }
      )

      attr_reader :variant

      def initialize(variant: :default, **html_attributes)
        @variant = variant
        super(**html_attributes)
      end

      def variant_values
        { variant: variant }
      end

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
