# frozen_string_literal: true

module Ui
  module Toast
    # One action a toast offers: a link, a form that sends another method, or a button that only
    # dismisses (ui-toast § Behavior, item 6). Built through .build, which returns nil for an
    # action that breaks a rule outside development and test, so an invalid action is dropped.
    class Action
      KEYS = %i[label href method variant class dismiss].freeze
      METHODS = %w[get post patch put delete].freeze
      DEFAULT_VARIANT = :outline

      attr_reader :label, :href, :http_method, :variant, :css_class, :dismiss

      def self.build(raw)
        return Validation.invalid!("A toast action must be a Hash, got #{raw.class}. It is dropped.") unless raw.is_a?(Hash)

        action = new(raw.to_h.transform_keys(&:to_sym))
        action if action.valid?
      end

      def self.variants
        Ui::ButtonComponent.variant_options[:variant]
      end

      def initialize(attributes)
        @attributes = attributes
        @label = attributes[:label]
        @href = attributes[:href]
        @css_class = attributes[:class]
        @dismiss = attributes.fetch(:dismiss, true)
        @valid = validate
      end

      def valid?
        @valid
      end

      # :link for a GET href, :form for any other method, :button for no href at all.
      def kind
        return :button if href.nil?

        http_method == 'get' ? :link : :form
      end

      private

      def validate
        problem = shape_problem
        return reject(problem) if problem

        resolve_variant && resolve_method && valid_href? && valid_dismiss?
      end

      def shape_problem
        unknown = @attributes.keys - KEYS
        return "has unknown keys #{unknown.map(&:inspect).join(', ')}; expected #{KEYS.join(', ')}" if unknown.any?

        'needs a label: it is the visible text and the accessible name' unless label.is_a?(String) && label.present?
      end

      def resolve_variant
        value = @attributes.fetch(:variant, DEFAULT_VARIANT)
        @variant = self.class.variants.find { |option| option.to_s == value.to_s }
        @variant || reject("has no variant #{value.inspect}; expected one of #{self.class.variants.join(', ')}")
      end

      def resolve_method
        value = @attributes[:method]
        return reject("sets method: #{value.inspect} without an href, so it would do nothing") if value && href.nil?

        @http_method = (value || 'get').to_s.downcase
        METHODS.include?(@http_method) || reject("has no method #{value.inspect}; expected one of #{METHODS.join(', ')}")
      end

      def valid_href?
        return true if href.nil? || Href.allowed?(href)

        reject("has href #{href.inspect}, which is not a relative or http(s) URL")
      end

      def valid_dismiss?
        return reject('sets dismiss: to something other than true or false') unless [true, false].include?(dismiss)
        return true if dismiss || href

        reject('sets dismiss: false without an href, so it would do nothing')
      end

      # nil, so a check that fails outside development and test stops the chain in validate.
      def reject(problem)
        Validation.invalid!("Toast action #{label.inspect} #{problem}. The action is dropped.")
      end
    end
  end
end
