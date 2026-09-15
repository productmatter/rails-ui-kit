# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# Reset and disabled are the platform's, and they still work because the value never left the
# native select (ui-select § Behavior, items 5 and 7).
class SelectFormResetTest < ApplicationSystemTestCase
  include SelectHelpers

  ID = 'booking_timezone'

  setup do
    visit select_path
    disable_transitions
    page.execute_script("document.getElementById('#{ID}-combobox').scrollIntoView({ block: 'center' })")
  end

  def form_keys
    page.evaluate_script("Array.from(new FormData(document.getElementById('select-form')).keys())")
  end

  test 'SR1: resetting the form restores the default selection, in the select and in the combobox' do
    focus_combobox(ID)
    press :enter
    press :end
    press :enter
    assert_equal 'tokyo', select_value(ID)
    assert_equal 'Tokyo', combobox_label(ID)

    find('#select-form button[type=reset]').click

    assert_selector "##{ID}-combobox", text: 'Berlin'
    assert_equal 'berlin', select_value(ID), 'the select did not go back to its default selection'
    assert_equal 'Berlin', combobox_label(ID)
  end

  test 'SR2: resetting also clears a search field back to the selected label' do
    id = 'booking_city'
    page.execute_script("document.getElementById('#{id}-combobox').focus()")
    press 'b', 'e'
    assert_popup id, 'open'

    # Reset from the form itself rather than the button: the open listbox covers it, which is
    # exactly what it should do. The event, and everything that follows it, is the same one.
    page.execute_script("document.getElementById('select-form').reset()")

    assert_popup id, 'closed'
    assert_equal '', select_value(id)
    assert_equal '', page.evaluate_script("document.getElementById('#{id}-combobox').value")
    hidden = page.evaluate_script(<<~JS, id)
      Array.from(document.querySelectorAll(`#${arguments[0]}-listbox [role="option"]`)).filter((o) => o.hidden).length
    JS
    assert_equal 0, hidden, 'the filter outlived the reset'
  end

  test 'SR3: a disabled Select posts nothing, exactly as a disabled native select does' do
    assert_includes form_keys, 'booking[timezone]'
    assert_not_includes form_keys, 'booking[tier]', 'a disabled Select would have posted its value'
    assert_selector '#booking_tier-combobox[aria-disabled=true]'
    assert page.evaluate_script("document.getElementById('booking_tier').disabled")
  end
end
