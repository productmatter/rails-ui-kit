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

    # Thor's inject_into_file inserts at every match, which a real host file can have more than one of.

    test 'imports once when application.js has two lines importing from @hotwired/stimulus' do
      write_host_file('app/javascript/application.js', <<~JS)
        import { Application } from "@hotwired/stimulus"
        import { Controller } from "@hotwired/stimulus"
        const application = Application.start()
      JS

      run_generator

      result = File.read(host_path('app/javascript/application.js'))
      assert_equal 1, result.scan('import { registerControllers } from "rails-ui-kit"').size, result
      assert_equal 1, result.scan('registerControllers(application)').size, result
      assert_equal 'import { registerControllers } from "rails-ui-kit"', result.lines[1].chomp
      assert_application_in_scope(result)
    end

    test 'registers after the real Application.start(), not a commented-out one above it' do
      write_host_file('app/javascript/application.js', <<~JS)
        // import { Application } from "@hotwired/stimulus"
        // const application = Application.start()
        import { Application } from "@hotwired/stimulus"
        const application = Application.start()
      JS

      run_generator

      result = File.read(host_path('app/javascript/application.js'))
      assert_equal 1, result.scan(/^registerControllers\(application\)$/).size, result
      assert_equal <<~JS, result
        // import { Application } from "@hotwired/stimulus"
        // const application = Application.start()
        import { Application } from "@hotwired/stimulus"
        import { registerControllers } from "rails-ui-kit"
        const application = Application.start()
        registerControllers(application)
      JS
      assert_application_in_scope(result)
    end

    test 'a commented-out Application.start() alone is not a place to register' do
      write_host_file('app/javascript/application.js', <<~JS)
        import "controllers"
        // const application = Application.start()
      JS

      output = run_generator

      assert_match(/skip.*Application\.start/i, output)
      assert_no_match(/registerControllers/, File.read(host_path('app/javascript/application.js')))
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

    # --- TOK2: `dark:` must follow the same `.dark` class the kit's tokens do ---

    DARK_VARIANT_LINE = '@custom-variant dark (&:where(.dark, .dark *));'

    test 'adds the .dark custom variant to tailwind/application.css with a notice when it is missing' do
      write_host_file('app/assets/tailwind/application.css', SAMPLE_CSS)

      output = run_generator

      result = File.read(host_path('app/assets/tailwind/application.css'))
      assert_equal 1, result.scan(DARK_VARIANT_LINE).size
      assert_operator result.index(DARK_VARIANT_LINE), :>, result.index('rails_ui_kit.css'),
                      'the variant must come after the @import lines'
      assert_match(/notice.*`dark:` utilities now follow the `\.dark` class/, output)
    end

    test 'does not add the dark variant twice' do
      write_host_file('app/assets/tailwind/application.css', "#{SAMPLE_CSS}#{DARK_VARIANT_LINE}\n")

      output = run_generator

      result = File.read(host_path('app/assets/tailwind/application.css'))
      assert_equal 1, result.scan('@custom-variant dark').size
      assert_match(/identical.*dark variant already present/, output)
    end

    test 'leaves a host-defined dark variant alone and warns that it must match .dark' do
      own_variant = "@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));\n"
      write_host_file('app/assets/tailwind/application.css', "#{SAMPLE_CSS}#{own_variant}")

      output = run_generator

      result = File.read(host_path('app/assets/tailwind/application.css'))
      assert_equal 1, result.scan('@custom-variant dark').size
      assert_includes result, own_variant
      assert_match(/skip.*already defines its own `@custom-variant dark`/, output)
    end

    test 'treats a Tailwind 4.0 style top-level @variant dark definition as already defined' do
      write_host_file('app/assets/tailwind/application.css', "#{SAMPLE_CSS}@variant dark (&:where(.dark, .dark *));\n")

      run_generator

      assert_not_includes File.read(host_path('app/assets/tailwind/application.css')), '@custom-variant'
    end

    # --- GEN3: `stylesheet_link_tag :app` links the engine stub the browser can't load ---

    # The <head> `rails new --css=tailwind` writes on Rails 8.1.
    RAILS_81_LAYOUT = <<~ERB
      <!DOCTYPE html>
      <html>
        <head>
          <title><%= content_for(:title) || "Shop" %></title>
          <%= csrf_meta_tags %>
          <%= csp_meta_tag %>

          <%# Includes all stylesheet files in app/assets/stylesheets %>
          <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
          <%= javascript_importmap_tags %>
        </head>

        <body>
          <%= yield %>
        </body>
      </html>
    ERB

    def write_rails_81_host
      write_host_file('app/assets/tailwind/application.css', SAMPLE_CSS)
      write_host_file('app/assets/stylesheets/application.css', "/* Application styles */\n")
      write_host_file('app/assets/builds/tailwind.css', "/* built */\n")
      write_host_file('app/assets/builds/tailwind/rails_ui_kit.css', "@import \"/gems/rails_ui_kit/app/assets/tailwind/rails_ui_kit/engine.css\";\n")
      write_host_file('app/views/layouts/application.html.erb', RAILS_81_LAYOUT)
    end

    test 'replaces stylesheet_link_tag :app with the stylesheets it linked, minus the engine stub' do
      write_rails_81_host

      output = run_generator

      layout = File.read(host_path('app/views/layouts/application.html.erb'))
      assert_includes layout, '<%= stylesheet_link_tag "application", "tailwind", "data-turbo-track": "reload" %>'
      assert_no_match(/:app\b/, layout)
      assert_no_match(/Includes all stylesheet files/, layout)
      assert_no_match(%r{tailwind/rails_ui_kit}, layout)
      assert_equal RAILS_81_LAYOUT.lines.size - 1, layout.lines.size, 'only the :app line and its comment change'
      assert_match(/notice.*stylesheet_link_tag :app/, output)
    end

    test 'names a stylesheet that is not built yet, and every stylesheet the host has' do
      write_rails_81_host
      File.delete(host_path('app/assets/builds/tailwind.css'))
      write_host_file('app/assets/stylesheets/admin/tables.css', "table {}\n")

      run_generator

      assert_includes File.read(host_path('app/views/layouts/application.html.erb')),
                      'stylesheet_link_tag "admin/tables", "application", "tailwind", "data-turbo-track": "reload"'
    end

    test 'is idempotent on a Rails 8.1 layout and leaves an explicit one alone' do
      write_rails_81_host

      run_generator
      first = File.read(host_path('app/views/layouts/application.html.erb'))
      run_generator

      assert_equal first, File.read(host_path('app/views/layouts/application.html.erb'))
    end

    test 'the next steps say to link stylesheets by name rather than with :app' do
      write_host_file('app/assets/tailwind/application.css', SAMPLE_CSS)

      output = run_generator

      assert_match(/stylesheet_link_tag :app/, output)
      assert_match(/stylesheet_link_tag "tailwind"/, output)
    end

    test 'skips with notice when application.js is missing' do
      output = run_generator
      assert_match(/skip.*application\.js/i, output)
    end

    test 'skips with notice when tailwind/application.css is missing' do
      output = run_generator
      assert_match(/skip.*application\.css/i, output)
      assert_match(/requires Tailwind CSS 4 via tailwindcss-rails/, output)
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
