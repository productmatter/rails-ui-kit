# frozen_string_literal: true

module Ui
  module Pagination
    # A truncation marker between skipped page numbers. Decorative -- the
    # numbers around it already convey that pages are skipped.
    class EllipsisComponent < Ui::Base
      data_slot 'pagination-ellipsis'

      class_variants(base: 'flex size-9 items-center justify-center')

      def call
        content_tag(:li, '…', root_attributes(aria: { hidden: true }))
      end
    end
  end
end
