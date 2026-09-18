# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# Turbo's page cache, under the primitives' contract (ui-select § Behavior, item 32): Back
# restores a closed, unfiltered Select still showing the value the user left, with focus left
# where it was.
class SelectTurboCacheTest < ApplicationSystemTestCase
  include SelectHelpers

  ID = 'demo_timezone'

  setup do
    visit select_path
    disable_transitions
    page.execute_script(<<~JS)
      window.__errors = []
      window.addEventListener('error', (event) => window.__errors.push(String(event.message)))
    JS
  end

  test 'SC1: Back to a page cached with a Select open restores it closed, on the value the user left' do
    focus_combobox(ID)
    press :enter
    press :end
    press :enter
    assert_equal 'tokyo', select_value(ID)

    press :enter
    assert_popup ID, 'open'
    page.execute_script('Turbo.visit(arguments[0])', installation_path)
    assert_selector 'h1', text: 'Installation'

    page.go_back
    assert_selector 'h1', text: 'Select'

    assert_popup ID, 'closed'
    assert_equal 'tokyo', select_value(ID), 'the value the user left did not survive the page cache'
    assert_equal 'Tokyo', combobox_label(ID)
    assert_no_active ID
    assert_not page.evaluate_script("document.getElementById('#{ID}-popup').contains(document.activeElement)")
    assert_not_equal "#{ID}-combobox", focused_id, 'the restored page pulled focus into the Select'
    assert_empty page.evaluate_script('window.__errors')
  end

  test 'SC2: Back restores a search Select closed, unfiltered, empty-fielded, on its selected label' do
    id = 'demo_city'
    focus_trigger(id)
    press :enter
    assert_popup id, 'open'
    press 'l', 'o', 'n'
    assert_equal 'lon', search_value(id)

    page.execute_script('Turbo.visit(arguments[0])', installation_path)
    assert_selector 'h1', text: 'Installation'
    page.go_back
    assert_selector 'h1', text: 'Select'

    assert_popup id, 'closed'
    assert_equal 'london', select_value(id)
    assert_equal 'London', control_label(id), 'the restored trigger was not showing the value'
    assert_equal '', search_value(id), 'the restored field kept what the user had typed'
    hidden = page.evaluate_script(<<~JS, id)
      Array.from(document.querySelectorAll(`#${arguments[0]}-listbox [role="option"]`)).filter((o) => o.hidden).length
    JS
    assert_equal 0, hidden, 'the filter was cached with the page'
    assert_not_equal "#{id}-search", focused_id, 'the restored page pulled focus into the Select'
    assert_not_equal "#{id}-trigger", focused_id
    assert_empty page.evaluate_script('window.__errors')
  end

  test 'SC3: the restored Select still opens and chooses' do
    focus_combobox(ID)
    press :enter
    assert_popup ID, 'open'
    page.execute_script('Turbo.visit(arguments[0])', installation_path)
    assert_selector 'h1', text: 'Installation'
    page.go_back
    assert_selector 'h1', text: 'Select'

    focus_combobox(ID)
    press :enter
    assert_popup ID, 'open'
    press :home
    press :enter
    assert_equal 'auckland', select_value(ID)
  end
end
