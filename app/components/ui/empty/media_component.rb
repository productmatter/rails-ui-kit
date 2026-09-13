# frozen_string_literal: true

module Ui
  module Empty
    # Named `empty-media` for its data-slot, unlike shadcn's own inconsistent
    # `empty-icon` -- rule 3's `<component>-<part>` scheme, kept consistent with
    # every other part in the kit.
    class MediaComponent < Ui::Base
      data_slot 'empty-media'

      class_variants(
        base: 'mb-2 flex shrink-0 items-center justify-center [&_svg]:pointer-events-none [&_svg]:shrink-0',
        variants: {
          variant: {
            default: 'bg-transparent',
            icon: 'flex size-10 shrink-0 items-center justify-center rounded-lg bg-muted text-foreground [&_svg:not([class*="size-"])]:size-6'
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
