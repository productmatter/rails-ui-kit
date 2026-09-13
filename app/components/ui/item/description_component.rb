# frozen_string_literal: true

module Ui
  module Item
    class DescriptionComponent < Ui::Base
      data_slot 'item-description'

      class_variants(
        base: 'line-clamp-2 min-w-0 text-sm font-normal leading-normal text-balance text-muted-foreground ' \
              '[&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary'
      )

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
