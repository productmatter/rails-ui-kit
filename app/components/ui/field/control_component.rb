# frozen_string_literal: true

module Ui
  module Field
    # Defers the control's construction to render time. It renders no element of its
    # own: it asks the field for the control's attributes once every part of the field
    # is known, and either builds the requested component with them or hands them to
    # the caller's block.
    #
    # This is why it is not a Ui::Base part — it has no markup, no classes and no
    # data-slot of its own. The control it builds carries all three.
    class ControlComponent < ViewComponent::Base
      # A value never rendered into the HTML, as password_field and file_field don't: a 422
      # must not echo a submitted password back.
      VALUELESS_INPUT_TYPES = %w[password file].freeze

      def initialize(field:, component: Ui::InputComponent, **attributes)
        @field = field
        @component = component
        @attributes = attributes
        super()
      end

      # The wiring the control needs: id, name, aria-describedby, aria-invalid and
      # required, with the caller's own attributes merged over it. Yielded to the block
      # form. The record's value isn't in it: what a value is depends on the control, so
      # a block reads `field.value` itself.
      def attributes
        @field.control_attributes(**@attributes)
      end

      # Whether a `<label for>` can name what this control renders (ui-choices § Assumptions).
      def labelable?
        @component.respond_to?(:labelable?) ? @component.labelable? : true
      end

      # The `required:` the caller passed here, or nil when they passed none.
      def stated_required
        @attributes[:required]
      end

      def call
        return content if content?

        value = @field.value
        return render(@component.new(**attributes)) if value.nil?
        return render(@component.new(**attributes)) { value.to_s } if @component <= Ui::TextareaComponent

        render(@component.new(**attributes, **value_attributes(value)))
      end

      private

      # The record's value in the shape each of the kit's own controls takes it. A value
      # the caller passed wins, and any other control gets none.
      def value_attributes(value)
        keyword = value_keyword
        return {} if keyword.nil? || @attributes.key?(keyword)

        { keyword => value }
      end

      # Each control's own word for "what the record holds": Input's `value:`, Select's
      # `selected:` (Rails' word for `select`), Choices' `checked:` (Rails' word for the
      # collection helpers).
      def value_keyword
        return :selected if @component <= Ui::SelectComponent
        return :checked if @component <= Ui::ChoicesComponent
        return unless @component <= Ui::InputComponent

        :value unless VALUELESS_INPUT_TYPES.include?(@attributes.fetch(:type, 'text').to_s)
      end
    end
  end
end
