# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# The WAI-ARIA editable combobox with list autocomplete (ui-select § Behavior, items 17, 21 and
# 22), driven with real keypresses. Filtering is a view over the same options: the select's own
# <option>s never change, which is why the value can always still submit.
class SelectSearchTest < ApplicationSystemTestCase
  include SelectHelpers

  ID = 'demo_city'
  LONDON = 11 # the blank option is first, so every index is one past the select-only page's

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit select_path
    disable_transitions
    page.execute_script("document.getElementById('#{ID}-combobox').scrollIntoView({ block: 'center' })")
  end

  def field
    find("##{ID}-combobox")
  end

  def field_value(id = ID)
    page.evaluate_script("document.getElementById('#{id}-combobox').value")
  end

  # Types into the field the way a person would: focus it, clear what is there with the keyboard,
  # then type. Backspacing filters as it goes, which is exactly what it does for a user.
  def type(*characters, id: ID)
    page.execute_script("document.getElementById('#{id}-combobox').focus()")
    length = page.evaluate_script("document.getElementById('#{id}-combobox').value.length")
    press(*Array.new(length) { :backspace }) if length.positive?
    press(*characters)
  end

  def visible_option_texts(id = ID)
    page.evaluate_script(<<~JS, id)
      Array.from(document.querySelectorAll(`#${arguments[0]}-listbox [role="option"]`))
           .filter((option) => !option.hidden)
           .map((option) => option.textContent.trim())
    JS
  end

  def native_option_count(id = ID)
    page.evaluate_script("document.getElementById('#{id}').options.length")
  end

  test 'SS1: typing filters the listbox and never the select' do
    before = native_option_count
    assert_operator before, :>, 5

    type 'l', 'o', 'n'

    assert_popup ID, 'open'
    assert_equal ['London'], visible_option_texts
    assert_equal before, native_option_count, 'filtering changed the options the form would post'
    assert_equal 'london', select_value(ID), 'filtering changed the value'
  end

  test 'SS2: filtering ignores case and diacritics in both directions' do
    type 'S', 'A', 'O'
    assert_equal ['São Paulo'], visible_option_texts

    press(*Array.new(3) { :backspace })
    type 'ó'
    assert_includes visible_option_texts, 'Bogotá'
  end

  test 'SS3: clearing the text shows every option again' do
    type 'l', 'o', 'n'
    assert_equal ['London'], visible_option_texts

    press :backspace, :backspace, :backspace

    assert_equal TIMEZONES.size + 1, visible_option_texts.size, 'clearing the filter left options hidden'
    assert_equal native_option_count, visible_option_texts.size
  end

  test 'SS4: a group with nothing left in it is hidden, and the ones with matches stay' do
    id = 'demo_region'
    type 'j', 'a', id: id

    assert_popup id, 'open'
    assert_equal %w[Japan], visible_option_texts(id)
    groups = page.evaluate_script(<<~JS, id)
      Array.from(document.querySelectorAll(`#${arguments[0]}-listbox [role="group"]`))
           .map((group) => [group.querySelector('[id]').textContent.trim(), group.hidden])
    JS
    assert_equal [['Europe', true], ['Americas', true], ['Asia', false]], groups
    assert_operator laid_out_rect("##{id}-listbox")['height'], :>, 0, 'the listbox collapsed entirely'
  end

  test 'SS5: no match shows the empty state, and the count is announced as the filter narrows' do
    # The filter matches anywhere in the label, not just at the start, which is what "contains"
    # means: "lo" reaches Oslo and São Paulo as well as London.
    type 'l', 'o'
    assert_equal ['London', 'Oslo', 'São Paulo'], visible_option_texts
    assert_selector "##{ID}-status", text: '3 results', visible: :all
    assert_selector "##{ID}-empty[hidden]", visible: :all

    press 'n'
    assert_selector "##{ID}-status", text: '1 result', visible: :all

    press 'z'
    assert_empty visible_option_texts
    assert_selector "##{ID}-empty", text: 'No results'
    assert_operator laid_out_rect("##{ID}-empty")['height'], :>, 0, 'the empty state is not rendered'
    assert_selector "##{ID}-status", text: '0 results', visible: :all
    assert_popup ID, 'open'
  end

  test 'SS6: closed, ArrowDown and ArrowUp open on the first and last option, Alt+ArrowDown on neither' do
    page.execute_script("document.getElementById('#{ID}-combobox').focus()")

    press :arrow_down
    assert_popup ID, 'open'
    assert_active ID, 0
    press :escape
    assert_popup ID, 'closed'

    press :arrow_up
    assert_popup ID, 'open'
    assert_active ID, TIMEZONES.size
    press :escape
    assert_popup ID, 'closed'

    press_with(:alt, :arrow_down)
    assert_popup ID, 'open'
    assert_no_active ID
  end

  # Escape is the cancel key, in both configurations: it never changes the value, and it never
  # dispatches anything. Where the field has drifted from the selection it puts the label back;
  # clearing a choice is what a blank option is for.
  { 'with a blank option' => [ID, 'london', 'London'],
    'with no blank option' => %w[demo_favourite paris Paris] }.each do |name, (id, value, label)|
    test "SS7: closed, Escape leaves the value alone and restores the label, #{name}" do
      record_events(id)
      page.execute_script("document.getElementById('#{id}-combobox').focus()")
      assert_equal label, field_value(id)

      press :escape
      assert_equal value, select_value(id), 'Escape changed the value'
      assert_equal label, field_value(id)
      assert_empty recorded_events, 'Escape dispatched an event from a keystroke that means "never mind"'

      # Typed into, then cancelled twice: the first Escape closes the list, the second finds the
      # text already back to the label and leaves everything alone.
      type 'z', 'z', 'z', id: id
      assert_popup id, 'open'
      press :escape
      assert_popup id, 'closed'
      assert_equal label, field_value(id), 'closing did not put the label back'

      press :escape
      assert_equal value, select_value(id), 'a second Escape changed the value'
      assert_equal label, field_value(id)
      assert_empty recorded_events, 'Escape dispatched an event'
    end
  end

  test 'SS8: open, the arrows wrap and Enter takes the active option' do
    record_events(ID)
    type 'l', 'o'
    assert_equal ['London', 'Oslo', 'São Paulo'], visible_option_texts

    press :arrow_down
    assert_active ID, TIMEZONES.index('London') + 1
    press :arrow_up
    assert_active ID, TIMEZONES.index('São Paulo') + 1, 'the arrows did not wrap in search mode'
    press :arrow_down
    assert_active ID, TIMEZONES.index('London') + 1

    press :enter
    assert_popup ID, 'closed'
    assert_equal 'london', select_value(ID)
    assert_equal 'London', field_value
    assert_focus_on_combobox ID
    assert_empty recorded_events, 'choosing the option that was already selected dispatched events'
    assert_equal TIMEZONES.size + 1, visible_option_texts.size, 'the filter outlived the close'
  end

  test 'SS9: open, Enter with no active option closes without choosing anything' do
    type 'b', 'e'
    assert_popup ID, 'open'
    assert_no_active ID, 'typing left visual focus on an option'

    press :enter

    assert_popup ID, 'closed'
    assert_equal 'london', select_value(ID)
    assert_equal 'London', field_value, 'the text was left as what the user typed'
  end

  test 'SS10: text that matches nothing leaves the value alone and the label restored' do
    record_events(ID)
    type 'z', 'z', 'z'
    assert_selector "##{ID}-empty", text: 'No results'

    press :escape

    assert_popup ID, 'closed'
    assert_equal 'london', select_value(ID), 'a search that matched nothing changed the value'
    assert_equal 'London', field_value
    assert_empty recorded_events
    assert_equal TIMEZONES.size + 1, visible_option_texts.size, 'the filter outlived the close'
  end

  test 'SS11: emptying the field and closing selects the blank option' do
    record_events(ID)
    page.execute_script("document.getElementById('#{ID}-combobox').focus()")
    press :arrow_down
    assert_popup ID, 'open'
    press(*Array.new(field_value.length) { :backspace })
    assert_equal '', field_value

    press :tab

    assert_popup ID, 'closed'
    assert_equal '', select_value(ID)
    assert_equal ['input::true', 'change::true'], recorded_events
  end

  test 'SS12: open, Tab closes without turning what was typed into a choice' do
    record_events(ID)
    type 'p', 'a'
    assert_popup ID, 'open'
    assert_equal ['Paris', 'São Paulo'], visible_option_texts

    press :tab

    assert_popup ID, 'closed'
    assert_equal 'london', select_value(ID), 'Tab selected the only match'
    assert_equal 'London', field_value
    assert_empty recorded_events
  end

  test 'SS13: the caret keys hand visual focus back to the text field' do
    type 'l', 'o'
    press :arrow_down
    assert_active ID, TIMEZONES.index('London') + 1

    press :home
    assert_no_active ID, 'Home left visual focus on an option'
    assert_equal 0, page.evaluate_script("document.getElementById('#{ID}-combobox').selectionStart"),
                 'Home did not reach the text field'

    press :arrow_down
    assert_active ID, TIMEZONES.index('London') + 1
    press :arrow_right
    assert_no_active ID, 'ArrowRight left visual focus on an option'
  end

  test 'SS14: DOM focus never leaves the text field, through typing, the button and a click' do
    type 'l', 'o'
    assert_focus_on_combobox ID

    find("##{ID}-popup [role=option]", match: :first).click
    assert_focus_on_combobox ID, 'clicking an option pulled focus out of the text field'
    assert_popup ID, 'closed'

    find("button[aria-label='Show options']", match: :first).click
    assert_popup ID, 'open'
    assert_focus_on_combobox ID, 'the show-options button kept DOM focus'
  end

  test 'SS15: Enter submits the form while the list is closed, and never while it is open' do
    id = 'booking_city'
    page.execute_script(<<~JS)
      window.__submits = 0
      document.getElementById('select-form').addEventListener('submit', (event) => {
        event.preventDefault()
        window.__submits += 1
      })
    JS
    # The form's required Select has to hold a value first, or the browser blocks submission
    # before any key of ours matters -- which is constraint validation working, not this test's
    # subject.
    page.execute_script("document.getElementById('booking_plan-combobox').focus()")
    press :enter
    # Twice: the first option is the prompt, whose value is empty.
    press :arrow_down
    press :arrow_down
    press :enter
    assert_equal 'starter', select_value('booking_plan')

    type 'b', 'e', id: id
    assert_popup id, 'open'
    press :enter
    assert_popup id, 'closed'
    assert_equal 0, page.evaluate_script('window.__submits'), 'Enter submitted the form while the list was open'

    press :enter
    assert_equal 1, page.evaluate_script('window.__submits'),
                 'Enter did not submit the form from a closed search field, as any text input would'
  end
end
