# frozen_string_literal: true

module Ui
  # The twelve placements ui--anchor positions a floating element at, for the components that float
  # beside a trigger. A closed set: a string or a symbol, `:bottom_start` as well as `"bottom-start"`,
  # and an unknown one is handled the way Ui::Base handles an unknown variant.
  module Placement
    PLACEMENTS = %w[
      top top-start top-end
      bottom bottom-start bottom-end
      left left-start left-end
      right right-start right-end
    ].freeze

    private

    def resolve_placement(value, default)
      resolve_option(:placement, value.to_s.tr('_', '-'), PLACEMENTS, default)
    end
  end
end
