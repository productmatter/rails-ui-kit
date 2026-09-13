# frozen_string_literal: true

module Ui
  module Table
    class CellComponent < Ui::Base
      data_slot 'table-cell'

      class_variants(base: 'whitespace-nowrap p-2 align-middle')

      def call
        content_tag(:td, content, root_attributes)
      end
    end
  end
end
