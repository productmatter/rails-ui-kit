# frozen_string_literal: true

require 'rails/generators/base'

module RailsUiKit
  module Generators
    class InstallGenerator < Rails::Generators::Base
      JS_PATH = 'app/javascript/application.js'
      CSS_PATH = 'app/assets/tailwind/application.css'

      JS_IMPORT_LINE = 'import { registerControllers } from "rails-ui-kit"'
      JS_REGISTER_LINE = 'registerControllers(application)'
      CSS_IMPORT_LINE = '@import "../../app/assets/builds/tailwind/rails_ui_kit.css";'

      desc 'Wire rails_ui_kit into application.js (importmap) and tailwind/application.css'

      def wire_javascript
        unless File.exist?(File.join(destination_root, JS_PATH))
          say_status :skip, "#{JS_PATH} not found — add the two rails_ui_kit lines manually (see README).", :yellow
          return
        end

        inject_js_import
        inject_js_register
      end

      def wire_tailwind
        unless File.exist?(File.join(destination_root, CSS_PATH))
          say_status :skip, "#{CSS_PATH} not found — see README 'Alternative setups' for Sprockets / Tailwind 3.", :yellow
          return
        end

        contents = File.read(File.join(destination_root, CSS_PATH))
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

      def inject_js_import
        contents = File.read(File.join(destination_root, JS_PATH))
        if contents.include?(JS_IMPORT_LINE)
          say_status :identical, "#{JS_PATH} (import already present)", :blue
          return
        end

        stimulus_import = %r{^import\s+.*from\s+["']@hotwired/stimulus["'].*\n}
        if contents.match?(stimulus_import)
          inject_into_file JS_PATH, "#{JS_IMPORT_LINE}\n", after: stimulus_import
        else
          prepend_to_file JS_PATH, "#{JS_IMPORT_LINE}\n"
        end
      end

      def inject_js_register
        contents = File.read(File.join(destination_root, JS_PATH))
        if contents.include?(JS_REGISTER_LINE)
          say_status :identical, "#{JS_PATH} (register call already present)", :blue
          return
        end

        start_call = /Application\.start\(\).*\n/
        if contents.match?(start_call)
          inject_into_file JS_PATH, "#{JS_REGISTER_LINE}\n", after: start_call
        else
          append_to_file JS_PATH, "#{JS_REGISTER_LINE}\n"
        end
      end
    end
  end
end
