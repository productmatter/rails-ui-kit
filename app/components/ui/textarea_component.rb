# frozen_string_literal: true

module Ui
  # Input's control styling on a <textarea>. Its value is the block content, the
  # same way Button's label is: a <textarea> has no `value` attribute, its text is
  # its element content.
  class TextareaComponent < Ui::Base
    data_slot 'textarea'

    # A textarea grows with its content, so a step of the shared size scale sets its
    # minimum rather than its height: one control height plus seven spacing units, a
    # constant one-line allowance. At the default step that is sixteen spacing units,
    # exactly the minimum it had before the scale existed (ui-control-sizing).
    #
    # Filled in both modes, as Input is, so it reads as a control on any surface: see
    # InputComponent for why the fill is explicit and why it never comes from --input.
    class_variants(
      base: 'flex w-full rounded-md border border-input bg-background dark:bg-muted/50 ' \
            'px-3 py-2 text-sm shadow-xs transition-colors ' \
            'placeholder:text-muted-foreground ' \
            'focus-visible:border-ring focus-visible:outline-2 focus-visible:outline-ring ' \
            'disabled:pointer-events-none disabled:opacity-50 ' \
            'aria-invalid:border-destructive aria-invalid:focus-visible:border-destructive ' \
            'aria-invalid:focus-visible:outline-destructive',
      variants: {
        size: {
          sm: 'min-h-[calc(var(--control-height-sm)+var(--spacing)*7)]',
          default: 'min-h-[calc(var(--control-height)+var(--spacing)*7)]',
          lg: 'min-h-[calc(var(--control-height-lg)+var(--spacing)*7)]'
        }
      },
      defaults: { size: :default }
    )

    attr_reader :size

    # `size:` accepts a symbol or string; nil means the default. Everything else is forwarded.
    def initialize(size: :default, **html_attributes)
      @size = size
      super(**html_attributes)
    end

    def variant_values
      { size: size }
    end
  end
end
