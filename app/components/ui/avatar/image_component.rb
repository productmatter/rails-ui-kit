# frozen_string_literal: true

module Ui
  module Avatar
    # Layered over the fallback (`absolute inset-0`) so the fallback shows through
    # whenever this doesn't paint -- no `src`, or a failed load. `alt` defaults to
    # empty: the accessible name belongs to Ui::AvatarComponent's `alt:`, not to
    # this element, so a caller never has two names to keep in sync and a broken
    # image never flashes alt text over the fallback beneath it.
    class ImageComponent < Ui::Base
      data_slot 'avatar-image'

      class_variants(base: 'absolute inset-0 aspect-square size-full rounded-full object-cover')

      attr_reader :alt

      def initialize(alt: '', **html_attributes)
        @alt = alt
        super(**html_attributes)
      end

      def call
        tag.img(**root_attributes(alt: alt))
      end
    end
  end
end
