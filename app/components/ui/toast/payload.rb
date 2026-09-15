# frozen_string_literal: true

module Ui
  module Toast
    # A toast as plain data (ui-toast § Behavior, item 1): the one shape Ruby, a Turbo Stream, flash
    # and JavaScript all carry. Keys may be strings or symbols and values may be strings where a
    # symbol is expected, because a flash that round-trips a JSON session comes back that way.
    #
    # Every rule is checked here, once, whichever entry point the payload came through.
    class Payload
      TYPES = %i[success error notice alert warning info].freeze
      KEYS = %i[type title description actions duration icon].freeze
      # 0.2.0's names, still honoured outside development and test (§ Behavior, item 15).
      RENAMED = { body: :description, timeout: :duration }.freeze

      ERROR_DURATION = 20_000
      DEFAULT_DURATION = 3_000

      attr_reader :type, :title, :description, :actions, :duration

      def initialize(raw)
        attributes = rename_legacy_keys(raw.to_h.transform_keys(&:to_sym))
        reject_unknown_keys(attributes)
        assign(attributes)
      end

      # false only when the payload removed the type's glyph.
      def icon?
        @icon
      end

      # A toast with an action never counts down unless the payload asks it to: a default can't
      # take an Undo away from someone still reaching for it (§ Behavior, item 10).
      def countdown?
        duration.positive?
      end

      private

      # In this order: the default duration depends on the type and on whether any action survived.
      def assign(attributes)
        @type = resolve_type(attributes[:type])
        @title = text(:title, attributes[:title])
        @description = text(:description, attributes[:description])
        @actions = Array(attributes[:actions]).filter_map { |action| Action.build(action) }
        @duration = resolve_duration(attributes[:duration])
        @icon = keeps_icon?(attributes[:icon])
      end

      def rename_legacy_keys(attributes)
        RENAMED.each do |old, new|
          next unless attributes.key?(old)

          Validation.invalid!("Toast #{old}: is now #{new}:. Rename it; #{new}: is used in its place.")
          value = attributes.delete(old)
          attributes[new] = value unless attributes.key?(new)
        end
        attributes
      end

      def reject_unknown_keys(attributes)
        unknown = attributes.keys - KEYS
        return if unknown.empty?

        Validation.invalid!("Toast has unknown keys #{unknown.map(&:inspect).join(', ')}; expected #{KEYS.join(', ')}. " \
                            'They are ignored.')
      end

      def resolve_type(value)
        return :info if value.nil?

        match = TYPES.find { |type| type.to_s == value.to_s }
        return match if match

        Validation.invalid!("Ui::ToastComponent has no type: #{value.inspect}. Expected one of: " \
                            "#{TYPES.map(&:inspect).join(', ')}. Rendering :info instead.", Ui::Base::UnknownVariantError)
        :info
      end

      def text(key, value)
        return value if value.nil? || value.is_a?(String)

        Validation.invalid!("Toast #{key}: must be a String, got #{value.class}. It is left out.")
      end

      # An Integer, or a String of one, because flash stores what JSON gives it. Anything else --
      # including "1; background-image: url(…)" -- is never written anywhere, and the default
      # applies (§ Behavior, item 15).
      def resolve_duration(value)
        return default_duration if value.nil?

        coerced = integer(value)
        return coerced if coerced && !coerced.negative?

        Validation.invalid!("Toast duration: must be a whole number of milliseconds, 0 or more, got #{value.inspect}. " \
                            'The default is used instead.')
        default_duration
      end

      def integer(value)
        case value
        when Integer then value
        when String then Integer(value, 10, exception: false)
        end
      end

      def default_duration
        return 0 if actions.any?

        type == :error ? ERROR_DURATION : DEFAULT_DURATION
      end

      def keeps_icon?(value)
        return true if value.nil?
        return false if value == false

        Validation.invalid!("Toast icon: accepts only false, which removes the glyph, got #{value.inspect}. " \
                            "A replacement glyph goes in the icon slot. The type's glyph is kept.")
        true
      end
    end
  end
end
