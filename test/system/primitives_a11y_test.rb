# frozen_string_literal: true

require 'application_system_test_case'
require 'primitives_helpers'

class PrimitivesA11yTest < ApplicationSystemTestCase
  include PrimitivesHelpers

  test 'PA1: the positioning and navigation demo page has no accessibility violations' do
    visit primitives_navigation_path
    assert_selector '[data-ui--anchor-target="floating"][data-side]', minimum: 12, wait: 20

    # The page's own content. The shared docs layout around it is not this page's to audit.
    assert_accessible(within: 'main')
  end

  test 'PA2: it still has none with a menu item focused and a listbox option active' do
    visit primitives_navigation_path

    page.execute_script("document.getElementById('primitive-menu-duplicate').focus()")
    input = find('#roving-listbox-input')
    page.execute_script('arguments[0].focus()', input)
    press :arrow_down, :arrow_down
    assert_selector "#roving-listbox-input[aria-activedescendant='roving-option-apple']"

    assert_accessible(within: '#roving-menu')
    assert_accessible(within: '#roving-listbox')
  end
end
