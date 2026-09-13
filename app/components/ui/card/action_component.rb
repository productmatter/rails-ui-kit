# frozen_string_literal: true

module Ui
  module Card
    class ActionComponent < Ui::Base
      data_slot 'card-action'

      class_variants(base: 'col-start-2 row-span-2 row-start-1 self-start justify-self-end')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
