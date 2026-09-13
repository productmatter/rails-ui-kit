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
      # The kit's tokens switch on `.dark` (what ui--dark-mode toggles). Tailwind 4's
      # own `dark:` follows the OS preference unless the host redefines it, so the
      # generator does that in the host's file; the engine can't ship it without
      # changing `dark:` for every host that imports it.
      DARK_VARIANT_LINE = '@custom-variant dark (&:where(.dark, .dark *));'
      # Any existing definition, including Tailwind 4.0's older top-level `@variant dark (…)`.
      DARK_VARIANT = /^\s*@(custom-variant\s+dark\b|variant\s+dark\s*\()/

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
          say_status :skip, "#{CSS_PATH} not found — rails_ui_kit requires Tailwind CSS 4 via tailwindcss-rails (see README).", :yellow
          return
        end

        inject_css_import
        inject_dark_variant
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

      def inject_css_import
        if File.read(destination_path(CSS_PATH)).include?(CSS_IMPORT_LINE)
          say_status :identical, "#{CSS_PATH} (import already present)", :blue
          return
        end

        append_to_file CSS_PATH, "#{CSS_IMPORT_LINE}\n"
      end

      def inject_dark_variant
        contents = File.read(destination_path(CSS_PATH))
        if contents.include?(DARK_VARIANT_LINE)
          say_status :identical, "#{CSS_PATH} (dark variant already present)", :blue
        elsif contents.match?(DARK_VARIANT)
          say_status :skip, "#{CSS_PATH} already defines its own `@custom-variant dark`. The kit's tokens switch " \
                            'on the `.dark` class on <html>; make sure your variant matches it, or `dark:` utilities ' \
                            'and the kit will disagree about what dark mode is.', :yellow
        else
          append_to_file CSS_PATH, "#{DARK_VARIANT_LINE}\n"
          say_status :notice, "#{CSS_PATH}: `dark:` utilities now follow the `.dark` class on <html> (what " \
                              'ui--dark-mode toggles and the kit\'s tokens use), not the OS colour-scheme preference.', :yellow
        end
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
