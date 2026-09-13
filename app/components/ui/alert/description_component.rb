# frozen_string_literal: true

module Ui
  module Alert
    class DescriptionComponent < Ui::Base
      data_slot 'alert-description'

      class_variants(base: 'col-start-2 grid min-w-0 gap-1 break-words text-sm text-muted-foreground [&_p]:leading-relaxed')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
