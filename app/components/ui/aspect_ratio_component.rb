# frozen_string_literal: true

module Ui
  # A box that holds its child at a fixed ratio: the child fills it completely
  # (`absolute inset-0`), whatever the child actually is. A ratio outside the
  # fixed set comes from the caller's `class:`, since Tailwind only compiles a
  # class it finds literally in the source (rule 2) -- `aspect-[…]` can't take a
  # runtime value.
  class AspectRatioComponent < Ui::Base
    data_slot 'aspect-ratio'

    class_variants(
      base: 'relative w-full',
      variants: {
        ratio: {
          square: 'aspect-square',
          video: 'aspect-video',
          portrait: 'aspect-[3/4]',
          classic: 'aspect-[4/3]'
        }
      },
      defaults: { ratio: :square }
    )

    attr_reader :ratio

    def initialize(ratio: :square, **html_attributes)
      @ratio = ratio
      super(**html_attributes)
    end

    def variant_values
      { ratio: ratio }
    end
  end
end
