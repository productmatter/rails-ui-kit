# frozen_string_literal: true

module Ui
  module ButtonGroup
    # A non-interactive label chip between buttons -- a symbol or short word that
    # doesn't warrant its own button. Its data-slot starts with "button" like the
    # buttons around it, so it picks up the same corner-squaring and border-overlap
    # treatment from ButtonGroupComponent's own selectors.
    class TextComponent < Ui::Base
      data_slot 'button-group-text'

      class_variants(
        base: 'flex items-center gap-2 rounded-md border border-input bg-muted px-3 text-sm font-medium ' \
              'text-muted-foreground shadow-xs [&_svg]:pointer-events-none [:where(&_svg)]:size-4'
      )

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
