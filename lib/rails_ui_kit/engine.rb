# frozen_string_literal: true

require 'rails/engine'
require 'view_component'
require 'stimulus-rails'
require 'turbo-rails'

module RailsUiKit
  class Engine < ::Rails::Engine
    isolate_namespace RailsUiKit

    initializer 'rails_ui_kit.assets' do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join('app/assets/stylesheets').to_s
        app.config.assets.paths << root.join('app/javascript').to_s
      end
    end

    initializer 'rails_ui_kit.importmap', before: 'importmap' do |app|
      app.config.importmap.paths << root.join('config/importmap.rb') if defined?(Importmap) && app.config.respond_to?(:importmap)
    end
  end
end
