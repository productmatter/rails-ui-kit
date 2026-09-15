# frozen_string_literal: true

module Ui
  module Toast
    # The URL rule for any href a payload carries (ui-toast § Behavior, item 9): a relative
    # reference, or an absolute http(s) URL. toast_container_controller.js implements the same
    # steps, and both run the vectors in test/fixtures/toast_href_vectors.json.
    module Href
      # What the WHATWG URL parser strips before it reads a scheme: leading and trailing C0
      # controls and spaces, and every tab and newline anywhere.
      EDGE_CONTROLS = /\A[\x00-\x20]+|[\x00-\x20]+\z/
      TAB_OR_NEWLINE = /[\t\n\r]/
      SCHEME = /\A[A-Za-z][A-Za-z0-9+.-]*:/
      ALLOWED_SCHEMES = %w[http: https:].freeze

      module_function

      def allowed?(href)
        return false unless href.is_a?(String)

        cleaned = href.gsub(EDGE_CONTROLS, '').gsub(TAB_OR_NEWLINE, '')
        return false if cleaned.empty?

        scheme = cleaned[SCHEME]
        scheme.nil? || ALLOWED_SCHEMES.include?(scheme.downcase)
      end
    end
  end
end
