# frozen_string_literal: true

module Ui
  module Item
    # A full-width row below the media/content/actions row, mirroring the header.
    class FooterComponent < Ui::Base
      data_slot 'item-footer'

      class_variants(base: 'flex basis-full items-center justify-between gap-2')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
