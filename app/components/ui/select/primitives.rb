# frozen_string_literal: true

module Ui
  module Select
    # How Select composes the kit's primitives, as the data attributes its root and combobox
    # carry. Select reimplements none of them (ui-select § Business rules, rule 6), so its two
    # modes differ here, in primitive values, rather than in behaviour of its own: each mode's
    # APG example (rule 4), written as configuration.
    class Primitives
      # A page of options is ten, which is what the APG select-only combobox example jumps.
      PAGE_STEP = 10

      def initialize(search:, native_on_touch:)
        @search = search
        @native_on_touch = native_on_touch
      end

      # The primitives Select composes. ui--media-query is what tells select-only mode it is on a
      # touch screen, where the platform picker is the better control.
      def root_data
        {
          controller: 'ui--media-query ui--select ui--overlay ui--anchor ui--roving-focus',
          action: 'change->ui--select#render ui--roving-focus:activated->ui--select#markActive ' \
                  'ui--overlay:opened->ui--select#opened ui--overlay:closed->ui--select#closed',
          'ui--media-query-query-value': '(pointer: coarse)',
          'ui--select-search-value': search?,
          'ui--select-native-on-touch-value': @native_on_touch,
          # The count is only known once the filter runs, so the plural forms go over as strings
          # and ui--select picks one. Locales with more plural categories than these two need the
          # host to override the strings themselves.
          'ui--select-results-one-value': I18n.t('rails_ui_kit.select.results.one'),
          'ui--select-results-other-value': I18n.t('rails_ui_kit.select.results.other')
        }.merge(popup_data, navigation_data)
      end

      def combobox_actions
        actions = ['keydown->ui--select#keydown']
        # A text field opens on typing rather than on a click, so a caret placed in it doesn't
        # reopen the list the user just closed.
        actions << (search? ? 'input->ui--select#filter' : 'click->ui--select#toggle')
        actions.join(' ')
      end

      private

      def search?
        @search
      end

      # A layer in the top layer, anchored under the control and matching its width. It opens
      # without taking focus, because a combobox keeps DOM focus on its own control, and it is
      # positioned against the viewport, because the top layer is.
      def popup_data
        {
          'ui--overlay-mode-value': 'layer',
          'ui--overlay-scroll-lock-value': false,
          'ui--overlay-move-focus-value': false,
          'ui--anchor-placement-value': 'bottom-start',
          'ui--anchor-match-width-value': true,
          'ui--anchor-strategy-value': 'fixed'
        }
      end

      # Each mode's APG example, as primitive values: virtual focus either way, then select-only
      # clamps at the ends and owns typing and the page keys, while search mode wraps and leaves
      # every editing key to its text field.
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
