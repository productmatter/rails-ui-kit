# frozen_string_literal: true

module Ui
  module Card
    # Sits in the title's row as a zero-height flex line centered on that row, so the
    # action's midpoint lands on the title's midpoint whatever either one's height.
    # An icon button is taller than a title line; top-aligning it instead drops its
    # center between the title and the description. Zero height also keeps a tall
    # action from stretching the title row and pushing the description down. With no
    # title beside it there is no row to center on, so it takes its own height.
    class ActionComponent < Ui::Base
      data_slot 'card-action'

      class_variants(base: 'col-start-2 row-start-1 flex h-0 items-center self-center justify-self-end only:h-auto')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
