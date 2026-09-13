# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'tmpdir'

module RailsUiKit
  class TailwindEngineCssTest < ActiveSupport::TestCase
    class << self
      attr_accessor :built_host_css
    end

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

    # --- TOK1: the kit's token values sit below anything a host defines ---

    test 'the built CSS puts every kit token value in a sub-layer of the theme layer' do
      css = build_host_css
      tokens = layer_block(css, 'theme.rails-ui-kit')

      refute_nil tokens, "expected an @layer theme.rails-ui-kit block in the built CSS:\n#{css[0, 500]}"
      assert_match(/:root\s*\{[^}]*--primary: oklch\(0\.52 0\.17 277\)/, tokens)
      assert_match(/\.dark\s*\{[^}]*--primary: oklch\(0\.7 0\.12 277\)/, tokens)
      assert_equal 1, css.scan('--primary: oklch(0.52 0.17 277)').size, 'the light --primary value must exist only inside the layer'
      assert_match(/\A.*?@layer theme, base, components, utilities;/m, css, 'Tailwind must declare theme as the first layer')
    end

    test 'the built CSS keeps the data-slot border default in the base layer and the inline theme mappings' do
      css = build_host_css

      assert_match(/\[data-slot\]\s*\{\s*border-color: var\(--border\);/, layer_block(css, 'base'))
      assert_match(/\.bg-primary\s*\{\s*background-color: var\(--primary\);/, css)
    end

    private

    # Built once per run: a real tailwindcss build of a host entrypoint that imports the engine.
    def build_host_css
      self.class.built_host_css ||= Dir.mktmpdir do |dir|
        input = File.join(dir, 'application.css')
        output = File.join(dir, 'out.css')
        File.write(input, %(@import "tailwindcss";\n@import "#{ENGINE_CSS}";\n))
        _stdout, stderr, status = Open3.capture3(Tailwindcss::Ruby.executable, '-i', input, '-o', output)
        assert status.success?, "tailwindcss build failed:\n#{stderr}"
        File.read(output)
      end
    end

    # The body of the last `@layer <name> { … }` block, found by brace matching.
    def layer_block(css, name)
      start = css.rindex(/@layer #{Regexp.escape(name)}\s*\{/)
      return unless start

      open_brace = css.index('{', start)
      depth = 0
      (open_brace...css.length).each do |index|
        depth += { '{' => 1, '}' => -1 }.fetch(css[index], 0)
        return css[(open_brace + 1)...index] if depth.zero?
      end
      nil
    end
  end
end
