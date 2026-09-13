# frozen_string_literal: true

require 'test_helper'
require 'rails/generators/test_case'
require 'generators/rails_ui_kit/install/install_generator'
require 'open3'
require 'tempfile'

module RailsUiKit
  class InstallGeneratorTest < Rails::Generators::TestCase
    tests RailsUiKit::Generators::InstallGenerator
    destination File.expand_path('../tmp/generators', __dir__)
    setup :prepare_destination

    # Old-style single-file shape: `Application.start()` runs directly in application.js.
    INLINE_APPLICATION_JS = <<~JS
      import { Application } from "@hotwired/stimulus"
      const application = Application.start()
    JS

    # Default `rails new --javascript=importmap` shape: application.js has no
    # `application` in scope at all.
    DEFAULT_IMPORTMAP_APPLICATION_JS = <<~JS
      // Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
      import "@hotwired/turbo-rails"
      import "controllers"
    JS

    # ...and Stimulus's `application` is defined and exported from here instead.
    DEFAULT_STIMULUS_APPLICATION_JS = <<~JS
      import { Application } from "@hotwired/stimulus"

      const application = Application.start()

      // Configure Stimulus development experience
      application.debug = false
      window.Stimulus   = application

      export { application }
    JS

    SAMPLE_CSS = "@import \"tailwindcss\";\n"

    # --- GEN2: registration must land where `application` is actually in scope ---

    test 'injects import and register call into application.js when Application.start() lives there' do
      write_host_file('app/javascript/application.js', INLINE_APPLICATION_JS)

      run_generator

      result = File.read(host_path('app/javascript/application.js'))
      assert_includes result, 'import { registerControllers } from "rails-ui-kit"'
      assert_includes result, 'registerControllers(application)'
      assert_application_in_scope(result)
    end

    test 'is idempotent when Application.start() lives in application.js' do
      write_host_file('app/javascript/application.js', INLINE_APPLICATION_JS)

      run_generator
      first = File.read(host_path('app/javascript/application.js'))
      run_generator
      second = File.read(host_path('app/javascript/application.js'))

      assert_equal first, second
    end

    test 'registers in controllers/application.js on a default importmap app, not application.js' do
      write_host_file('app/javascript/application.js', DEFAULT_IMPORTMAP_APPLICATION_JS)
      write_host_file('app/javascript/controllers/application.js', DEFAULT_STIMULUS_APPLICATION_JS)

      run_generator

      untouched = File.read(host_path('app/javascript/application.js'))
      assert_equal DEFAULT_IMPORTMAP_APPLICATION_JS, untouched,
                   'application.js has no `application` in scope and must be left alone'

      wired = File.read(host_path('app/javascript/controllers/application.js'))
      assert_includes wired, 'import { registerControllers } from "rails-ui-kit"'
      assert_includes wired, 'registerControllers(application)'
      assert_application_in_scope(wired)
    end

    test 'is idempotent on the default importmap app shape' do
      write_host_file('app/javascript/application.js', DEFAULT_IMPORTMAP_APPLICATION_JS)
      write_host_file('app/javascript/controllers/application.js', DEFAULT_STIMULUS_APPLICATION_JS)

      run_generator
      first_app = File.read(host_path('app/javascript/application.js'))
      first_stimulus = File.read(host_path('app/javascript/controllers/application.js'))
      run_generator
      second_app = File.read(host_path('app/javascript/application.js'))
      second_stimulus = File.read(host_path('app/javascript/controllers/application.js'))

      assert_equal first_app, second_app
      assert_equal first_stimulus, second_stimulus
    end

    test 'skips with a clear message and writes nothing when Application.start() is nowhere to be found' do
      write_host_file('app/javascript/application.js', DEFAULT_IMPORTMAP_APPLICATION_JS)

      output = run_generator

      assert_match(/skip.*Application\.start/i, output)
      untouched = File.read(host_path('app/javascript/application.js'))
      assert_equal DEFAULT_IMPORTMAP_APPLICATION_JS, untouched,
                   'must not blindly append registerControllers(application) without application in scope'
    end

    # --- GEN1: the CSS import must resolve to where tailwindcss-rails actually builds it ---

    test 'appends @import to tailwind/application.css' do
      write_host_file('app/assets/tailwind/application.css', SAMPLE_CSS)

      run_generator

      result = File.read(host_path('app/assets/tailwind/application.css'))
      assert_includes result, 'rails_ui_kit.css'
    end

    test 'the generated CSS import resolves to the engines build output, not app/app/assets' do
      write_host_file('app/assets/tailwind/application.css', SAMPLE_CSS)

      run_generator

      css_path = host_path('app/assets/tailwind/application.css')
      import_line = File.readlines(css_path).find { |l| l.include?('rails_ui_kit.css') }
      refute_nil import_line, 'expected an @import line referencing rails_ui_kit.css'

      import_path = import_line[/"([^"]+)"/, 1]
      resolved = File.expand_path(import_path, File.dirname(css_path))

      # This is exactly where Tailwindcss::Engines.bundle (tailwindcss-rails' `tailwindcss:engines`
      # task) writes the compiled engine CSS: Rails.root.join("app/assets/builds/tailwind/#{engine_name}.css")
      expected = File.join(destination_root, 'app/assets/builds/tailwind/rails_ui_kit.css')
      assert_equal expected, resolved
    end

    test 'is idempotent on tailwind/application.css' do
      write_host_file('app/assets/tailwind/application.css', SAMPLE_CSS)

      run_generator
      first = File.read(host_path('app/assets/tailwind/application.css'))
      run_generator
      second = File.read(host_path('app/assets/tailwind/application.css'))

      assert_equal first, second
    end

    test 'skips with notice when application.js is missing' do
      output = run_generator
      assert_match(/skip.*application\.js/i, output)
    end

    test 'skips with notice when tailwind/application.css is missing' do
      output = run_generator
      assert_match(/skip.*application\.css/i, output)
    end

    private

    def write_host_file(rel, contents)
      path = host_path(rel)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, contents)
    end

    def host_path(rel)
      File.join(destination_root, rel)
    end

    # Actually proves `application` is reachable where `registerControllers(application)`
    # is called, by running the generated JS (with bare-specifier imports/exports stripped
    # and stubbed) under Node and checking it doesn't throw a ReferenceError. A string match
    # on the presence of `registerControllers(application)` alone can't tell the difference
    # between this passing and the ReferenceError this generator used to throw.
    def assert_application_in_scope(js_source)
      skip 'node is not available in this environment' unless node_available?

      Tempfile.create(['rails_ui_kit_generated', '.js']) do |file|
        file.write(node_scope_harness(js_source))
        file.flush
        _stdout, stderr, status = Open3.capture3('node', file.path)
        assert status.success?,
               "expected the generated JavaScript to run without a ReferenceError:\n#{stderr}\n---\n#{js_source}"
      end
    end

    def node_scope_harness(js_source)
      body = js_source.lines.grep_v(/^\s*(import\s+.+|export\s+\{.*\})\s*$/).join
      <<~JS
        "use strict";
        const window = {};
        const Application = { start: () => ({}) };
        function registerControllers(app) {
          if (typeof app === "undefined") {
            throw new ReferenceError("application is not defined");
          }
        }
        #{body}
      JS
    end

    def node_available?
      return @node_available if defined?(@node_available)

      @node_available = system('node', '--version', out: File::NULL, err: File::NULL)
    end
  end
end
