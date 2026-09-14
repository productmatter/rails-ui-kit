# frozen_string_literal: true

module Ui
  class PopoverComponent < ViewComponent::Base
    PLACEMENTS = %w[
      top top-start top-end
      bottom bottom-start bottom-end
      left left-start left-end
      right right-start right-end
    ].freeze

    attr_reader :placement, :offset, :panel_classes

    renders_one :trigger
    renders_one :panel

    def initialize(placement: 'bottom', offset: 8, panel_classes: '')
      @placement = PLACEMENTS.include?(placement) ? placement : 'bottom'
      @offset = offset
      @panel_classes = panel_classes
      super()
    end

    def controller_data
      {
        data: {
          controller: 'ui--popover ui--overlay ui--anchor',
          'ui--overlay-mode-value': 'layer',
          'ui--anchor-placement-value': placement,
          'ui--anchor-offset-value': offset,
          'ui--anchor-strategy-value': 'fixed'
        }
      }
    end

    def panel_wrapper_classes
      # The panel is a popover in the top layer, so the browser's popover defaults -- overflow
      # clipping and system colours -- are put back to what an in-flow panel inherits.
      base = %w[
        overflow-visible text-inherit outline-none
        transition duration-100 ease-out origin-top
        data-[state=closed]:opacity-0 data-[state=closed]:scale-95
        data-[state=closing]:opacity-0 data-[state=closing]:scale-95
        bg-white dark:bg-neutral-900
        border border-neutral-200 dark:border-neutral-700
        rounded-lg shadow-lg
      ]
      [base, panel_classes].flatten.compact.join(' ')
    end
  end
end
