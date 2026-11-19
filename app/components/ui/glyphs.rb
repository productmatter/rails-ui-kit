# frozen_string_literal: true

module Ui
  # One 24×24 line glyph, drawn the way every icon in the kit is: stroked in currentColor, so it
  # takes the text colour it sits in and survives forced colours, and aria-hidden, because a glyph
  # is never what names a control. Included by the components that draw their own.
  module Glyphs
    private

    def render_glyph(paths, css: 'size-4')
      attributes = { class: css, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor',
                     'stroke-width': 2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round',
                     aria: { hidden: true } }

      tag.svg(paths, **attributes)
    end
  end
end
