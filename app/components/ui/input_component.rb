# frozen_string_literal: true

module Ui
  class InputComponent < Ui::Base
    data_slot 'input'

    # The boundary is border-input, tuned to reach 3:1 against every token surface
    # (ui-design-tokens). The fill is explicit in both modes -- bg-background in light,
    # a translucent --muted in dark -- so a control reads as a control on any surface
    # instead of inheriting whatever it sits on (decided 2026-09-14; inside a muted card
    # a transparent control read as a sunken grey panel). Don't "simplify" it back to
    # bg-transparent. The dark fill never comes from --input: that token is the border,
    # and deriving the fill from it washes the boundary and fill out together
    # (ui-presentational-components rule 6). Invalid styling is driven entirely by
    # aria-invalid, never a Ruby keyword, so field binding can set it later.
    #
    # Height is Button's size scale, read from the same tokens (ui-control-sizing).
    class_variants(
      base: 'flex w-full min-w-0 rounded-md border border-input bg-background dark:bg-muted/50 ' \
            'px-3 py-1 text-sm shadow-xs transition-colors ' \
            'placeholder:text-muted-foreground ' \
            'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring ' \
            'disabled:pointer-events-none disabled:opacity-50 ' \
            'aria-invalid:border-destructive aria-invalid:focus-visible:outline-destructive',
      variants: {
        size: {
          sm: 'h-(--control-height-sm)',
          default: 'h-(--control-height)',
          lg: 'h-(--control-height-lg)'
        }
      },
      defaults: { size: :default }
    )

    attr_reader :type, :size

    # `type:`/`size:` accept a symbol or string; nil means the default. `size:` is the kit's
    # size scale, not the HTML attribute of the same name. Everything else (name:, value:,
    # placeholder:, id:, disabled:, aria-invalid:, …) is forwarded.
    def initialize(type: 'text', size: :default, **html_attributes)
      @type = type
      @size = size
      super(**html_attributes)
    end

    def variant_values
      { size: size }
    end

    def element_attributes
      { type: type }
    end
  end
end
