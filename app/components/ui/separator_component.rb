# frozen_string_literal: true

module Ui
  # A rule between content. Decorative (role="none") by default, since most
  # separators in a layout are purely visual; a caller that means the separator
  # to be read by assistive tech passes `decorative: false` for `role="separator"`
  # and `aria-orientation` (rule 4). The bar itself is exempt from the 3:1 non-text
  # contrast rule either way -- it is decoration, like a card border.
  class SeparatorComponent < Ui::Base
    data_slot 'separator'

    class_variants(
      base: 'shrink-0 bg-border',
      variants: {
        orientation: {
          horizontal: 'h-px w-full',
          vertical: 'h-full w-px'
        }
      },
      defaults: { orientation: :horizontal }
    )

    attr_reader :orientation, :decorative

    def initialize(orientation: :horizontal, decorative: true, **html_attributes)
      @orientation = orientation
      @decorative = decorative
      super(**html_attributes)
    end

    def variant_values
      { orientation: orientation }
    end

    def element_attributes
      return { role: 'none' } if decorative

      { role: 'separator', aria: { orientation: orientation.to_s } }
    end
  end
end
