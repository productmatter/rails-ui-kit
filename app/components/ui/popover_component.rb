# frozen_string_literal: true

module Ui
  class PopoverComponent < Ui::Base
    include Ui::Placement

    data_slot 'popover'

    # The panel is a popover in the top layer, so the browser's popover defaults -- overflow
    # clipping and system colours -- are put back to what an in-flow panel inherits.
    PANEL_CLASSES = %w[
      overflow-visible text-inherit outline-none
      transition duration-100 ease-out origin-top
      data-[state=closed]:opacity-0 data-[state=closed]:scale-95
      data-[state=closing]:opacity-0 data-[state=closing]:scale-95
      bg-popover border rounded-lg shadow-lg
    ].join(' ').freeze

    attr_reader :placement, :offset

    renders_one :trigger

    # popover.with_panel(class: 'w-64 p-4') { ... } -- the classes merge over the panel's own.
    renders_one :panel, lambda { |**options, &block|
      options.assert_valid_keys(:class)
      @panel_class = options[:class]
      block&.call
    }

    # panel_classes: is kept for one release, merged the way with_panel(class:) is.
    def initialize(placement: 'bottom', offset: 8, panel_classes: nil, **html_attributes)
      @placement = resolve_placement(placement, 'bottom')
      @offset = offset
      @panel_classes = deprecated_class_keyword(:panel_classes, panel_classes, 'with_panel(class: ...)')
      super(**html_attributes)
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
      MERGER.merge([PANEL_CLASSES, @panel_classes, token_list(@panel_class)].compact_blank.join(' '))
    end
  end
end
