# frozen_string_literal: true

module Ui
  # A native <select> styled as a form control, with a decorative chevron layered
  # over it. The <select> itself is the root -- not a wrapper div -- so id/name/
  # disabled/aria-invalid forward the same way Input's do (rule 1); the chevron
  # can't live inside a <select> (only option/optgroup can), so a plain
  # positioning div (no data-slot of its own, not a caller-facing part) wraps it.
  # A native <option> doesn't inherit the select's classes, so the popover
  # colours below reach every option/optgroup through a descendant selector
  # instead of requiring the caller to class each one.
  class NativeSelectComponent < Ui::Base
    data_slot 'native-select'

    class_variants(
      base: 'flex w-full min-w-0 appearance-none items-center rounded-md border border-input ' \
            'bg-transparent dark:bg-muted/50 text-sm shadow-xs transition-colors ' \
            'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring ' \
            'disabled:pointer-events-none disabled:opacity-50 ' \
            'aria-invalid:border-destructive aria-invalid:focus-visible:outline-destructive ' \
            '[&_option]:bg-popover [&_option]:text-popover-foreground ' \
            '[&_optgroup]:bg-popover [&_optgroup]:text-popover-foreground',
      variants: {
        size: {
          default: 'h-9 pl-3 pr-8',
          sm: 'h-8 pl-2.5 pr-7'
        }
      },
      defaults: { size: :default }
    )

    attr_reader :size

    # `size:` accepts a symbol or string; nil means the default.
    def initialize(size: :default, **html_attributes)
      @size = size
      super(**html_attributes)
    end

    def variant_values
      { size: size }
    end
  end
end
