# frozen_string_literal: true

module Ui
  module Empty
    class TitleComponent < Ui::Base
      data_slot 'empty-title'

      class_variants(base: 'text-lg font-medium tracking-tight')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
