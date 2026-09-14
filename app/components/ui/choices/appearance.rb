# frozen_string_literal: true

module Ui
  module Choices
    # What one choice looks like, as the two class lists it needs: the label that wraps the
    # input, and the input that draws the indicator (ui-choices § Behavior, items 15–17). Held
    # apart from the component the way Ui::Select::Primitives is, so the component stays about
    # names, values and wiring, and every state here is CSS reading a real input.
    class Appearance
      # The step's own token, as a minimum: a one-line choice lines up with the Input or Select
      # beside it, and content is free to make it taller (ui-control-sizing).
      SIZES = {
        sm: 'min-h-(--control-height-sm)', default: 'min-h-(--control-height)', lg: 'min-h-(--control-height-lg)'
      }.freeze

      CHOICE = 'relative flex items-start gap-3 text-sm has-disabled:cursor-not-allowed'

      # A card is a control too: the same boundary and fill, with the checked, focused and
      # disabled states read from the input inside it. The invalid border has to beat the checked
      # one, and `has-checked:` is emitted after `group-aria-invalid/choices:` at equal
      # specificity, so the invalid rule for a checked card is written as the compound selector.
      CARD = 'rounded-md border border-input bg-background dark:bg-muted/50 p-3 shadow-xs transition-colors ' \
             'has-checked:border-primary ' \
             'has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-ring ' \
             'has-disabled:opacity-50 ' \
             'group-aria-invalid/choices:border-destructive ' \
             'group-aria-invalid/choices:has-checked:border-destructive ' \
             'group-aria-invalid/choices:has-focus-visible:outline-destructive'

      LIST = 'has-disabled:opacity-50'

      APPEARANCES = { list: LIST, card: CARD }.freeze

      # The indicator is the control, so it takes the control boundary and the control fill
      # (ui-presentational-components, rule 6(a)) and never a transparent background. `checked:`
      # fills it with --primary; the mark inside is drawn in --primary-foreground.
      INPUT = 'peer size-4 shrink-0 appearance-none border border-input bg-background dark:bg-muted/50 ' \
              'shadow-xs transition-colors checked:border-primary checked:bg-primary ' \
              'disabled:cursor-not-allowed group-aria-invalid/choices:border-destructive'

      LIST_INPUT = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring ' \
                   'group-aria-invalid/choices:focus-visible:outline-destructive'

      # In a card the ring belongs to the card, which is what the user sees as the control, so
      # the input's own outline is suppressed here and only here.
      CARD_INPUT = 'focus-visible:outline-none'

      # A tick for a checkbox, a dot for a radio -- both drawn as a stroke, so forced colours
      # turn them into CanvasText instead of losing them with the fill.
      MARKS = { checkbox: { path: 'm4 12 5 5L20 6', width: 3 }, radio: { path: 'M12 12h.01', width: 9 } }.freeze

      def initialize(appearance:, size:, multiple:)
        @appearance = appearance
        @size = size
        @multiple = multiple
      end

      def choice_class
        [CHOICE, SIZES[@size], APPEARANCES[@appearance]].join(' ')
      end

      def input_class
        [INPUT, @multiple ? 'rounded-sm' : 'rounded-full',
         @appearance == :card ? CARD_INPUT : LIST_INPUT].join(' ')
      end

      def mark
        MARKS[@multiple ? :checkbox : :radio]
      end
    end
  end
end
