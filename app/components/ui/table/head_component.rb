# frozen_string_literal: true

module Ui
  module Table
    class HeadComponent < Ui::Base
      data_slot 'table-head'

      class_variants(base: 'h-10 whitespace-nowrap px-2 text-left align-middle font-medium text-foreground')

      def call
        content_tag(:th, content, root_attributes)
      end
    end
  end
end
