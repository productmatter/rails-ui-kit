# frozen_string_literal: true

module Ui
  class TooltipComponent < Ui::Base
    include Ui::Placement

    data_slot 'tooltip'

    # A popover in the top layer: overflow-visible keeps the browser's popover default from
    # clipping the arrow. A tooltip inverts the page's colours, so it reads as foreground on background.
    TOOLTIP_CLASSES = %w[
      overflow-visible
      transition-opacity duration-100 ease-out
      data-[state=closed]:opacity-0 data-[state=closing]:opacity-0
      px-2 py-1 text-xs font-medium rounded shadow-sm
      bg-foreground text-background
      max-w-xs text-pretty
    ].join(' ').freeze

    ARROW_CLASSES = 'absolute h-2 w-2 rotate-45 bg-foreground'

    attr_reader :text, :placement, :offset

    renders_one :trigger

    def initialize(text:, placement: 'top', offset: 6, **html_attributes)
      @text = text
      @placement = resolve_placement(placement, 'top')
      @offset = offset
      super(**html_attributes)
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
  end
end
