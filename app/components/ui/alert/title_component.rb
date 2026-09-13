# frozen_string_literal: true

module Ui
  module Alert
    class TitleComponent < Ui::Base
      data_slot 'alert-title'

      class_variants(base: 'col-start-2 min-w-0 line-clamp-1 break-words font-medium tracking-tight')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
