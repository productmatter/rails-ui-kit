# frozen_string_literal: true

module Ui
  module Card
    class TitleComponent < Ui::Base
      data_slot 'card-title'

      class_variants(base: 'min-w-0 font-semibold leading-none break-words')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
