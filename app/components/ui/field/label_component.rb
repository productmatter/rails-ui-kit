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
    # control's own state.
    class LabelComponent < ViewComponent::Base
      def initialize(field:, **attributes)
        @field = field
        @attributes = attributes
        super()
      end

      def call
        render(Ui::LabelComponent.new(**names_control, id: @field.label_id, **@attributes)) do
          safe_join([content? ? content : @field.label_text, required_marker].compact)
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
    end
  end
end
