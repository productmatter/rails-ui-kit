# frozen_string_literal: true

require 'test_helper'

module RailsUiKit
  class TailwindEngineCssTest < ActiveSupport::TestCase
    GEM_ROOT = File.expand_path('..', __dir__)
    ENGINE_CSS = File.join(GEM_ROOT, 'app/assets/tailwind/rails_ui_kit/engine.css')

    test 'ships engine.css at the tailwindcss-rails-conventional path' do
      assert File.exist?(ENGINE_CSS), "expected #{ENGINE_CSS} to exist"
    end

    test 'engine.css imports the components stylesheet and sources the gem trees' do
      contents = File.read(ENGINE_CSS)

      assert_match %r{@import\s+["']\.\./\.\./stylesheets/rails_ui_kit/components\.css["']}, contents
      assert_match %r{@source\s+["']\.\./\.\./\.\./components/}, contents
      assert_match %r{@source\s+["']\.\./\.\./\.\./javascript/}, contents
    end

    test 'engine.css relative paths resolve to real files in the gem' do
      base = File.dirname(ENGINE_CSS)

      assert File.exist?(File.expand_path('../../stylesheets/rails_ui_kit/components.css', base))
      assert File.directory?(File.expand_path('../../../components', base))
      assert File.directory?(File.expand_path('../../../javascript', base))
    end

    test 'engine.css defaults border color to the token on kit parts only' do
      contents = File.read(ENGINE_CSS)

      assert_match(/@layer base\s*\{\s*\[data-slot\]\s*\{\s*border-color:\s*var\(--border\);/, contents)
      refute_match(/^\s*\*\s*\{/, contents, 'a global * reset would recolor bare borders in host apps')
    end
  end
end
