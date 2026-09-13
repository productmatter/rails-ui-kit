# frozen_string_literal: true

require 'rails/generators/base'

module RailsUiKit
  module Generators
    class InstallGenerator < Rails::Generators::Base
      JS_PATH = 'app/javascript/application.js'
      # On a default `rails new --javascript=importmap` app, Stimulus's `application`
      # constant is defined and exported here, not in JS_PATH.
      STIMULUS_APPLICATION_JS_PATH = 'app/javascript/controllers/application.js'
      CSS_PATH = 'app/assets/tailwind/application.css'

      JS_IMPORT_LINE = 'import { registerControllers } from "rails-ui-kit"'
      JS_REGISTER_LINE = 'registerControllers(application)'
      # tailwindcss-rails' `tailwindcss:engines` task writes the engine's compiled CSS to
      # app/assets/builds/tailwind/rails_ui_kit.css (Tailwindcss::Engines.bundle). From
      # CSS_PATH (app/assets/tailwind/application.css), that's one level up.
      CSS_IMPORT_LINE = '@import "../builds/tailwind/rails_ui_kit.css";'

      APPLICATION_START = /Application\.start\(\).*\n/

      desc 'Wire rails_ui_kit into application.js (importmap) and tailwind/application.css'

      def wire_javascript
        unless File.exist?(destination_path(JS_PATH))
          say_status :skip, "#{JS_PATH} not found — add the two rails_ui_kit lines manually (see README).", :yellow
          return
        end

        target = registration_target
        unless target
          say_status :skip, no_registration_target_message, :yellow
          return
        end

        inject_js_import(target)
        inject_js_register(target)
      end

      def wire_tailwind
        unless File.exist?(destination_path(CSS_PATH))
          say_status :skip, "#{CSS_PATH} not found — see README 'Alternative setups' for Sprockets / Tailwind 3.", :yellow
          return
        end

        contents = File.read(destination_path(CSS_PATH))
        if contents.include?(CSS_IMPORT_LINE)
          say_status :identical, CSS_PATH, :blue
          return
        end

        append_to_file CSS_PATH, "#{CSS_IMPORT_LINE}\n"
      end

      def print_next_steps
        say ''
        say '  Render these once per layout (e.g. app/views/layouts/application.html.erb):', :green
        say '    <%= render Ui::ConfirmDialogComponent.new %>'
        say '    <%= render Ui::ToastContainerComponent.new %>'
        say '    <div data-controller="ui--turbo-confirm ui--turbo-disable-with"></div>'
        say ''
      end

      private

      def destination_path(relative_path)
        File.join(destination_root, relative_path)
      end

      def no_registration_target_message
        "couldn't find `Application.start()` in #{JS_PATH} or " \
          "#{STIMULUS_APPLICATION_JS_PATH} — add `#{JS_IMPORT_LINE}` and " \
          "`#{JS_REGISTER_LINE}` yourself, in whichever file has Stimulus's " \
          '`application` in scope (see README).'
      end

      # The file where `Application.start()` actually runs is where Stimulus's
      # `application` constant is in scope, so that's where registration must go.
      def registration_target
        return JS_PATH if application_start_in?(JS_PATH)
        return STIMULUS_APPLICATION_JS_PATH if application_start_in?(STIMULUS_APPLICATION_JS_PATH)

        nil
      end

      def application_start_in?(relative_path)
        full_path = destination_path(relative_path)
        File.exist?(full_path) && File.read(full_path).match?(APPLICATION_START)
      end

      def inject_js_import(path)
        contents = File.read(destination_path(path))
        if contents.include?(JS_IMPORT_LINE)
          say_status :identical, "#{path} (import already present)", :blue
          return
        end

        stimulus_import = %r{^import\s+.*from\s+["']@hotwired/stimulus["'].*\n}
        if contents.match?(stimulus_import)
          inject_into_file path, "#{JS_IMPORT_LINE}\n", after: stimulus_import
        else
          prepend_to_file path, "#{JS_IMPORT_LINE}\n"
        end
      end

      def inject_js_register(path)
        contents = File.read(destination_path(path))
        if contents.include?(JS_REGISTER_LINE)
          say_status :identical, "#{path} (register call already present)", :blue
          return
        end

        inject_into_file path, "#{JS_REGISTER_LINE}\n", after: APPLICATION_START
      end
    end
  end
end
