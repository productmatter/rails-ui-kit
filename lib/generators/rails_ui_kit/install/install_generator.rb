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
      LAYOUT_PATH = 'app/views/layouts/application.html.erb'

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

      # Rails 8's default layout. Propshaft's `:app` links every CSS file under app/assets, which
      # includes the entry stub tailwindcss-rails' engines task writes to
      # app/assets/builds/tailwind/rails_ui_kit.css: a Tailwind input whose `@import` names the
      # gem's absolute path, so the browser requests that path on every page and gets an error.
      # tailwindcss-rails' maintainers say not to combine `:app` with it and to link the build
      # explicitly (rails/tailwindcss-rails#565, rails/propshaft#242).
      APP_STYLESHEETS = /(stylesheet_link_tag[\s(]+):app\b/
      APP_STYLESHEETS_COMMENT = %r{^[ \t]*<%# Includes all stylesheet files in app/assets/stylesheets %>\n}
      # Propshaft's load path is each directory under app/assets; app/assets/tailwind is excluded by
      # tailwindcss-rails, and builds/tailwind/ holds only engine stubs.
      UNSERVED_STYLESHEETS = %r{\A(tailwind/|builds/tailwind/)}

      APPLICATION_START = /Application\.start\(\).*\n/
      STIMULUS_IMPORT = %r{^import\s+.*from\s+["']@hotwired/stimulus["'].*\n}
      # A line a host has commented out is not where anything runs.
      COMMENT_LINE = %r{\A\s*(//|/\*|\*)}

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
        link_stylesheets_explicitly
      end

      def print_next_steps
        say ''
        say '  Render these once per layout (e.g. app/views/layouts/application.html.erb):', :green
        say '    <%= render Ui::ConfirmDialogComponent.new %>'
        say '    <%= render Ui::ToastContainerComponent.new %>'
        say '    <div data-controller="ui--turbo-confirm ui--turbo-disable-with"></div>'
        say ''
        say '  Link stylesheets by name, not with `stylesheet_link_tag :app` or `:all`: those also link', :green
        say '  the engine stubs tailwindcss-rails writes to app/assets/builds/tailwind/, which the', :green
        say '  browser cannot load. `stylesheet_link_tag "tailwind"` already contains the kit\'s CSS.', :green
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
        File.exist?(full_path) && !first_code_line(File.read(full_path), APPLICATION_START).nil?
      end

      def first_code_line(contents, pattern)
        contents.lines.index { |line| !line.match?(COMMENT_LINE) && line.match?(pattern) }
      end

      # Thor's inject_into_file inserts at every match of `after:`, so the flag is anchored to
      # the start of the file and spans exactly the lines up to and including the chosen one.
      def after_line(index)
        /\A(?:.*\n){#{index + 1}}/
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

      # `:app` is replaced by exactly the stylesheets it links today, in the order Propshaft links
      # them (sorted by logical path), minus the stubs.
      def link_stylesheets_explicitly
        return unless File.exist?(destination_path(LAYOUT_PATH)) && File.read(destination_path(LAYOUT_PATH)).match?(APP_STYLESHEETS)

        names = served_stylesheets.map { |name| %("#{name}") }.join(', ')
        gsub_file LAYOUT_PATH, APP_STYLESHEETS_COMMENT, ''
        gsub_file LAYOUT_PATH, APP_STYLESHEETS, "\\1#{names}"
        say_status :notice, "#{LAYOUT_PATH}: `stylesheet_link_tag :app` now names #{names}. `:app` also linked the " \
                            'engine stub in app/assets/builds/tailwind/, which the browser cannot load. Add any ' \
                            'stylesheet you create later to that line.', :yellow
      end

      def served_stylesheets
        assets = destination_path('app/assets')
        logical_paths = Dir.glob("#{assets}/*/**/*.css").filter_map do |path|
          relative = path.delete_prefix("#{assets}/")
          relative.split('/', 2).last.delete_suffix('.css') unless relative.match?(UNSERVED_STYLESHEETS)
        end
        (logical_paths | ['tailwind']).sort
      end

      def inject_js_import(path)
        contents = File.read(destination_path(path))
        if contents.include?(JS_IMPORT_LINE)
          say_status :identical, "#{path} (import already present)", :blue
          return
        end

        stimulus_import = first_code_line(contents, STIMULUS_IMPORT)
        if stimulus_import
          inject_into_file path, "#{JS_IMPORT_LINE}\n", after: after_line(stimulus_import)
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

        inject_into_file path, "#{JS_REGISTER_LINE}\n", after: after_line(first_code_line(contents, APPLICATION_START))
      end
    end
  end
end
