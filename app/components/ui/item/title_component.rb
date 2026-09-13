# frozen_string_literal: true

module Ui
  module Item
    class TitleComponent < Ui::Base
      data_slot 'item-title'

      class_variants(base: 'flex w-fit items-center gap-2 text-sm font-medium leading-snug')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
