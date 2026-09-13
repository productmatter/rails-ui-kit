# frozen_string_literal: true

module Ui
  module Card
    class FooterComponent < Ui::Base
      data_slot 'card-footer'

      class_variants(base: 'flex items-center px-6 [.border-t]:pt-6')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
