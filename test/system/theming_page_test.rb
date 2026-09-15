# frozen_string_literal: true

require 'application_system_test_case'

# The Theming docs page: every colour token the kit ships, in both modes, read from the stylesheet.
class ThemingPageTest < ApplicationSystemTestCase
  setup do
    visit theming_path
    disable_transitions
  end

  test 'it shows a light and a dark swatch for every colour token the kit ships' do
    tokens = ApplicationController.helpers.kit_colour_tokens

    assert_operator tokens.size, :>=, 32
    assert_selector '#theming-swatches tbody tr', minimum: tokens.size
    tokens.each { |name| assert_selector '#theming-swatches td', text: "--#{name}", exact_text: true }
  end

  test 'a dark swatch shows the dark value even on a light page' do
    dark = ApplicationController.helpers.kit_token_values(:dark)
    row = find('#theming-swatches tr', text: '--primary', match: :first)

    assert_includes row.text, dark['primary']
  end

  test 'it has no accessibility violations in light and dark mode' do
    assert_accessible(within: 'main')

    use_dark_mode(true)
    assert_accessible(within: 'main')
  end
end
