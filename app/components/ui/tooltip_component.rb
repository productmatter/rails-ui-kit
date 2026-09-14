# frozen_string_literal: true

module Ui
  class TooltipComponent < ViewComponent::Base
    PLACEMENTS = %w[
      top top-start top-end
      bottom bottom-start bottom-end
      left left-start left-end
      right right-start right-end
    ].freeze

    attr_reader :text, :placement, :offset

    renders_one :trigger

    def initialize(text:, placement: 'top', offset: 6)
      @text = text
      @placement = PLACEMENTS.include?(placement) ? placement : 'top'
      @offset = offset
      super()
    end

    def controller_data
      {
        data: {
          controller: 'ui--tooltip ui--overlay ui--anchor',
          'ui--overlay-mode-value': 'hint',
          'ui--overlay-restore-focus-value': false,
          'ui--anchor-placement-value': placement,
          'ui--anchor-offset-value': offset,
          'ui--anchor-strategy-value': 'fixed'
        }
      }
    end

    def tooltip_classes
      # A popover in the top layer: overflow-visible keeps the browser's popover default from
      # clipping the arrow.
      %w[
        overflow-visible
        transition-opacity duration-100 ease-out
        data-[state=closed]:opacity-0 data-[state=closing]:opacity-0
        px-2 py-1 text-xs font-medium rounded shadow-sm
        bg-neutral-900 text-white dark:bg-white dark:text-neutral-900
        max-w-xs text-pretty
      ].join(' ')
    end
  end
end
