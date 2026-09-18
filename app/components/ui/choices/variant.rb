# frozen_string_literal: true

module Ui
  module Choices
    # What one choice looks like, as the two class lists it needs: the label that wraps the
    # input, and the input that draws the indicator (ui-choices § Behavior, items 15–17). Held
    # apart from the component the way Ui::Select::Primitives is, so the component stays about
    # names, values and wiring, and every state here is CSS reading a real input.
    class Variant
      # `size:` is accepted, so a form can hand every control one size, and changes nothing here
      # (ui-choices § Behavior, item 17, decided 2026-09-18). A list row is sized by its content,
      # and a card's padding plus one line of text was always taller than the largest step's
      # minimum, so a step never bound and the option never did anything visible. The keys are
      # what validates the keyword; they carry no classes.
      SIZES = { sm: nil, default: nil, lg: nil }.freeze

      # Every choice, row or card: WCAG 2.5.8's target size. A one-line list row centers its
      # indicator on it; a row with a description stays top-aligned so the indicator sits on the
      # first line of text.
      MIN_HEIGHT = 'min-h-6'

      CHOICE = 'relative flex gap-3 text-sm has-disabled:cursor-not-allowed'

      # A card is a control too: the same boundary and fill, with the checked, focused and
      # disabled states read from the input inside it. The invalid border has to beat the checked
      # one, and `has-checked:` is emitted after `group-aria-invalid/choices:` at equal
      # specificity, so the invalid rule for a checked card is written as the compound selector.
      CARD = 'rounded-md border border-input bg-background dark:bg-muted/50 p-3 shadow-xs transition-colors ' \
             'has-checked:border-primary ' \
             'has-focus-visible:border-ring has-focus-visible:outline-2 has-focus-visible:outline-ring ' \
             'has-disabled:opacity-50 ' \
             'group-aria-invalid/choices:border-destructive ' \
             'group-aria-invalid/choices:has-checked:border-destructive ' \
             'group-aria-invalid/choices:has-focus-visible:border-destructive ' \
             'group-aria-invalid/choices:has-focus-visible:outline-destructive'

      LIST = 'has-disabled:opacity-50'

      VARIANTS = { list: LIST, card: CARD }.freeze

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

      def initialize(variant:, multiple:, described:)
        @variant = variant
        @multiple = multiple
        @described = described
      end

      def choice_class
        [CHOICE, align_class, MIN_HEIGHT, VARIANTS[@variant]].join(' ')
      end

      def input_class
        [INPUT, @multiple ? 'rounded-sm' : 'rounded-full',
         @variant == :card ? CARD_INPUT : LIST_INPUT].join(' ')
      end

      def mark
        MARKS[@multiple ? :checkbox : :radio]
      end

      private

      # A card keeps items-start regardless of description, the way it always has. A list row
      # centers a one-line choice on its 24px floor, and stays top-aligned once a description
      # puts a second line under the text -- not items-baseline: the indicator sits inside a
      # `flex h-5 items-center` wrapper matching text-sm's line height, so items-start already
      # centers it on the first line, which is what items-baseline would otherwise be reaching
      # for by way of the wrapper's synthesized baseline.
      def align_class
        @variant == :card || @described ? 'items-start' : 'items-center'
      end
    end
  end
end
