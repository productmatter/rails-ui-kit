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
          controller: 'ui--popover',
          'ui--popover-placement-value': placement,
          'ui--popover-offset-value': offset
        }
      }
    end

    def panel_wrapper_classes
      base = %w[
        absolute z-50 hidden
        opacity-0 scale-95
        transition duration-100 ease-out origin-top
        bg-white dark:bg-neutral-900
        border border-neutral-200 dark:border-neutral-700
        rounded-lg shadow-lg
      ]
      [base, panel_classes].flatten.compact.join(' ')
    end
  end
end
