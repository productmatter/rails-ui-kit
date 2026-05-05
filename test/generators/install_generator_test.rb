# frozen_string_literal: true

require 'test_helper'
require 'rails/generators/test_case'
require 'generators/rails_ui_kit/install/install_generator'

module RailsUiKit
  class InstallGeneratorTest < Rails::Generators::TestCase
    tests RailsUiKit::Generators::InstallGenerator
    destination File.expand_path('../tmp/generators', __dir__)
    setup :prepare_destination

    SAMPLE_JS = <<~JS
      import { Application } from "@hotwired/stimulus"
      const application = Application.start()
    JS

    SAMPLE_CSS = "@import \"tailwindcss\";\n"

    test 'injects import and register call into application.js' do
      write_host_file('app/javascript/application.js', SAMPLE_JS)

      run_generator

      result = File.read(host_path('app/javascript/application.js'))
      assert_includes result, 'import { registerControllers } from "rails-ui-kit"'
      assert_includes result, 'registerControllers(application)'
    end

    test 'is idempotent on application.js' do
      write_host_file('app/javascript/application.js', SAMPLE_JS)

      run_generator
      first = File.read(host_path('app/javascript/application.js'))
      run_generator
      second = File.read(host_path('app/javascript/application.js'))

      assert_equal first, second
    end

    test 'appends @import to tailwind/application.css' do
      write_host_file('app/assets/tailwind/application.css', SAMPLE_CSS)

      run_generator

      result = File.read(host_path('app/assets/tailwind/application.css'))
      assert_includes result, '@import "../../app/assets/builds/tailwind/rails_ui_kit.css";'
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
  end
end
