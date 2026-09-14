# frozen_string_literal: true

module Ui
  class DropdownComponent < ViewComponent::Base
    KINDS = %i[menu listbox dialog].freeze

    # kind: :listbox shipped on main (0.2.0), so a consumer outside this repository may still
    # render it: it keeps working, and says once per process what replaces it. It has no
    # selection model, and it moves real DOM focus onto [role="option"] elements, which is the
    # one focus model a listbox must never use (ui-select § Behavior, item 36). Removed in the
    # release after the one that ships Ui::SelectComponent.
    LISTBOX_DEPRECATION = '[rails_ui_kit] Ui::DropdownComponent(kind: :listbox) is deprecated and will be ' \
                          'removed in the next minor release. Use Ui::SelectComponent, which keeps the value in a ' \
                          'real <select> and follows the WAI-ARIA combobox focus model.'

    class << self
      attr_accessor :listbox_deprecation_warned
    end

    attr_reader :kind, :placement, :offset, :match_width, :content_classes, :label

    renders_one :trigger
    renders_one :menu

    def initialize(kind: :menu, placement: 'bottom-start', offset: 4, match_width: false, content_classes: '', label: nil)
      @kind = KINDS.include?(kind.to_sym) ? kind.to_sym : :menu
      warn_listbox_deprecation if @kind == :listbox
      @placement = placement
      @offset = offset
      @match_width = match_width
      @content_classes = content_classes
      @label = label
      super()
    end

    def warn_listbox_deprecation
      return if self.class.listbox_deprecation_warned

      self.class.listbox_deprecation_warned = true
      Kernel.warn(LISTBOX_DEPRECATION)
      Rails.logger&.warn(LISTBOX_DEPRECATION)
    end

    def controller_data
      {
        data: {
          controller: 'ui--dropdown ui--anchor',
          'ui--dropdown-kind-value': kind,
          'ui--anchor-placement-value': placement,
          'ui--anchor-offset-value': offset,
          'ui--anchor-match-width-value': match_width
        }
      }
    end

    # A menu's arrows, Home, End and typeahead are ui--roving-focus's; the listbox and dialog
    # kinds keep the controller's own handling.
    def content_data
      data = { 'ui--dropdown-target': 'content', 'ui--anchor-target': 'floating' }
      return data unless kind == :menu

      data.merge(controller: 'ui--roving-focus', 'ui--roving-focus-typeahead-value': true)
    end

    def content_wrapper_classes
      base_classes = %w[
        hidden absolute z-50
        opacity-0 scale-95
        transition duration-100 ease-out origin-top
      ]

      [base_classes, content_classes].flatten.compact.join(' ')
    end
  end
end
