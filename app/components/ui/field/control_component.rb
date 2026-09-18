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

      # OptionSet's own option-source keywords: what tells this control the caller already
      # named a source, so silent enum: inference stands aside.
      OPTION_SOURCE_KEYS = %i[collection options model enum].freeze

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
        @field.control_attributes(**resolved_attributes)
      end

      # Whether a `<label for>` can name what this control renders (ui-choices § Assumptions).
      def labelable?
        @component.respond_to?(:labelable?) ? @component.labelable? : true
      end

      # The `required:` the caller passed here, or nil when they passed none.
      def stated_required
        @attributes[:required]
      end

      # `counter:`/`limit:` the caller passed to with_control, read the same way stated_required
      # is: straight off the raw attributes, before Textarea is ever built. This is what Field
      # asks to know whether it has a count to render, and how big the limit is, without a
      # circular dependency on building the control first (ui-character-counter § Behavior,
      # item 3 -- "what Textarea tells Field it wants").
      def stated_counter
        @attributes[:counter]
      end

      def stated_limit
        @attributes[:limit]
      end

      def call
        return content if content?

        value = @field.value
        return render(@component.new(**component_attributes)) if value.nil?
        return render(@component.new(**component_attributes)) { value.to_s } if @component <= Ui::TextareaComponent

        render(@component.new(**component_attributes, **value_attributes(value)))
      end

      private

      # The resolved attributes, plus one marker no public keyword carries: this method is the
      # only caller that ever constructs a Textarea, so its presence is what tells Textarea's
      # own `counter: true` check it has a Field to render its count in. Never forwarded to the
      # element -- Textarea's initialize consumes it -- and never added for another component,
      # so nothing else is affected.
      def component_attributes
        return attributes unless @component <= Ui::TextareaComponent

        attributes.merge(rendered_by_field: true)
      end

      # Select and Choices take model:/enum: for their option source. Inside a model-bound
      # Field, both are inferable, additively: enum: alone completes to the field's record
      # class, and no source at all infers enum: from the bound attribute when it is one on the
      # record's class. A caller who named any source keeps exactly what they wrote.
      def resolved_attributes
        return @attributes unless option_source_component? && @field.model_class
        return @attributes.merge(model: @field.model_class) if enum_without_model?
        return @attributes unless no_option_source?

        enum = inferable_enum
        enum ? @attributes.merge(model: @field.model_class, enum: enum) : @attributes
      end

      def option_source_component?
        @component <= Ui::SelectComponent || @component <= Ui::ChoicesComponent
      end

      def enum_without_model?
        @attributes.key?(:enum) && !@attributes.key?(:model)
      end

      def no_option_source?
        OPTION_SOURCE_KEYS.none? { |key| @attributes.key?(key) }
      end

      # ActiveRecord publishes every enum attribute's name on defined_enums (class_attribute,
      # keyed by attribute as a string); respond_to? keeps a plain ActiveModel record inferring
      # nothing rather than raising.
      def inferable_enum
        attribute = @field.bound_attribute
        return unless attribute && @field.model_class.respond_to?(:defined_enums)

        attribute.to_sym if @field.model_class.defined_enums.key?(attribute.to_s)
      end

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
