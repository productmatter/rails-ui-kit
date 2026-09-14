# frozen_string_literal: true

require 'test_helper'

# The chrome inventory, held together mechanically (ui-localization § Acceptance checks).
# Chrome is what the kit says in its own voice; content is what the call site writes. This
# file is what stops the next hardcoded string, the next orphan key and the next JavaScript
# fallback that drifts from the translation it mirrors.
class ChromeContractTest < ActiveSupport::TestCase
  ROOT = File.expand_path('../..', __dir__)
  LOCALE_FILE = File.join(ROOT, 'config/locales/rails_ui_kit.en.yml')
  DOCS_PAGE = File.join(ROOT, 'examples/app/views/docs/i18n.html.erb')
  COMPONENTS = Dir[File.join(ROOT, 'app/components/**/*.{rb,erb}')].freeze
  CONTROLLERS = Dir[File.join(ROOT, 'app/javascript/**/*.js')].freeze

  # Every leaf under rails_ui_kit.*, as dotted keys.
  def self.chrome_keys(node = nil, prefix = [])
    node ||= YAML.load_file(LOCALE_FILE).dig('en', 'rails_ui_kit')
    node.flat_map do |key, value|
      value.is_a?(Hash) ? chrome_keys(value, prefix + [key]) : [(prefix + [key]).join('.')]
    end
  end

  KEYS = chrome_keys.freeze
  VALUES = KEYS.to_h { |key| [key, I18n.t("rails_ui_kit.#{key}", locale: :en)] }.freeze

  # The only English literals the kit is allowed to hold: a developer-facing console message,
  # and the fallbacks a controller uses when hand-written markup carries no data attribute.
  # Each fallback is checked against its key below, so the two cannot drift.
  JS_FALLBACKS = {
    'dialog_controller.js' => %w[confirm_dialog.title confirm_dialog.message],
    'modal_controller.js' => %w[modal.unsaved_changes_title modal.unsaved_changes_message],
    'toast_container_controller.js' => %w[toast.default_title],
    'dark_mode_controller.js' => %w[dark_mode.switch_to_light dark_mode.switch_to_dark],
    'turbo_disable_with_controller.js' => %w[turbo_disable_with.processing]
  }.freeze

  # A literal in a user-facing position: an accessible name, a title, a placeholder, or text
  # written into the DOM. Console messages address a developer and are exempt (§ Business
  # rules, rule 2); so is the required marker's asterisk, which is a glyph, not a word.
  USER_FACING_RUBY = /
    aria-label=["'](?<text>[A-Za-z][^"'<>%#]{2,})["']
    |aria:\s*\{\s*label:\s*["'](?<text2>[A-Za-z][^"'<>%\#{}]{2,})["']
    |placeholder:\s*["'](?<text3>[A-Za-z][^"'<>%\#{}]{2,})["']
  /x
  USER_FACING_JS = /
    setAttribute\(\s*["'](?:aria-label|title|placeholder)["']\s*,\s*["'](?<text>[^"']{3,})["']
    |(?:textContent|innerText)\s*=\s*["'](?<text2>[A-Za-z][^"']{2,})["']
  /x

  test 'CC1 every key is used by the kit' do
    sources = (COMPONENTS + CONTROLLERS + Dir[File.join(ROOT, 'lib/**/*.rb')]).map { |file| File.read(file) }.join("\n")

    KEYS.each do |key|
      # A plural map is read whole, by its parent key: the category is the browser's to choose.
      read_as = key.sub(/\.(zero|one|two|few|many|other)\z/, '')
      leaf = read_as.split('.').last
      used = sources.include?("rails_ui_kit.#{read_as}") || sources.include?("key: '#{read_as}'") ||
             sources.match?(/chrome_(?:string|plural) :#{Regexp.escape(leaf)}\b/)
      # The two host-wired controllers have no component to render them, so the docs page is
      # where they are used from; the page itself is checked by CC2.
      used ||= key.start_with?('dark_mode.', 'turbo_disable_with.')
      assert used, "rails_ui_kit.#{key} is in the locale file but nothing reads it"
    end
  end

  test 'CC2 every key has a row on the Internationalization page' do
    page = File.read(DOCS_PAGE)

    KEYS.each do |key|
      documented = page.include?("rails_ui_kit.#{key}") ||
                   page.include?("rails_ui_kit.#{key.sub(/\.(one|other|zero|two|few|many)\z/, '')}")
      assert documented, "rails_ui_kit.#{key} is undocumented on the Internationalization page"
    end
  end

  test 'CC3 the docs page documents no key the locale file has dropped' do
    scopes = KEYS.map { |key| key.split('.').first }.uniq
    documented = File.read(DOCS_PAGE).scan(/rails_ui_kit\.([a-z_.]+[a-z_])/).flatten.uniq
                     .select { |key| scopes.include?(key.split('.').first) }

    documented.each do |key|
      known = KEYS.include?(key) || KEYS.any? { |actual| actual.start_with?("#{key}.") }
      assert known, "the Internationalization page documents rails_ui_kit.#{key}, which no longer exists"
    end
  end

  test 'CC4 every English literal a controller falls back to equals the key it mirrors' do
    JS_FALLBACKS.each do |file, keys|
      source = File.read(CONTROLLERS.find { |path| path.end_with?(file) })

      keys.each do |key|
        assert_includes source, VALUES.fetch(key),
                        "#{file} should fall back to the English value of rails_ui_kit.#{key}"
      end
    end
  end

  test 'CC5 no user-facing literal is hardcoded in a component' do
    offenders = COMPONENTS.flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, index|
        next if line.strip.start_with?('#', '<%#')

        match = line.match(USER_FACING_RUBY)
        next unless match

        text = match[:text] || match[:text2] || match[:text3]
        "#{file.delete_prefix("#{ROOT}/")}:#{index + 1} hardcodes #{text.inspect}"
      end
    end

    assert_empty offenders,
                 'chrome goes through I18n and content comes from the call site, so neither is a literal here'
  end

  test 'CC6 no user-facing literal is hardcoded in a Stimulus controller' do
    allowed = VALUES.values

    offenders = CONTROLLERS.flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, index|
        next if line.strip.start_with?('//', '*', '/*')

        match = line.match(USER_FACING_JS)
        next unless match

        text = match[:text] || match[:text2]
        next if allowed.include?(text)

        "#{file.delete_prefix("#{ROOT}/")}:#{index + 1} writes #{text.inspect}"
      end
    end

    assert_empty offenders,
                 'a controller reads its strings from the data attributes its component renders'
  end

  test 'CC7 every plural form interpolates its count' do
    KEYS.grep(/\.(zero|one|two|few|many|other)\z/).each do |key|
      interpolated = I18n.t("rails_ui_kit.#{key}", count: 7, locale: :en)

      assert_not_equal VALUES.fetch(key), interpolated,
                       "rails_ui_kit.#{key} must interpolate the count: a CLDR category is not a number, " \
                       'so a literal numeral here is wrong the moment this file is translated'
    end
  end
end
