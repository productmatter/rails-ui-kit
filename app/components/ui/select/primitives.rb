# frozen_string_literal: true

module Ui
  module Select
    # How Select composes the kit's primitives, as the data attributes its root, its control and
    # its search field carry. Select reimplements none of them (ui-select § Business rules,
    # rule 6), so its two modes differ here, in primitive values, rather than in behaviour of its
    # own: each mode's documented pattern (rule 4), written as configuration.
    class Primitives
      # A page of options is ten, which is what the APG select-only combobox example jumps.
      PAGE_STEP = 10

      # Where ui--overlay puts focus when search mode's popup opens.
      SEARCH_FIELD = "[data-ui--select-target='search']"

      def initialize(search:, native_on_touch:)
        @search = search
        @native_on_touch = native_on_touch
      end

      # The primitives Select composes.
      def root_data
        {
          controller: 'ui--select ui--overlay ui--anchor ui--roving-focus',
          action: 'change->ui--select#render ui--roving-focus:activated->ui--select#markActive ' \
                  'ui--overlay:opened->ui--select#opened ui--overlay:closed->ui--select#closed',
          'ui--select-search-value': search?,
          'ui--select-native-on-touch-value': @native_on_touch
        }.merge(popup_data, navigation_data)
      end

      # Select-only mode on a touch screen keeps the platform picker. Search mode always enhances,
      # because no native picker searches.
      def native_on_touch?
        !search? && @native_on_touch
      end

      # The control is pressable in both modes now — a div in one, a button in the other — so the
      # two modes ask for the same wiring here, and differ in the key table ui--select runs.
      def control_actions
        'keydown->ui--select#keydown click->ui--select#toggle'
      end

      # Search mode only. Bound to the field's own input event, so every way of editing it --
      # typing, pasting, cutting -- filters through one path.
      def search_actions
        'keydown->ui--select#keydown input->ui--select#filter'
      end

      private

      def search?
        @search
      end

      # A layer in the top layer, anchored under the control and matching its width, positioned
      # against the viewport because the top layer is. The two modes take the two halves of the
      # overlay's focus contract: select-only opens without moving focus, because its combobox
      # keeps DOM focus throughout; search mode opens onto the field in the popup and hands focus
      # back to the trigger when it closes (§ Behavior, items 17 and 24). Both are the overlay's
      # own values, not behaviour of Select's.
      def popup_data
        focus = search? ? { 'ui--overlay-initial-focus-value': SEARCH_FIELD } : {}
        {
          'ui--overlay-mode-value': 'layer',
          'ui--overlay-scroll-lock-value': false,
          'ui--overlay-move-focus-value': search?,
          'ui--anchor-placement-value': 'bottom-start',
          'ui--anchor-match-width-value': true,
          'ui--anchor-strategy-value': 'fixed'
        }.merge(focus)
      end

      # Each mode's key table, as primitive values: virtual focus either way, then select-only
      # clamps at the ends and owns typing and the page keys, while search mode wraps and leaves
      # every editing key to the field in its popup.
      def navigation_data
        {
          'ui--roving-focus-focus-model-value': 'activedescendant',
          'ui--roving-focus-loop-value': search?,
          'ui--roving-focus-typeahead-value': !search?,
          'ui--roving-focus-page-step-value': search? ? 0 : PAGE_STEP,
          'ui--roving-focus-active-class': 'bg-accent text-accent-foreground'
        }
      end
    end
  end
end
