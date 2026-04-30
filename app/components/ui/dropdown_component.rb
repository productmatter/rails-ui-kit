# frozen_string_literal: true

module Ui
  class DropdownComponent < ViewComponent::Base
    KINDS = %i[menu listbox dialog].freeze

    attr_reader :kind, :placement, :offset, :match_width, :content_classes

    renders_one :trigger
    renders_one :menu

    def initialize(kind: :menu, placement: 'bottom-start', offset: 4, match_width: false, content_classes: '')
      @kind = KINDS.include?(kind.to_sym) ? kind.to_sym : :menu
      @placement = placement
      @offset = offset
      @match_width = match_width
      @content_classes = content_classes
      super()
    end

    def controller_data
      {
        data: {
          controller: 'ui--dropdown',
          'ui--dropdown-kind-value': kind,
          'ui--dropdown-placement-value': placement,
          'ui--dropdown-offset-value': offset,
          'ui--dropdown-match-width-value': match_width
        }
      }
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
