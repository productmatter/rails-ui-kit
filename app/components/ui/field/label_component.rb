# frozen_string_literal: true

module Ui
  module Field
    # Defers the label's construction to render time, as Ui::Field::ControlComponent does
    # for the control: whether it carries the required marker depends on a `required:` the
    # block may pass to with_control after setting the label.
    #
    # Its text is the caller's block, or the text form.label would render for the record.
    # The marker is real markup, not CSS content, and aria-hidden: generated content joins
    # the accessible name, and the name must stay "Email", with "required" coming from the
    # control's own state -- except search mode's Select trigger (see required_text below),
    # a `<button>` that has no state of its own to say it with.
    class LabelComponent < ViewComponent::Base
      def initialize(field:, **attributes)
        @field = field
        @attributes = attributes
        super()
      end

      def call
        render(Ui::LabelComponent.new(**names_control, id: @field.label_id, **@attributes)) do
          safe_join([content? ? content : @field.label_text, required_marker, required_text].compact)
        end
      end

      private

      # `for` has to point at one labelable element. A control that is a group of inputs isn't
      # one, and pointing it at the first input would make clicking the group's label toggle that
      # choice, so the group is named by `aria-labelledby` pointing back here instead
      # (ui-choices § Behavior, item 10).
      def names_control
        @field.labelable_control? ? { for: @field.control_id } : {}
      end

      def required_marker
        return unless @field.required?

        tag.span('*', aria: { hidden: true }, data: { slot: 'field-required-indicator' }, class: 'text-destructive')
      end

      # A control states "required" itself, through `required` or `aria-required` -- except
      # search mode's Select trigger, a `<button>` ARIA forbids the attribute on. That one
      # control has the label carry it into the accessible name instead: `hidden` keeps this
      # span out of the label's own text (so a `<label for>`-named control never hears it
      # twice), but an element a caller's `aria-labelledby` names directly is still read even
      # while hidden (the same rule ui-field-model-binding item 20 relies on for the error/help
      # swap) -- which is how select_controller.js pulls it into the trigger's name.
      def required_text
        return unless @field.required?

        tag.span(@field.required_label, id: "#{@field.label_id}-required", hidden: true,
                                        data: { slot: 'field-required-text' })
      end
    end
  end
end
