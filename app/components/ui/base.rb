# frozen_string_literal: true

module Ui
  # Shared foundation for every kit component: the class_variants variant layer,
  # the tailwind_merge class-merge layer that makes a caller's `class:` win, generic
  # HTML attribute forwarding, and the `data-slot` styling hook.
  class Base < ViewComponent::Base
    # One merger per process. Its LRU cache is thread-safe and is what keeps
    # repeated renders from re-parsing the same class lists.
    MERGER = TailwindMerge::Merger.new

    class << self
      # Declares the component's variant axes. Arguments are handed to
      # ClassVariants.build verbatim: base:, variants:, compound_variants:, defaults:.
      def class_variants(**definition)
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

      private

      def inherited_setting(name)
        superclass.respond_to?(name) ? superclass.public_send(name) : nil
      end
    end

    attr_reader :html_attributes

    # Every keyword a component does not name for itself lands here and is
    # forwarded to the root element; `class:` is pulled out for the merge step.
    def initialize(**html_attributes)
      @caller_class = html_attributes.delete(:class)
      @html_attributes = html_attributes
      super()
    end

    # The variant values this component resolves its class list from. Components
    # with variant axes override it; components without any inherit the empty hash.
    def variant_values
      {}
    end

    # Variant classes first, the caller's `class:` merged last, so tailwind_merge
    # resolves same-property conflicts in the caller's favour.
    def root_class
      MERGER.merge([variant_classes, @caller_class].compact.join(' ')).presence
    end

    # Root-element attributes: `data-slot`, whatever the component supplies for its
    # own element, then the caller's forwarded attributes, then the merged class.
    # `data:`/`aria:` hashes merge by key so a component's own data attributes
    # survive alongside a caller's.
    def root_attributes(**component_attributes)
      attributes = merge_attributes(slot_attributes, component_attributes)
      attributes = merge_attributes(attributes, html_attributes)
      attributes.merge(class: root_class)
    end

    private

    def variant_classes
      self.class.variants&.render(**variant_values.compact)
    end

    def slot_attributes
      slot = self.class.data_slot
      slot ? { data: { slot: slot } } : {}
    end

    def merge_attributes(own, other)
      own.merge(other) do |_key, mine, theirs|
        mine.is_a?(Hash) && theirs.is_a?(Hash) ? mine.merge(theirs) : theirs
      end
    end
  end
end
