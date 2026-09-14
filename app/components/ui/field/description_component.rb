# frozen_string_literal: true

module Ui
  module Field
    class DescriptionComponent < Ui::Base
      data_slot 'field-description'

      class_variants(base: 'text-sm text-muted-foreground')

      def call
        content_tag(:p, content, root_attributes)
      end
    end
  end
end
