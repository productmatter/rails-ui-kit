# frozen_string_literal: true

module Ui
  module Card
    # Title and description stack in the first column; an action, when present,
    # takes a second column pinned top-right across both rows.
    class HeaderComponent < Ui::Base
      data_slot 'card-header'

      class_variants(
        base: 'grid auto-rows-min grid-rows-[auto_auto] items-start gap-2 px-6 [.border-b]:pb-6',
        variants: { action: 'grid-cols-[1fr_auto]' }
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
