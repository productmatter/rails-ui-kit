# frozen_string_literal: true

module Ui
  module Toast
    # Invalid input is loud where a developer can see it and safe where a user would
    # (ui-toast § Behavior, item 15). One predicate decides both, and it is the one Ui::Base
    # already uses for an unknown variant, so the kit has a single idea of "development".
    module Validation
      module_function

      def strict?
        Ui::Base.raise_on_unknown_variant?
      end

      # Raises in development and test. Elsewhere it logs and returns nil, and the caller applies
      # the safe rule for that key.
      def invalid!(message, error = InvalidPayloadError)
        raise error, message if strict?

        Rails.logger&.warn("[rails_ui_kit] #{message}")
        nil
      end
    end
  end
end
