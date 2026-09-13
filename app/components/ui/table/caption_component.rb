# frozen_string_literal: true

module Ui
  module Table
    # A part with no slots of its own renders from call, not a template (rule 3).
    class CaptionComponent < Ui::Base
      data_slot 'table-caption'

      class_variants(base: 'mt-4 text-sm text-muted-foreground')

      def call
        content_tag(:caption, content, root_attributes)
      end
    end
  end
end
