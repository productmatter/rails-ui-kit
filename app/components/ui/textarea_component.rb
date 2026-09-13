# frozen_string_literal: true

module Ui
  # Input's control styling on a <textarea>. Its value is the block content, the
  # same way Button's label is: a <textarea> has no `value` attribute, its text is
  # its element content.
  class TextareaComponent < Ui::Base
    data_slot 'textarea'

    class_variants(
      base: 'flex min-h-16 w-full rounded-md border border-input bg-transparent dark:bg-muted/50 ' \
            'px-3 py-2 text-sm shadow-xs transition-colors ' \
            'placeholder:text-muted-foreground ' \
            'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring ' \
            'disabled:pointer-events-none disabled:opacity-50 ' \
            'aria-invalid:border-destructive aria-invalid:focus-visible:outline-destructive'
    )
  end
end
