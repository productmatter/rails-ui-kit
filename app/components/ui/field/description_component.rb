# frozen_string_literal: true

module Ui
  module Field
    # Fades on data-state, which ui--field sets through the presence primitive when a morph
    # swaps the description and the error. Nothing sets data-state on a static render.
    class DescriptionComponent < Ui::Base
      data_slot 'field-description'

      class_variants(base: "text-sm text-muted-foreground #{Ui::Field::ErrorComponent::SWAP_CLASSES}")

      def call
        content_tag(:p, content, root_attributes)
      end
    end
  end
end
