# frozen_string_literal: true

module Ui
  module Alert
    # A status glyph rarely carries information the title and description don't
    # already say, so it is hidden from assistive tech by default (rule 4). A
    # caller whose icon does carry meaning overrides that with `aria: { hidden: false }`.
    class IconComponent < Ui::Base
      data_slot 'alert-icon'

      class_variants(base: 'row-start-1 [&>svg]:size-4 [&>svg]:translate-y-0.5')

      def call
        content_tag(:span, content, root_attributes(aria: { hidden: true }))
      end
    end
  end
end
