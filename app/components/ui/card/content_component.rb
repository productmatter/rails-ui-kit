# frozen_string_literal: true

module Ui
  module Card
    class ContentComponent < Ui::Base
      data_slot 'card-content'

      class_variants(base: 'px-6')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
