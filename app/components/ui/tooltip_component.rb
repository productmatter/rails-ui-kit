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
          controller: 'ui--tooltip',
          'ui--tooltip-placement-value': placement,
          'ui--tooltip-offset-value': offset,
          action: 'mouseenter->ui--tooltip#show mouseleave->ui--tooltip#hide focusin->ui--tooltip#show focusout->ui--tooltip#hide'
        }
      }
    end

    def tooltip_classes
      %w[
        absolute z-50 hidden opacity-0
        transition-opacity duration-100 ease-out
        px-2 py-1 text-xs font-medium rounded shadow-sm
        bg-neutral-900 text-white dark:bg-white dark:text-neutral-900
        pointer-events-none whitespace-nowrap
      ].join(' ')
    end
  end
end
