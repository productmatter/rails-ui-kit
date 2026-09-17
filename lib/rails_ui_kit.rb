# frozen_string_literal: true

require 'rails_ui_kit/version'
require 'rails_ui_kit/engine'

module RailsUiKit
  # Warns about kit API kept for one release after its replacement ships. Registered with the host
  # app's deprecators, so config.active_support.deprecation decides where the warnings go.
  def self.deprecator
    @deprecator ||= ActiveSupport::Deprecation.new('0.4.0', 'rails_ui_kit')
  end
end
