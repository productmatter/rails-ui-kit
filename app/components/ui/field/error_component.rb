# frozen_string_literal: true

module Ui
  module Field
    # No live-region role on a server-rendered error: it is already on the page when the page
    # or frame arrives, and a role on every one would announce the whole form on arrival. An
    # error that a morph reveals is different, and ui--field gives it role="alert" as it
    # enters.
    class ErrorComponent < Ui::Base
      # The swap's fade, shared with the description. Presence waits on this transition; under
      # reduced motion there is none, and presence doesn't wait either.
      SWAP_CLASSES = 'transition-opacity duration-150 ease-out motion-reduce:transition-none ' \
                     'data-[state=closed]:opacity-0 data-[state=closing]:opacity-0'

      data_slot 'field-error'

      class_variants(base: "text-sm text-destructive #{SWAP_CLASSES}")

      def call
        content_tag(:p, content, root_attributes)
      end
    end
  end
end
