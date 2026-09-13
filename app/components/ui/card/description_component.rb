# frozen_string_literal: true

module Ui
  module Card
    class DescriptionComponent < Ui::Base
      data_slot 'card-description'

      class_variants(base: 'min-w-0 text-sm text-muted-foreground break-words')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
