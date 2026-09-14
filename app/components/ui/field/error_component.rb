# frozen_string_literal: true

module Ui
  module Field
    # No live-region role: server-rendered errors are already on the page when it
    # loads, and a role on every one of them would announce the whole form on arrival.
    # A Turbo Stream that replaces a single field can pass `role: "alert"` itself,
    # through attribute forwarding.
    class ErrorComponent < Ui::Base
      data_slot 'field-error'

      class_variants(base: 'text-sm text-destructive')

      def call
        content_tag(:p, content, root_attributes)
      end
    end
  end
end
