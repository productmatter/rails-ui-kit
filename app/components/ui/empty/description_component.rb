# frozen_string_literal: true

module Ui
  module Empty
    class DescriptionComponent < Ui::Base
      data_slot 'empty-description'

      class_variants(
        base: 'text-sm leading-relaxed text-muted-foreground [&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary'
      )

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
