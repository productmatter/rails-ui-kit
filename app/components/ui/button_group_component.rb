# frozen_string_literal: true

module Ui
  # role="group" around a call-ordered mix of buttons, separators and text chips.
  # Children render through the actual Ui::ButtonComponent and Ui::SeparatorComponent
  # -- reused, not copied (rule 1) -- so a polymorphic renders_many is what keeps
  # them in call order across the three kinds (rule 3), the same reason Table rows
  # and Breadcrumb items use it. Adjoining buttons/text share one border: only the
  # first and last corners round, and each item after the first overlaps its
  # neighbour's border by a hairline so the shared edge isn't twice as thick.
  # Selectors key off `[data-slot^=button]`, which matches both "button" and
  # "button-group-text" -- not "separator", which keeps its own full-bleed bar.
  class ButtonGroupComponent < Ui::Base
    data_slot 'button-group'

    class_variants(
      base: 'inline-flex w-fit items-stretch ' \
            '[&>[data-slot^=button]]:rounded-none ' \
            '[&>[data-slot^=button]]:focus-visible:relative [&>[data-slot^=button]]:focus-visible:z-10',
      variants: {
        orientation: {
          horizontal: 'flex-row ' \
                      '[&>[data-slot^=button]:first-child]:rounded-l-md [&>[data-slot^=button]:last-child]:rounded-r-md ' \
                      '[&>[data-slot^=button]:not(:first-child)]:-ml-px',
          vertical: 'flex-col ' \
                    '[&>[data-slot^=button]:first-child]:rounded-t-md [&>[data-slot^=button]:last-child]:rounded-b-md ' \
                    '[&>[data-slot^=button]:not(:first-child)]:-mt-px'
        }
      },
      defaults: { orientation: :horizontal }
    )

    attr_reader :orientation

    renders_many :items, types: {
      button: Ui::ButtonComponent,
      separator: Ui::SeparatorComponent,
      text: Ui::ButtonGroup::TextComponent
    }

    # `orientation:` accepts a symbol or string; nil means the default.
    def initialize(orientation: :horizontal, **html_attributes)
      @orientation = orientation
      super(**html_attributes)
    end

    def variant_values
      { orientation: orientation }
    end

    def element_attributes
      { role: 'group' }
    end
  end
end
