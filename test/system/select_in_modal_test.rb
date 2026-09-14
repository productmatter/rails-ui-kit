# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# Nesting is not a special case (ui-component-library § Business rules, rule 7): a Select inside a
# Modal behaves as it does outside one, and the Escape ordering is the top layer's, not ours.
class SelectInModalTest < ApplicationSystemTestCase
  include SelectHelpers

  ID = 'modal_city'

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit select_path
    disable_transitions
    find('#select-modal-trigger').click
    assert_selector '#select-modal dialog[data-state=open]'
    assert_selector "##{ID}-combobox"
  end

  test 'SM1: the listbox draws above the dialog and is not clipped by it' do
    focus_combobox(ID)
    press :enter
    assert_popup ID, 'open'

    popup = laid_out_rect("##{ID}-popup")
    dialog = laid_out_rect('#select-modal dialog')
    assert_operator popup['width'], :>, 0

    # Painted above the dialog: the point just inside the popup belongs to an option, not to the
    # dialog underneath it.
    top_element = page.evaluate_script(<<~JS, popup['x'] + 8, popup['y'] + 8)
      (document.elementFromPoint(arguments[0], arguments[1]) || {}).closest === undefined
        ? null
        : Boolean(document.elementFromPoint(arguments[0], arguments[1]).closest('##{ID}-popup'))
    JS
    assert top_element, 'the dialog painted over the listbox'
    assert_operator popup['bottom'], :>, dialog['top'], 'the listbox is nowhere near the dialog'
  end

  test 'SM2: the first Escape closes the listbox and the second closes the Modal' do
    focus_combobox(ID)
    press :enter
    assert_popup ID, 'open'

    press :escape
    assert_popup ID, 'closed'
    assert_selector '#select-modal dialog[data-state=open]', wait: 1
    assert page.evaluate_script("document.querySelector('#select-modal dialog').matches(':modal')"),
           'the first Escape closed the dialog as well as the listbox'

    press :escape
    assert_no_selector '#select-modal dialog[data-state=open]'
  end

  test 'SM3: choosing inside the dialog writes the select and keeps focus on the combobox' do
    record_events(ID)
    focus_combobox(ID)
    press :enter
    assert_popup ID, 'open'
    press :end
    press :enter

    assert_equal 'tokyo', select_value(ID)
    assert_equal 'Tokyo', combobox_label(ID)
    assert_focus_on_combobox ID
    assert_equal ['input:tokyo:true', 'change:tokyo:true'], recorded_events
    assert_selector '#select-modal dialog[data-state=open]'
  end

  test 'SM4: an open listbox inside a dialog passes an axe audit' do
    focus_combobox(ID)
    press :enter
    assert_popup ID, 'open'

    assert_accessible(within: '#select-modal')
  end
end
