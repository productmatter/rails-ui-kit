# frozen_string_literal: true

require 'application_system_test_case'
require 'open3'
require 'tmpdir'

# TOK1: a host app's own theme always wins over the kit's token values, whatever
# its import order or layer. Each scenario builds a real host entrypoint with the
# tailwindcss CLI, swaps it into a page, and reads what the browser resolved.
class TokensTest < ApplicationSystemTestCase
  ENGINE_CSS = File.expand_path('../../app/assets/tailwind/rails_ui_kit/engine.css', __dir__)
  KIT_IMPORT = %(@import "#{ENGINE_CSS}";).freeze

  HOST_LIGHT = 'rgb(1, 2, 3)'
  HOST_DARK = 'rgb(4, 5, 6)'
  UNLAYERED = ":root { --primary: #{HOST_LIGHT}; }\n.dark { --primary: #{HOST_DARK}; }".freeze
  BASE_LAYER = "@layer base {\n#{UNLAYERED}\n}".freeze
  THEME_BLOCK = "@theme { --primary: #{HOST_LIGHT}; }".freeze

  SCENARIOS = {
    'unlayered :root/.dark before the kit import' => [UNLAYERED, KIT_IMPORT],
    'unlayered :root/.dark after the kit import' => [KIT_IMPORT, UNLAYERED],
    '@layer base before the kit import' => [BASE_LAYER, KIT_IMPORT],
    '@layer base after the kit import' => [KIT_IMPORT, BASE_LAYER],
    '@theme before the kit import' => [THEME_BLOCK, KIT_IMPORT],
    '@theme after the kit import' => [KIT_IMPORT, THEME_BLOCK]
  }.freeze

  test 'with no host theme the kit token values apply' do
    load_host_css(KIT_IMPORT)

    assert_equal 'oklch(0.52 0.17 277)', token('--primary')
    assert_equal 'oklch(0.7 0.12 277)', token('--primary', dark: true)
  end

  SCENARIOS.each do |name, parts|
    test "the host theme wins: #{name}" do
      load_host_css(*parts)

      assert_equal HOST_LIGHT, token('--primary')
      assert_equal HOST_LIGHT, primary_utility_background, 'bg-primary must resolve through @theme inline to the host value'
      next if parts.include?(THEME_BLOCK) # @theme has no dark-mode form

      assert_equal HOST_DARK, token('--primary', dark: true)
      assert_equal HOST_DARK, primary_utility_background
    end
  end

  test 'a host that redefines only some tokens keeps the kit values for the rest' do
    load_host_css(KIT_IMPORT, UNLAYERED)

    assert_equal 'oklch(0.994 0.002 75)', token('--background')
    assert_equal 'oklch(0.175 0.008 75)', token('--background', dark: true)
  end

  # The three status colours a toast reads are kit extensions (ui-toast § Assumptions): present in
  # both modes by default, and a host that defines --success -- as a shadcn theme author would --
  # wins over the kit's value like any other token.
  test 'the kit status tokens exist in both modes, and a host --success wins' do
    load_host_css(KIT_IMPORT)
    %w[--success --success-foreground --warning --warning-foreground --info --info-foreground].each do |name|
      assert_match(/\Aoklch\(/, token(name), "#{name} is missing in light mode")
      assert_match(/\Aoklch\(/, token(name, dark: true), "#{name} is missing in dark mode")
    end

    load_host_css(KIT_IMPORT, ":root { --success: #{HOST_LIGHT}; }")
    assert_equal HOST_LIGHT, token('--success')
  end

  private

  def load_host_css(*parts)
    css = build_css(['@import "tailwindcss";', *parts].join("\n"))
    visit root_path
    page.execute_script(<<~JS, css)
      document.querySelectorAll('link[rel=stylesheet], style').forEach((node) => node.remove())
      const style = document.createElement('style')
      style.textContent = arguments[0]
      document.head.appendChild(style)
      const probe = document.createElement('div')
      probe.id = 'primary-probe'
      probe.className = 'bg-primary'
      document.body.appendChild(probe)
    JS
  end

  def build_css(source)
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'application.css')
      output = File.join(dir, 'application.out.css')
      File.write(input, source)
      _stdout, stderr, status = Open3.capture3(Tailwindcss::Ruby.executable, '-i', input, '-o', output)
      assert status.success?, "tailwindcss build failed:\n#{stderr}"
      File.read(output)
    end
  end

  def token(name, dark: false)
    page.execute_script("document.documentElement.classList.toggle('dark', #{dark})")
    page.evaluate_script("getComputedStyle(document.documentElement).getPropertyValue('#{name}').trim()")
  end

  def primary_utility_background
    page.evaluate_script("getComputedStyle(document.getElementById('primary-probe')).backgroundColor")
  end
end
