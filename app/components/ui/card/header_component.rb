# frozen_string_literal: true

module Ui
  module Card
    # Title and description stack in the first column; an action, when present,
    # takes a second column pinned right and centered on the title's row. Rows are
    # implicit, so a title-only header has no empty second row adding a gap. The
    # first column's minmax(0, …) lets a long unbroken title wrap instead of
    # widening the column and pushing the action out of the card.
    class HeaderComponent < Ui::Base
      data_slot 'card-header'

      class_variants(
        base: 'grid auto-rows-min items-start gap-2 px-6 [.border-b]:pb-6',
        variants: { action: 'grid-cols-[minmax(0,1fr)_auto]' }
      )

      renders_one :title, Ui::Card::TitleComponent
      renders_one :description, Ui::Card::DescriptionComponent
      renders_one :action, Ui::Card::ActionComponent

      def variant_values
        { action: action? }
      end
    end
  end
end
