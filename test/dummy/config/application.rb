# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'action_controller/railtie'
require 'action_view/railtie'

Bundler.require(*Rails.groups)
require 'rails_ui_kit'

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.secret_key_base = 'rails-ui-kit-dummy'
    config.hosts.clear
    config.logger = Logger.new(IO::NULL)
  end
end
