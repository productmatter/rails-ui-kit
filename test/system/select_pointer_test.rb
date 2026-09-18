# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# Pointer interaction, which has one rule the keyboard model depends on: DOM focus never lands on
# an option, however the user reaches it. In select-only mode it stays on the combobox throughout;
# in search mode it is in the popup's search field while open and on the trigger once it closes
# (ui-select § Behavior, items 17 and 18).
class SelectPointerTest < ApplicationSystemTestCase
  include SelectHelpers

  ID = 'demo_timezone'
  LONDON = 10

  setup do
    visit select_path
    disable_transitions
  end

  test 'SP1: clicking the combobox opens the list, and clicking it again closes it' do
    combobox(ID).click
    assert_popup ID, 'open'
    assert_active ID, LONDON
    assert_focus_on_combobox ID

    combobox(ID).click
    assert_popup ID, 'closed'
    assert_equal 'london', select_value(ID)
  end

  test 'SP2: clicking an option writes the select and closes, without moving DOM focus' do
    record_events(ID)
    combobox(ID).click
    assert_popup ID, 'open'

    find("##{ID}-option-3").click

    assert_popup ID, 'closed'
    assert_equal option_value(ID, 3), select_value(ID)
    assert_equal TIMEZONES[3], combobox_label(ID)
    assert_focus_on_combobox ID, 'clicking an option pulled DOM focus out of the combobox'
    assert_equal ["input:#{select_value(ID)}:true", "change:#{select_value(ID)}:true"], recorded_events
  end

  test 'SP3: hovering an option moves visual focus to it, and DOM focus stays put' do
    combobox(ID).click
    assert_popup ID, 'open'

    find("##{ID}-option-5").hover
    assert_active ID, 5
    assert_focus_on_combobox ID
    assert_selector "##{ID}-option-5[aria-selected='true']"
    assert_equal 'london', select_value(ID), 'hovering an option changed the value'
  end

  test 'SP4: a disabled option ignores the pointer: nothing is selected and the list stays open' do
    id = 'demo_plan'
    record_events(id)
    combobox(id).click
    assert_popup id, 'open'

    # Pressed at the point rather than through the element, because the option refuses pointer
    # events -- which is the behaviour under test: the press lands on the listbox behind it.
    option = laid_out_rect("##{id}-option-2")
    click_at(option['x'] + (option['width'] / 2), option['y'] + (option['height'] / 2))

    assert_popup id, 'open'
    assert_equal 'growth', select_value(id)
    assert_empty recorded_events
  end

  test 'SP5: clicking outside dismisses the list and changes nothing' do
    record_events(ID)
    combobox(ID).click
    assert_popup ID, 'open'

    find('h1').click

    assert_popup ID, 'closed'
    assert_equal 'london', select_value(ID)
    assert_empty recorded_events
  end

  test 'SP6: clicking the Field label focuses the combobox, not the select behind it' do
    find("label[for='#{ID}']").click

    assert_focus_on_combobox ID, 'the label focused the hidden select instead of the combobox'
    assert_popup ID, 'closed'
  end

  test 'SP7: the popup dismisses when another Select opens over it' do
    combobox(ID).click
    assert_popup ID, 'open'

    combobox('demo_status').click

    assert_popup 'demo_status', 'open'
    assert_popup ID, 'closed'
  end

  # Search mode. The trigger is a button, so a press opens the list the way it does in select-only
  # mode, and DOM focus goes where the mode says: into the search field while open, back on the
  # trigger once it closes (ui-select § Behavior, items 17 and 18).
  SEARCH = 'demo_city'
  SEARCH_LONDON = 11

  test 'SP8: pressing the trigger opens onto the search field, and pressing it again closes' do
    find("##{SEARCH}-trigger").click
    assert_popup SEARCH, 'open'
    assert_focus_on_search SEARCH, 'pressing the trigger left focus outside the popup'
    assert_no_active SEARCH

    find("##{SEARCH}-trigger").click
    assert_popup SEARCH, 'closed'
    assert_equal 'london', select_value(SEARCH)
  end

  test 'SP9: clicking an option writes the select and closes, and focus lands on the trigger' do
    record_events(SEARCH)
    find("##{SEARCH}-trigger").click
    assert_popup SEARCH, 'open'

    find("##{SEARCH}-option-4").click

    assert_popup SEARCH, 'closed'
    assert_equal option_value(SEARCH, 4), select_value(SEARCH)
    assert_equal TIMEZONES[3], control_label(SEARCH)
    assert_focus_on_trigger SEARCH, 'clicking an option stranded focus in a popup that has closed'
    assert_equal ["input:#{select_value(SEARCH)}:true", "change:#{select_value(SEARCH)}:true"], recorded_events
  end

  test 'SP10: hovering an option moves visual focus to it, and DOM focus stays in the field' do
    find("##{SEARCH}-trigger").click
    assert_popup SEARCH, 'open'

    find("##{SEARCH}-option-6").hover
    assert_active SEARCH, 6
    assert_focus_on_search SEARCH
    assert_selector "##{SEARCH}-option-6[aria-selected='true']"
    assert_equal 'london', select_value(SEARCH), 'hovering an option changed the value'
  end

  test 'SP11: clicking outside dismisses the list, changes nothing, and returns focus' do
    record_events(SEARCH)
    find("##{SEARCH}-trigger").click
    assert_popup SEARCH, 'open'
    press 'l', 'o'

    find('h1').click

    assert_popup SEARCH, 'closed'
    assert_equal 'london', select_value(SEARCH)
    assert_equal 'London', control_label(SEARCH)
    assert_empty recorded_events
  end

  test 'SP12: clicking the Field label focuses the trigger, not the select behind it' do
    page.execute_script("document.getElementById('#{SEARCH}-trigger').scrollIntoView({ block: 'center' })")
    find("label[for='#{SEARCH}']").click

    assert_focus_on_trigger SEARCH, 'the label focused the hidden select instead of the trigger'
    assert_popup SEARCH, 'closed'
  end
end
