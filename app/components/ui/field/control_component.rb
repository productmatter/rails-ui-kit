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
      def initialize(field:, component: Ui::InputComponent, **attributes)
        @field = field
        @component = component
        @attributes = attributes
        super()
      end

      # The wiring the control needs: id, name, aria-describedby and aria-invalid,
      # with the caller's own attributes merged over it. Yielded to the block form.
      def attributes
        @field.control_attributes(**@attributes)
      end

      def call
        return content if content?

        render(@component.new(**attributes))
      end
    end
  end
end
