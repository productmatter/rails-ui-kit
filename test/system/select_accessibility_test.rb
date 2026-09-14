# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# Accessibility is definition-of-done, not a later pass (ui-select § Business rules, rule 8).
# This file covers select-only mode; the filtered, empty and invalid states, dark mode and the
# contrast checks join it with search mode and Field integration.
class SelectAccessibilityTest < ApplicationSystemTestCase
  include SelectHelpers

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit select_path
    disable_transitions
  end

  test 'SA1: the preview passes an axe audit as rendered' do
    assert_accessible(within: '#select-preview')
  end

  test 'SA2: an open listbox passes an axe audit, grouped and ungrouped' do
    combobox('demo_timezone').click
    assert_popup 'demo_timezone', 'open'
    assert_accessible(within: 'main')

    # Closed first: an open popup covers the next control, which would make the click land on an
    # option instead.
    press :escape
    assert_popup 'demo_timezone', 'closed'
    combobox('demo_country').click
    assert_popup 'demo_country', 'open'
    assert_accessible(within: 'main')
  end

  test 'SA3: an open listbox passes an axe audit in dark mode' do
    use_dark_mode(true)
    combobox('demo_timezone').click
    assert_popup 'demo_timezone', 'open'

    assert_accessible(within: 'main')
  end
end
