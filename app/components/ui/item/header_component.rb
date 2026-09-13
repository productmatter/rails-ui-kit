# frozen_string_literal: true

module Ui
  module Item
    # A full-width row above the media/content/actions row -- `flex-wrap` on the
    # item lets it wrap onto its own line whatever else is set.
    class HeaderComponent < Ui::Base
      data_slot 'item-header'

      class_variants(base: 'flex basis-full items-center justify-between gap-2')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
