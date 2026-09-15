# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# Accessibility is definition-of-done, not a later pass (ui-select § Business rules, rule 8):
# both modes, closed, open, filtered, empty and invalid, in light and dark mode, plus the
# contrast the component's own colours have to meet on every token surface.
class SelectAccessibilityTest < ApplicationSystemTestCase
  include SelectHelpers

  setup do
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

  test 'SA3: a filtered list, and an emptied one, pass an axe audit' do
    field = find('#demo_city-combobox')
    field.click
    press 'l', 'o'
    assert_popup 'demo_city', 'open'
    assert_selector '#demo_city-status', text: 'results', visible: :all
    assert_accessible(within: 'main')

    press 'z', 'z'
    assert_selector '#demo_city-empty', text: 'No results'
    assert_accessible(within: 'main')
  end

  test 'SA4: an open listbox passes an axe audit in dark mode, in both modes' do
    use_dark_mode(true)
    combobox('demo_timezone').click
    assert_popup 'demo_timezone', 'open'
    assert_accessible(within: 'main')

    press :escape
    assert_popup 'demo_timezone', 'closed'
    find('#demo_city-combobox').click
    press 'l', 'o'
    assert_popup 'demo_city', 'open'
    assert_accessible(within: 'main')
  end

  test 'SA5: the invalid state passes an axe audit, light and dark' do
    id = 'trip_city'
    page.execute_script("document.getElementById('#{id}-combobox').scrollIntoView({ block: 'center' })")
    find("##{id}-combobox").click
    assert_popup id, 'open'
    find("##{id}-option-4").click
    find('#select-round-trip-submit').click
    assert_selector '[data-slot=field-error]'
    assert_selector "##{id}-combobox[aria-invalid='true']"

    assert_accessible(within: '#select-round-trip-preview')
    use_dark_mode(true)
    assert_accessible(within: '#select-round-trip-preview')
  end

  # The control's own text contrast is control_contrast_test.rb's "Select's control box" test;
  # this keeps the option and active-option contrast, which are unique to the open listbox.
  test 'SA6: option text and the active option meet contrast on every surface' do
    preview = find_by_id('select-preview')
    combobox('demo_timezone').click
    assert_popup 'demo_timezone', 'open'
    press :arrow_down

    each_token_surface(preview) do |mode, surface|
      option = find('#demo_timezone-option-0')
      ratio = contrast_ratio(color_of(:text, option), color_of(:background, option))
      assert_operator ratio, :>=, 4.5, "option text is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"

      active = find('#demo_timezone-option-10')
      ratio = contrast_ratio(color_of(:text, active), color_of(:background, active))
      assert_operator ratio, :>=, 4.5, "the active option is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'SA8: aria-required mirrors the select, server-rendered and after a programmatic change, in both modes' do
    assert_selector "#trip_city-combobox[aria-required='true']"

    id = 'demo_city'
    assert_no_selector "##{id}-combobox[aria-required]"

    page.execute_script(<<~JS, id)
      const select = document.getElementById(arguments[0])
      select.required = true
      select.dispatchEvent(new Event('change', { bubbles: true }))
    JS
    assert_selector "##{id}-combobox[aria-required='true']"
    assert_accessible(within: '#select-search-preview')

    page.execute_script(<<~JS, id)
      const select = document.getElementById(arguments[0])
      select.required = false
      select.dispatchEvent(new Event('change', { bubbles: true }))
    JS
    assert_no_selector "##{id}-combobox[aria-required]"
  end

  # SA7 (the focus ring on the control reaches 3:1 against every surface) moved to
  # control_contrast_test.rb's "Select's control box" test.
end
