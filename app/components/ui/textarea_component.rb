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

    # `size:` accepts a symbol or string; nil means the default. `counter:`/`limit:` are
    # consumed here, never forwarded to the element, the way `size:` already is
    # (ui-presentational-components § Business rules, rule 1); `rendered_by_field:` is not
    # part of the public API -- Ui::Field::ControlComponent is the only caller that ever sets
    # it, so its presence is what proves a Textarea with `counter:` has somewhere to render
    # its count (ui-character-counter § Behavior, item 3). Everything else is forwarded.
    def initialize(size: :default, counter: false, limit: nil, rendered_by_field: false, **html_attributes)
      @size = size
      @counter = boolean_attribute?(counter)
      @limit = limit
      validate_counter!(rendered_by_field)
      super(**html_attributes)
    end

    def variant_values
      { size: size }
    end

    def counter?
      @counter
    end

    private

    # counter: and limit: are a pair, the way Choices' description_method: and icon_method:
    # need collection: -- always raised, whatever the environment, because leaving one out is
    # a plain mistake with one fix. Rendered with no Field to hold it is a separate check,
    # below: that can be a real page a caller doesn't control every corner of.
    def validate_counter!(rendered_by_field)
      validate_pairing!
      validate_field!(rendered_by_field)
    end

    def validate_pairing!
      raise ArgumentError, "#{self.class.name}: counter: true needs limit:, a positive integer." if @counter && @limit.nil?
      raise ArgumentError, "#{self.class.name}: limit: needs counter: true." if @limit && !@counter
    end

    # Ui::Base's own unknown-variant gate -- loud in development and test, a warning and a
    # disabled counter elsewhere, rather than a page that won't render.
    def validate_field!(rendered_by_field)
      return unless @counter && !rendered_by_field

      message = "#{self.class.name}: counter: true needs a Field to render its count in -- help text is " \
                'Field\'s row. Render this Textarea through field.with_control.'
      raise ArgumentError, message if self.class.raise_on_unknown_variant?

      Rails.logger&.warn("[rails_ui_kit] #{message} Ignoring counter:.")
      @counter = false
    end
  end
end
