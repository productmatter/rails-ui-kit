# frozen_string_literal: true

module Ui
  class DropdownComponent < Ui::Base
    include Ui::Placement

    KINDS = %i[menu dialog].freeze

    data_slot 'dropdown'

    # The panel is a popover in the top layer, so the browser's popover defaults -- overflow
    # clipping and system colours -- are replaced by the kit's surface, the one Popover's panel wears.
    PANEL_CLASSES = %w[
      overflow-visible text-inherit outline-none
      transition duration-100 ease-out origin-top
      data-[state=closed]:opacity-0 data-[state=closed]:scale-95
      data-[state=closing]:opacity-0 data-[state=closing]:scale-95
      bg-popover border rounded-md shadow-lg
    ].join(' ').freeze

    attr_reader :kind, :placement, :offset, :match_width, :label

    renders_one :trigger

    # dropdown.with_panel(class: 'min-w-48') { ... } -- the classes merge over the panel's own.
    renders_one :panel, lambda { |**options, &block|
      options.assert_valid_keys(:class)
      @panel_class = options[:class]
      block&.call
    }

    # content_classes: is kept for one release, merged the way with_panel(class:) is.
    def initialize(kind: :menu, placement: 'bottom-start', offset: 4, match_width: false, content_classes: nil, label: nil,
                   **html_attributes)
      @kind = resolve_option(:kind, kind, KINDS, :menu)
      @placement = resolve_placement(placement, 'bottom-start')
      @offset = offset
      @match_width = match_width
      @content_classes = deprecated_class_keyword(:content_classes, content_classes, 'with_panel(class: ...)')
      @label = label
      super(**html_attributes)
    end

    # The slot was called menu until it held dialogs too; kept for one release.
    def with_menu(...)
      RailsUiKit.deprecator.warn("#{self.class.name}#with_menu is deprecated; call with_panel instead, which takes the same block and class:.")
      with_panel(...)
    end

    # ui--overlay, in layer mode, opens and closes the panel and its events are Dropdown's. Focus on
    # open is Dropdown's own -- a menu's first or last item -- so the overlay doesn't move it.
    def controller_data
      {
        data: {
          controller: 'ui--dropdown ui--overlay ui--anchor',
          'ui--dropdown-kind-value': kind,
          'ui--overlay-mode-value': 'layer',
          'ui--overlay-move-focus-value': false,
          'ui--anchor-placement-value': placement,
          'ui--anchor-offset-value': offset,
          'ui--anchor-match-width-value': match_width,
          'ui--anchor-strategy-value': 'fixed'
        }
      }
    end

    # A menu's arrows, Home, End and typeahead are ui--roving-focus's.
    def panel_data
      data = { slot: 'dropdown-panel', 'ui--dropdown-target': 'content', 'ui--overlay-target': 'content', 'ui--anchor-target': 'floating' }
      return data unless kind == :menu

      data.merge(controller: 'ui--roving-focus', 'ui--roving-focus-typeahead-value': true)
    end

    def panel_wrapper_classes
      MERGER.merge([PANEL_CLASSES, @content_classes, token_list(@panel_class)].compact_blank.join(' '))
    end
  end
end
