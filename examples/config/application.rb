# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# ActiveModel's railtie, for the docs app's form objects (DemoTrip): it loads ActiveModel before
# I18n does, so validation messages translate. There is still no ActiveRecord and no database.
require 'active_model/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'

# :docs is the app's runtime (Puma, Propshaft, importmap, Turbo) in every environment; :assets is
# the Tailwind build, required in development and test, and in production only where assets are
# compiled (RAILS_GROUPS=assets in examples/Dockerfile's build stage). See the Gemfile.
Bundler.require(*Rails.groups(:docs, assets: %w[development test]))
require 'rails_ui_kit'

module Examples
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    # Production reads SECRET_KEY_BASE from the environment (examples/DEPLOY.md).
    config.secret_key_base = 'rails-ui-kit-examples' if Rails.env.local?
    config.hosts.clear

    # What a host app does: a locale with no translation for a key falls back to English rather
    # than rendering "translation missing". The docs app ships English and reads the kit's own
    # English chrome; the fixture locales the test suite loads translate part of it, which is
    # exactly the partial state a real app is in mid-translation.
    config.i18n.fallbacks = [:en]
  end
end
