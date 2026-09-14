# frozen_string_literal: true

require 'rails/engine'
require 'class_variants'
require 'tailwind_merge'
require 'view_component'
require 'stimulus-rails'
require 'turbo-rails'
require 'rails_ui_kit/turbo_streams'

module RailsUiKit
  class Engine < ::Rails::Engine
    isolate_namespace RailsUiKit

    initializer 'rails_ui_kit.assets' do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join('app/assets/stylesheets').to_s
        app.config.assets.paths << root.join('app/javascript').to_s
      end
    end

    # turbo_stream.ui_close_modal. Turbo's own extension point for custom stream actions, so the
    # helper joins the tag builder without reopening a constant during boot.
    initializer 'rails_ui_kit.turbo_streams' do
      ActiveSupport.on_load(:turbo_streams_tag_builder) { include RailsUiKit::TurboStreams }
    end

    initializer 'rails_ui_kit.importmap', before: 'importmap' do |app|
      app.config.importmap.paths << root.join('config/importmap.rb') if defined?(Importmap::Engine) && app.config.respond_to?(:importmap)
    end
  end
end
