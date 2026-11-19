# frozen_string_literal: true

module Ui
  module Select
    # The three glyphs Select draws, held apart from the component the way Ui::Select::Box is.
    module Glyphs
      include Ui::Glyphs

      # The same decorative chevron in both modes: the control is one box, whichever element plays it.
      def render_chevron
        render_glyph(tag.path(d: 'm6 9 6 6 6-6'))
      end

      # The clear button's glyph. Decorative: the button is named by its hidden text and the field's.
      def render_clear_glyph
        render_glyph(safe_join([tag.path(d: 'M18 6 6 18'), tag.path(d: 'm6 6 12 12')]), css: 'size-3.5')
      end

      # The search row's glyph, which is what says "this field filters" without a second label.
      def render_search_glyph
        render_glyph(safe_join([tag.circle(cx: 11, cy: 11, r: 8), tag.path(d: 'm21 21-4.3-4.3')]),
                     css: 'size-4 shrink-0 text-muted-foreground')
      end
    end
  end
end
