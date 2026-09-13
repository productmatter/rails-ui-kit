# frozen_string_literal: true

module Ui
  module Item
    # The structural rule between items in a Ui::Item::GroupComponent -- a
    # relabelled Ui::SeparatorComponent rather than a copy of its class table
    # (rule 1).
    class SeparatorComponent < Ui::Base
      data_slot 'item-separator'

      class_variants(base: 'my-0')

      def call
        render Ui::SeparatorComponent.new(**html_attributes, data: { slot: self.class.data_slot }, class: root_class)
      end
    end
  end
end
