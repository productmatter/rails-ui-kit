# frozen_string_literal: true

module Ui
  module Choices
    # The per-option methods a Choices caller may name -- `description_method:`, `icon_method:` and
    # `count_method:` -- each called with the collection element an item came from. Held apart from
    # the component the way Ui::Choices::Variant is, so the component stays about names, values and
    # wiring.
    class OptionMethods
      def initialize(component:, description:, icon:, count:)
        @component = component
        @description = description
        @icon = icon
        @count = count
      end

      def description?
        !@description.nil?
      end

      def count?
        !@count.nil?
      end

      def description_for(item)
        call_on(item, @description)
      end

      def icon_for(item)
        call_on(item, @icon)
      end

      def count_for(item)
        call_on(item, @count)
      end

      # Per-option methods need an object to call: an array, hash or enum source has none, which is
      # a caller error rather than a silent half-rendering.
      def validate!(items)
        return unless items.all? { |item| item.object.nil? }

        if count?
          raise ArgumentError, "#{@component}: count_method: needs collection:, because an array, hash or enum " \
                               'source has no object to call it on.'
        end
        return unless description? || @icon

        raise ArgumentError,
              "#{@component}: description_method: and icon_method: need collection:, " \
              'because an array, hash or enum source has no object to call them on.'
      end

      private

      # Rails' own value_for_collection: a symbol names a method, a callable is called.
      def call_on(item, method)
        return if method.nil? || item.object.nil?

        method.respond_to?(:call) ? method.call(item.object) : item.object.public_send(method)
      end
    end
  end
end
