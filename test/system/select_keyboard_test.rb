# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# The WAI-ARIA select-only combobox key table (ui-select § Behavior, item 16), driven with real
# keypresses. Every case also asserts the two things the widget exists to protect: DOM focus
# stays on the combobox, and the value that would post lives in the native <select>.
class SelectKeyboardTest < ApplicationSystemTestCase
  include SelectHelpers

  ID = 'demo_timezone'
  LONDON = 10
  LAST = 19

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit select_path
    disable_transitions
    focus_combobox(ID)
  end

  test 'SK1: ArrowDown, Alt+ArrowDown, Enter and Space open without changing the value' do
    %i[arrow_down alt_arrow_down enter space].each do |key|
      key == :alt_arrow_down ? press_with(:alt, :arrow_down) : press(key)
      assert_popup ID, 'open'
      assert_active ID, LONDON, "#{key} moved visual focus off the selected option"
      assert_equal 'london', select_value(ID)
      assert_focus_on_combobox ID

      press :escape
      assert_popup ID, 'closed'
    end
  end

  test 'SK2: ArrowUp opens and moves visual focus to the first option' do
    press :arrow_up

    assert_popup ID, 'open'
    assert_active ID, 0
    assert_equal 'london', select_value(ID), 'opening changed the value'
  end

  test 'SK3: Home and End open on the first and last option' do
    press :home
    assert_popup ID, 'open'
    assert_active ID, 0

    press :escape
    assert_popup ID, 'closed'
    press :end
    assert_popup ID, 'open'
    assert_active ID, LAST
  end

  test 'SK4: a printable character opens the list and types into it' do
    press 't'
    assert_popup ID, 'open'
    assert_active ID, TIMEZONES.index('Tokyo')
    assert_equal 'london', select_value(ID)

    # Closing ends the search that was running: "ne" starts a fresh one rather than continuing
    # the "t" typed a moment ago.
    press :escape
    assert_popup ID, 'closed'
    press 'n', 'e'
    assert_popup ID, 'open'
    assert_active ID, TIMEZONES.index('New York'), 'a multi-character buffer did not reach the list'
  end

  test 'SK5: while open the arrows step one option and stop at the ends' do
    press :arrow_down
    assert_active ID, LONDON

    press :arrow_down
    assert_active ID, LONDON + 1
    press :arrow_up
    assert_active ID, LONDON

    press :end
    assert_active ID, LAST
    press :arrow_down
    assert_active ID, LAST, 'the list wrapped at the end instead of staying put'

    press :home
    assert_active ID, 0
    press :arrow_up
    assert_active ID, 0, 'the list wrapped at the start instead of staying put'
  end

  test 'SK6: PageDown and PageUp move ten options, clamping at the ends' do
    press :arrow_down
    assert_active ID, LONDON

    press :page_up
    assert_active ID, LONDON - 10
    press :page_down
    assert_active ID, LONDON
    press :page_down
    assert_active ID, LAST, 'a page past the end did not clamp to the last option'
  end

  test 'SK7: the active option is scrolled into view inside the scrolling listbox' do
    press :end
    assert_active ID, LAST

    option = laid_out_rect("##{ID}-option-#{LAST}")
    list = laid_out_rect("##{ID}-listbox")
    assert_operator option['bottom'], :<=, list['bottom'] + 1
    assert_operator option['top'], :>=, list['top'] - 1
  end

  test 'SK8: Enter, Space and Alt+ArrowUp select the active option and close' do
    %i[enter space alt_arrow_up].each_with_index do |key, index|
      target = index + 1
      record_events(ID)
      press :home
      assert_popup ID, 'open'
      press(*Array.new(target) { :arrow_down })
      assert_active ID, target

      key == :alt_arrow_up ? press_with(:alt, :arrow_up) : press(key)
      assert_popup ID, 'closed'
      assert_equal option_value(ID, target), select_value(ID), "#{key} did not write the select"
      assert_equal TIMEZONES[target], combobox_label(ID)
      assert_focus_on_combobox ID
      assert_equal ["input:#{select_value(ID)}:true", "change:#{select_value(ID)}:true"], recorded_events,
                   "#{key} did not dispatch input and change from the select"
    end
  end

  test 'SK9: Tab selects the active option, closes, and moves focus on' do
    record_events(ID)
    press :arrow_down
    press :arrow_down
    assert_active ID, LONDON + 1

    press :tab
    assert_popup ID, 'closed'
    assert_equal option_value(ID, LONDON + 1), select_value(ID)
    assert_equal 2, recorded_events.size
    assert_not_equal "#{ID}-combobox", focused_id, 'Tab left focus on the combobox'
  end

  test 'SK10: Escape closes with no change, and choosing what is already chosen dispatches nothing' do
    record_events(ID)
    press :arrow_down
    press :arrow_down
    assert_active ID, LONDON + 1

    press :escape
    assert_popup ID, 'closed'
    assert_equal 'london', select_value(ID)
    assert_equal 'London', combobox_label(ID)
    assert_focus_on_combobox ID

    press :enter
    assert_popup ID, 'open'
    assert_active ID, LONDON
    press :enter
    assert_popup ID, 'closed'
    assert_empty recorded_events, 'choosing the option that was already selected dispatched events'
  end

  # In this mode the combobox is a <div>, so it cannot trigger implicit submission whatever the
  # controller does: this guards the composition (a Select inside a real form) rather than the
  # preventDefault. Search mode's combobox is a real text input, where the key genuinely could
  # submit, and that is where the guard itself is exercised.
  test 'SK11: operating a Select inside a form never submits it' do
    within '#select-form' do
      page.execute_script(<<~JS)
        window.__submits = 0
        document.getElementById('select-form').addEventListener('submit', (event) => {
          event.preventDefault()
          window.__submits += 1
        })
      JS
      focus_combobox('booking_timezone')

      press :enter
      assert_popup 'booking_timezone', 'open'
      press :arrow_down
      press :enter
      assert_popup 'booking_timezone', 'closed'
    end

    assert_equal 0, page.evaluate_script('window.__submits'), 'Enter submitted the form'
  end

  test 'SK12: aria-selected marks the active option and only it, while data-selected marks the value' do
    press :arrow_down
    assert_active ID, LONDON
    press :arrow_down

    assert_selector "##{ID}-option-#{LONDON + 1}[aria-selected='true']"
    assert_selector "##{ID}-listbox [role=option][aria-selected='true']", count: 1
    assert_selector "##{ID}-option-#{LONDON}[data-selected='true']"
    assert_selector "##{ID}-listbox [role=option][data-selected='true']", count: 1
  end

  test 'SK13: a disabled option takes visual focus but never selects' do
    id = 'demo_plan'
    focus_combobox(id)
    press :end
    assert_popup id, 'open'
    assert_active id, 2, 'a disabled option was skipped instead of staying reachable'

    press :enter
    assert_popup id, 'open'
    assert_equal 'growth', select_value(id)
  end

  test 'SK14: a disabled Select is out of the tab order and never opens' do
    id = 'demo_locked'
    assert_selector "##{id}-combobox[aria-disabled='true']"
    assert_no_selector "##{id}-combobox[tabindex]"

    page.execute_script("document.getElementById('#{id}-combobox').focus()")
    press :arrow_down
    assert_selector "##{id}-combobox[aria-expanded='false']"
    assert_equal 'starter', select_value(id)
  end
end
