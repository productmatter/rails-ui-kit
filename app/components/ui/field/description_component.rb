# frozen_string_literal: true

module Ui
  module Field
    # Fades on data-state, which ui--field sets through the presence primitive when a morph
    # swaps the description and the error. Nothing sets data-state on a static render.
    #
    # `field:` is what defers the counter's text and over-limit state to render time, the same
    # way Ui::Field::LabelComponent defers the required marker: renders_one's lambda constructs
    # this component the instant with_description is called, which can be before with_control
    # sets the counter Field would otherwise have to ask about right now. Reading `@field.*`
    # only inside `call`, never in `initialize`, is what makes the order the caller sets Field's
    # parts in not matter (ui-character-counter § Behavior, item 4).
    class DescriptionComponent < Ui::Base
      data_slot 'field-description'

      # The flex row only applies with a count to share the line with: flexbox already puts the
      # second child at the inline-end in either writing direction, so no logical utility is
      # needed beyond it (ui-character-counter § Behavior, item 13).
      class_variants(
        base: "text-sm text-muted-foreground #{Ui::Field::ErrorComponent::SWAP_CLASSES}",
        variants: { counter: 'flex items-baseline justify-between gap-2' }
      )

      def initialize(field: nil, **attributes)
        @field = field
        super(**attributes)
      end

      def call
        content_tag(:p, safe_join([body, counter_span].compact), root_attributes)
      end

      def variant_values
        { counter: counter? }
      end

      private

      def counter?
        @field&.counter? == true
      end

      # The help text grows and the count never wraps off it, wrapped only when there is a
      # count to share the line with: a plain description keeps rendering exactly as it did
      # before this scope.
      def body
        return content unless counter?
        return if content.blank?

        tag.span(content, class: 'min-w-0 grow')
      end

      # `shrink-0` and `tabular-nums` so digits don't jostle the line as they change width, in
      # `text-muted-foreground` unless the count is over the limit, when nothing else changes
      # (ui-character-counter § Behavior, item 9). `data-ui--character-count-target="count"` is
      # what ui--character-count recounts into on every input, form reset and connect.
      def counter_span
        return unless counter?

        over = @field.character_over_limit?
        tag.span(@field.counter_text, class: counter_classes(over),
                                      data: { over: (true if over), 'ui--character-count-target': 'count' }.compact)
      end

      def counter_classes(over)
        MERGER.merge(['shrink-0 tabular-nums', over ? 'text-destructive' : 'text-muted-foreground'].join(' '))
      end
    end
  end
end
