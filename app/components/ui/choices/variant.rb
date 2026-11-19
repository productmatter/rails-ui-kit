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
      # and a card's padding plus one line of text was always taller than the largest step of the
      # day, so a step never bound and the option never did anything visible. The keys are
      # what validates the keyword; they carry no classes.
      SIZES = { xs: nil, sm: nil, default: nil, lg: nil, xl: nil, '2xl': nil }.freeze

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

      # The two compact appearances draw no indicator: the input is visually hidden inside the label
      # (still focused, still what arrows, Space and submission act on) and the label itself is the
      # control. Every state is still CSS reading that input. Checked is never colour alone: it
      # changes the boundary's weight, and in forced colours takes Highlight, the system's own
      # "selected".
      #
      # Segmented: one row of radios in a sunken track, the checked one raised onto the page's fill.
      SEGMENT = 'flex h-full min-w-0 cursor-pointer items-center justify-center gap-1.5 whitespace-nowrap ' \
                'font-medium text-muted-foreground transition-colors hover:text-foreground ' \
                'has-checked:bg-background has-checked:text-foreground has-checked:shadow-xs ' \
                'has-checked:outline has-checked:-outline-offset-1 has-checked:outline-border ' \
                'forced-colors:has-checked:outline-2 forced-colors:has-checked:outline-[Highlight] ' \
                'has-focus-visible:outline-2 has-focus-visible:-outline-offset-2 has-focus-visible:outline-ring ' \
                'has-disabled:cursor-not-allowed has-disabled:opacity-50 has-disabled:hover:text-muted-foreground'

      # Chips: a control's boundary and fill each, with a leading mark, the text and a count. Checked
      # takes --primary as a doubled boundary (border plus an inset line) over --accent.
      CHIP = 'flex min-w-0 cursor-pointer items-center gap-1.5 whitespace-nowrap border border-input ' \
             'bg-background dark:bg-muted/50 font-medium text-foreground shadow-xs transition-colors hover:bg-accent ' \
             'has-checked:border-primary has-checked:bg-accent has-checked:inset-ring has-checked:inset-ring-primary ' \
             'forced-colors:has-checked:border-[Highlight] ' \
             'has-focus-visible:border-ring has-focus-visible:outline-2 has-focus-visible:outline-ring ' \
             'has-disabled:cursor-not-allowed has-disabled:opacity-50 has-disabled:hover:bg-background ' \
             'group-aria-invalid/choices:border-destructive group-aria-invalid/choices:has-focus-visible:outline-destructive'

      VARIANTS = { list: LIST, card: CARD, segmented: SEGMENT, chips: CHIP }.freeze

      # The compact appearances, which hide the input and are sized from the control scale.
      COMPACT = %i[segmented chips].freeze

      # The root each compact appearance needs instead of the stacking grid: a track for segments, a
      # wrapping row for chips. Merged over the component's base, so a caller's `class:` -- columns,
      # say -- still wins (tailwind_merge resolves `flex` against a caller's `grid`).
      ROOTS = {
        segmented: 'inline-flex w-fit max-w-full items-stretch gap-0.5 border border-border bg-muted p-0.5 ' \
                   'aria-invalid:border-destructive',
        chips: 'flex flex-wrap gap-1.5'
      }.freeze

      # The control scale's steps, for the compact appearances only (list and card ignore `size:`,
      # item 17). Segmented sizes the track, so the whole control is one control height, as a Button
      # at that step is; chips size each chip. Height, inline padding, text size and radius move
      # together, read from the same tokens as Button, Input and Select.
      COMPACT_SIZES = {
        segmented: {
          xs: { root: 'h-(--control-height-xs) rounded-sm', choice: 'px-1.5 text-xs rounded-xs' },
          sm: { root: 'h-(--control-height-sm) rounded-sm', choice: 'px-2 text-xs rounded-xs' },
          default: { root: 'h-(--control-height) rounded-md', choice: 'px-2.5 text-sm rounded-sm' },
          lg: { root: 'h-(--control-height-lg) rounded-md', choice: 'px-3 text-sm rounded-sm' },
          xl: { root: 'h-(--control-height-xl) rounded-md', choice: 'px-3.5 text-sm rounded-sm' },
          '2xl': { root: 'h-(--control-height-2xl) rounded-md', choice: 'px-3.5 text-base rounded-sm' }
        },
        chips: {
          xs: { choice: 'h-(--control-height-xs) px-1.5 text-xs rounded-sm' },
          sm: { choice: 'h-(--control-height-sm) px-2 text-xs rounded-sm' },
          default: { choice: 'h-(--control-height) px-2.5 text-sm rounded-md' },
          lg: { choice: 'h-(--control-height-lg) px-3 text-sm rounded-md' },
          xl: { choice: 'h-(--control-height-xl) px-3.5 text-sm rounded-md' },
          '2xl': { choice: 'h-(--control-height-2xl) px-3.5 text-base rounded-md' }
        }
      }.freeze

      # Visually hidden, never `display: none`: the input is still what focus lands on and what a
      # screen reader, the arrow keys and the form act on.
      COMPACT_INPUT = 'peer sr-only'

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

      def initialize(variant:, multiple:, described:, size: :default)
        @variant = variant
        @multiple = multiple
        @described = described
        @size = size
      end

      # A segmented control is one choice of several, by definition; a segment and a chip have no
      # line under the text for a description; and only a chip has somewhere to put a count. Each is
      # a caller error rather than a silent half-rendering.
      def validate!(component:, description:, count:)
        raise ArgumentError, "#{component}: variant: :segmented is one choice of several — use variant: :chips with multiple: true for toggles." if @variant == :segmented && @multiple
        raise ArgumentError, "#{component}: variant: :#{@variant} has no description line, so description_method: has nowhere to go." if compact? && description
        return unless count && @variant != :chips

        raise ArgumentError, "#{component}: count_method: is for variant: :chips, the one appearance with a count."
      end

      # Whether the input is hidden and the label is the control: segmented and chips.
      def compact?
        COMPACT.include?(@variant)
      end

      # The root's own classes, merged over the component's base; nil for list and card.
      def root_class
        return unless compact?

        [ROOTS[@variant], compact_size[:root]].compact.join(' ')
      end

      def choice_class
        return [VARIANTS[@variant], compact_size[:choice]].join(' ') if compact?

        [CHOICE, align_class, MIN_HEIGHT, VARIANTS[@variant]].join(' ')
      end

      def input_class
        return COMPACT_INPUT if compact?

        [INPUT, @multiple ? 'rounded-sm' : 'rounded-full',
         @variant == :card ? CARD_INPUT : LIST_INPUT].join(' ')
      end

      def mark
        MARKS[@multiple ? :checkbox : :radio]
      end

      private

      def compact_size
        COMPACT_SIZES.dig(@variant, @size) || {}
      end

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
