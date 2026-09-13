# frozen_string_literal: true

module Ui
  module Item
    class ActionsComponent < Ui::Base
      data_slot 'item-actions'

      class_variants(base: 'flex items-center gap-2')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
