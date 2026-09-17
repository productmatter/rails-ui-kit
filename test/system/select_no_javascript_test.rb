# frozen_string_literal: true

require 'application_system_test_case'

# With JavaScript off, Select is what it was server-rendered as: a native <select> that submits.
# This is the check that keeps the whole component honest, so it is driven by rack_test -- no
# browser at all, which is the strongest possible form of "JavaScript never ran"
# (ui-select § Behavior, item 2, and § Assumptions).
class SelectNoJavascriptTest < ApplicationSystemTestCase
  driven_by :rack_test

  setup { visit select_path }

  test 'SN1: the native select is the visible control, and the enhanced parts are not rendered' do
    assert_selector 'select#trip_city'
    assert_no_selector '#trip_city-combobox'
    assert_no_selector '#trip_city-popup'
    assert_no_selector '[role=listbox]'
    assert_selector "[data-slot='select']:not([data-enhanced])", minimum: 1
  end

  test 'SN2: the select is named by the Field label, and reachable by that name' do
    assert_selector "label[for='trip_city']", text: 'Destination'
    assert_equal 'trip_city-label', find("label[for='trip_city']")[:id]

    assert_nothing_raised { find_field('Destination') }
    assert_equal 'trip_city', find_field('Destination')[:id]
  end

  test 'SN3: choosing an option and submitting posts its value' do
    select 'London', from: 'Destination'
    click_button 'Book'

    assert_text 'Server received: london'
    assert_selector "select#trip_city option[value='london'][selected]", visible: :all
  end

  test 'SN4: a server-side error comes back through Field, on the select itself' do
    click_button 'Book'

    assert_selector '[data-slot=field-error]', text: "can't be blank"
    assert_selector "select#trip_city[aria-invalid='true'][aria-describedby~='trip_city-error']"
  end

  test 'SN5: search mode degrades to the same native select' do
    assert_selector 'select#demo_city'
    assert_no_selector '#demo_city-combobox'
    assert_no_selector "button[aria-label='Show options']"
    assert_equal 'london', find('select#demo_city').value
  end
end
