# frozen_string_literal: true

module Ui
  # An inline loading indicator. role="status" carries the accessible name, and
  # the name comes from the block: it's rendered visually hidden, never as a
  # visible label, so a caller overrides the default "Loading" text without
  # changing what's drawn on screen.
  class SpinnerComponent < Ui::Base
    data_slot 'spinner'

    DEFAULT_LABEL = 'Loading'

    class_variants(base: 'inline-flex items-center justify-center text-foreground [:where(&>svg)]:size-4')

    def label
      content.presence || DEFAULT_LABEL
    end
  end
end
