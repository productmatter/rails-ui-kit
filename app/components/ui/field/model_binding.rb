# frozen_string_literal: true

module Ui
  module Field
    # What a Field reads from the record behind it: the param key its name is built from,
    # the attribute's errors, label text, value and whether it is required. It reads only
    # ActiveModel's shape — `to_model`, `model_name`, `errors` — and uses
    # `validators_on`, `human_attribute_name` and the attribute readers only when they
    # exist, so a plain form object binds as well as a database-backed model does.
    class ModelBinding
      # The options a presence validator may carry and still mark a field required. Every
      # other option makes presence conditional (`if:`, `on:`) or weaker (`allow_nil:`), and
      # an option this list doesn't name is read as one of those rather than guessed at.
      UNCONDITIONAL_OPTIONS = %i[message strict].freeze

      attr_reader :record, :attribute

      def initialize(model, attribute)
        @record = self.class.record_for(model)
        @attribute = self.class.attribute_name(attribute)
      end

      class << self
        def record_for(model)
          unless model.respond_to?(:to_model)
            raise ArgumentError, "Ui::FieldComponent's model: must be a record that responds to to_model, got #{model.inspect}. " \
                                 'For a bare scope such as :user, pass name: "user[email]" instead.'
          end

          record = model.to_model
          return record if record.respond_to?(:model_name) && record.respond_to?(:errors)

          raise ArgumentError, "Ui::FieldComponent's model: must respond to model_name and errors after to_model; " \
                               "#{record.class} doesn't. Include ActiveModel::API, or pass name: and errors: instead."
        end

        def attribute_name(attribute)
          name = attribute.to_s
          raise ArgumentError, "Ui::FieldComponent's model: needs attribute:, the attribute this field edits." if name.empty?
          return name unless name.match?(/[\[\].]/) || name.end_with?('?')

          raise ArgumentError, "Ui::FieldComponent's attribute: must be a single attribute name, got #{attribute.inspect}. " \
                               'For a nested attribute, pass the nested record as model: and its full name: explicitly.'
        end
      end

      def param_key
        record.model_name.param_key
      end

      def errors
        record.errors[attribute]
      end

      # The order form.label resolves in (ActionView::Helpers::Tags::Translator and
      # Tags::Label): helpers.label under the param key, then under the i18n key, then the
      # class's human_attribute_name, then the humanised attribute.
      def label_text
        translated = I18n.t("#{param_key}.#{attribute}", scope: 'helpers.label',
                                                         default: [:"#{record.model_name.i18n_key}.#{attribute}", '']).presence
        translated || human_attribute_name || attribute.humanize
      end

      # True only for a presence validator with no option beyond message: and strict:.
      # Anything conditional, weakened or unrecognised leaves the field not required: a
      # control wrongly marked required blocks a submission the model would accept.
      def required?
        return false unless record.class.respond_to?(:validators_on)

        record.class.validators_on(attribute).any? do |validator|
          validator.respond_to?(:kind) && validator.kind == :presence &&
            (validator.options.keys.map(&:to_sym) - UNCONDITIONAL_OPTIONS).empty?
        end
      end

      # What form.text_field renders as the value (Tags::Base#value_before_type_cast): the
      # _before_type_cast reader when the value came from the user and that reader exists,
      # otherwise the attribute. A record without the reader has no value.
      def value
        before_type_cast = "#{attribute}_before_type_cast"
        return record.public_send(before_type_cast) if came_from_user? && record.respond_to?(before_type_cast)

        record.public_send(attribute) if record.respond_to?(attribute)
      end

      private

      def human_attribute_name
        record.class.human_attribute_name(attribute) if record.class.respond_to?(:human_attribute_name)
      end

      def came_from_user?
        predicate = "#{attribute}_came_from_user?"
        !record.respond_to?(predicate) || record.public_send(predicate)
      end
    end
  end
end
