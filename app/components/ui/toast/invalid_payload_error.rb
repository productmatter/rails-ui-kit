# frozen_string_literal: true

module Ui
  module Toast
    # Raised in development and test for a toast payload that breaks a rule: the message names
    # the key and the fix.
    class InvalidPayloadError < ArgumentError; end
  end
end
