# frozen_string_literal: true

module Ui
  # Shared foundation for every kit component: the class_variants variant layer,
  # the tailwind_merge class-merge layer that makes a caller's `class:` win, generic
  # HTML attribute forwarding, and the `data-slot` styling hook.
  class Base < ViewComponent::Base
    # Raised in development and test when a component is rendered with a variant
    # value its class_variants declaration doesn't define.
    class UnknownVariantError < ArgumentError; end

    # One merger per process. Its LRU cache is thread-safe and is what keeps
    # repeated renders from re-parsing the same class lists.
    MERGER = TailwindMerge::Merger.new

    # Attribute prefixes Rails' tag helpers expand from a nested hash.
    PREFIXED_ATTRIBUTES = %w[data aria].freeze
    FLAT_PREFIXED_ATTRIBUTE = /\A(data|aria)-(.+)\z/

    class << self
      # Declares the component's variant axes. Arguments are handed to
      # ClassVariants.build verbatim: base:, variants:, compound_variants:, defaults:.
      def class_variants(**definition)
        @variant_options = variant_options_from(definition.fetch(:variants, {}))
        @variants = ClassVariants.build(**definition)
      end

      # Declares the value stamped as `data-slot` on the component's root element.
      # Explicit per component rather than derived from the class name.
      def data_slot(name = nil)
        @data_slot = name.to_s unless name.nil?
        @data_slot || inherited_setting(:data_slot)
      end

      def variants
        @variants || inherited_setting(:variants)
      end

      # The declared values per axis, e.g. { variant: [:default, :outline], action: [true, false] }.
      def variant_options
        @variant_options || inherited_setting(:variant_options) || {}
      end

      # An unknown variant value is a bug worth failing loudly on while developing.
      # Outside development and test the axis falls back to its default and a warning is logged
      # instead: a mis-styled button is better than a page that won't render.
      def raise_on_unknown_variant?
        Rails.env.development? || Rails.env.test?
      end

      private

      def inherited_setting(name)
        superclass.respond_to?(name) ? superclass.public_send(name) : nil
      end

      # class_variants' boolean shorthand (`action: "…"`, `"!action": "…"`) declares
      # a true/false axis; every other axis is a hash of named values.
      def variant_options_from(variants)
        variants.to_h do |axis, values|
          values.is_a?(Hash) ? [axis.to_sym, values.keys] : [axis.to_s.delete_prefix('!').to_sym, [true, false]]
        end
      end
    end

    attr_reader :html_attributes

    # Every keyword a component does not name for itself lands here and is
    # forwarded to the root element; `class:` is pulled out for the merge step.
    def initialize(**html_attributes)
      @html_attributes = normalize_attributes(html_attributes)
      @caller_class = @html_attributes.delete(:class)
      super()
    end

    # The variant values this component resolves its class list from. Components
    # with variant axes override it; components without any inherit the empty hash.
    # A nil value falls back to the axis default.
    def variant_values
      {}
    end

    # Variant classes first, the caller's `class:` merged last, so tailwind_merge
    # resolves same-property conflicts in the caller's favour. The caller's value
    # takes any form Rails' `class:` does: a string, an array, or a conditional hash.
    def root_class
      MERGER.merge([variant_classes, caller_class].compact.join(' ')).presence
    end

    # Root-element attributes: `data-slot`, whatever the component supplies for its
    # own element, then the caller's forwarded attributes, then the merged class.
    # `data:`/`aria:` hashes merge by key so a component's own data attributes
    # survive alongside a caller's.
    def root_attributes(**component_attributes)
      attributes = merge_attributes(slot_attributes, normalize_attributes(component_attributes))
      attributes = merge_attributes(attributes, html_attributes)
      attributes.merge(class: root_class)
    end

    private

    def variant_classes
      self.class.variants&.render(**resolved_variant_values)
    end

    def resolved_variant_values
      variant_values.compact.to_h { |axis, value| [axis, resolve_variant(axis, value)] }.compact
    end

    # Matches by string form, so `"outline"` resolves to the declared `:outline`.
    def resolve_variant(axis, value)
      options = self.class.variant_options[axis]
      return value unless options

      match = options.find { |option| option.to_s == value.to_s }
      match.nil? ? unknown_variant(axis, value, options) : match
    end

    def unknown_variant(axis, value, options)
      message = "#{self.class.name} has no #{axis}: #{value.inspect}. Expected one of: #{options.map(&:inspect).join(', ')}."
      raise UnknownVariantError, message if self.class.raise_on_unknown_variant?

      Rails.logger&.warn("[rails_ui_kit] #{message} Rendering the default instead.")
      nil
    end

    def caller_class
      return if @caller_class.blank?

      # token_list HTML-escapes its output; it's unescaped here because the tag
      # helper that renders the class attribute escapes it again.
      CGI.unescape_html(token_list(@caller_class))
    end

    def slot_attributes
      slot = self.class.data_slot
      slot ? { data: { slot: slot } } : {}
    end

    # One canonical shape for attributes, whatever form the caller used, so the
    # merge below never emits a duplicate attribute: symbol keys, `data`/`aria`
    # as nested hashes (folding in flat `"data-foo"` keys), nested keys in
    # underscore form, and a nil `data:`/`aria:` treated as nothing passed.
    def normalize_attributes(attributes)
      attributes.each_with_object({}) do |(key, value), normalized|
        name = key.to_s
        if PREFIXED_ATTRIBUTES.include?(name)
          merge_prefixed(normalized, name, value) unless value.nil?
        elsif (flat = FLAT_PREFIXED_ATTRIBUTE.match(name))
          merge_prefixed(normalized, flat[1], { flat[2] => value })
        else
          normalized[name.to_sym] = value
        end
      end
    end

    def merge_prefixed(normalized, prefix, value)
      prefix = prefix.to_sym
      return normalized[prefix] = value unless value.is_a?(Hash)

      nested = normalized[prefix].is_a?(Hash) ? normalized[prefix] : {}
      normalized[prefix] = nested.merge(value.to_h { |key, nested_value| [key.to_s.tr('-', '_').to_sym, nested_value] })
    end

    def merge_attributes(own, other)
      own.merge(other) do |_key, mine, theirs|
        mine.is_a?(Hash) && theirs.is_a?(Hash) ? mine.merge(theirs) : theirs
      end
    end
  end
end
