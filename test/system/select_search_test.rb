# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# Search mode's key table (ui-select § Behavior, items 17, 21 and 22), driven with real
# keypresses. Two elements, two jobs: the trigger shows the value and the field in the popup takes
# the query. The query is never the value — the field is empty on every open and discarded on
# every close — and filtering is a view over the same options, so the select's own <option>s never
# change and the value can always still submit.
class SelectSearchTest < ApplicationSystemTestCase
  include SelectHelpers

  ID = 'demo_city'
  LONDON = 11 # the blank option is first, so every index is one past the select-only page's

  setup do
    visit select_path
    disable_transitions
    page.execute_script("document.getElementById('#{ID}-trigger').scrollIntoView({ block: 'center' })")
  end

  # Opens the way a person does, then types into the field the popup put focus in.
  def type(*characters, id: ID)
    open_search(id) unless page.has_css?("##{id}-trigger[aria-expanded='true']", wait: 0)
    press(*characters)
  end

  def open_search(id = ID)
    focus_trigger(id)
    press :enter
    assert_popup id, 'open'
    assert_focus_on_search id
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

  # --- the shape ----------------------------------------------------------------------------

  test 'SS1: the trigger owns the listbox and the field in the popup is the only combobox' do
    trigger = find("##{ID}-trigger")
    assert_equal 'button', trigger.tag_name
    assert_equal 'listbox', trigger['aria-haspopup']
    assert_equal "#{ID}-listbox", trigger['aria-controls']
    assert_equal 'London', control_label(ID), 'the trigger does not show the value'

    open_search
    field = find("##{ID}-search")
    assert_equal 'combobox', field['role']
    assert_equal 'list', field['aria-autocomplete']
    assert_equal "#{ID}-listbox", field['aria-controls']
    assert_equal 'true', field['aria-expanded'], 'the field says the list it controls is closed'
    assert_not page.evaluate_script("document.getElementById('#{ID}-search').hasAttribute('name')"),
               'a named search field would submit a second value'

    root = trigger.find(:xpath, "ancestor::*[@data-slot='select']")
    assert_equal 1, root.all('[role=combobox]', visible: :all).size,
                 'the widget offers a screen reader two comboboxes'
    # First in the popup, above the list it filters.
    ids = find("##{ID}-popup").all('input, [role=listbox]').map { |element| element['id'] }
    assert_equal %W[#{ID}-search #{ID}-listbox], ids
  end

  # The field itself is outline-none, so without this the caret would be the only cue that the
  # popup put focus in it -- and a caret is not a focus indicator (WCAG 2.4.11 / 1.4.11). The line
  # is drawn on the row, so the glyph and the field read as one focused thing, and it is an
  # outline rather than a box-shadow because forced-colors mode drops shadows.
  test 'SS1b: the search row draws a visible focus line while its field is focused' do
    open_search
    assert_focus_on_search ID
    row = find("##{ID}-search").find(:xpath, '..')

    outline = outline_of(row)
    assert_not_equal 'none', outline['style'], 'the search row shows nothing while its field has focus'
    assert_operator outline['width'].to_f, :>=, 2, "the focus line is #{outline['width']}, under 2px"

    ratio = contrast_ratio(color_of(:outline, row), color_of(:background, find("##{ID}-popup")))
    assert_operator ratio, :>=, 3, "the focus line is #{ratio.round(2)}:1 on the popup it is drawn in"
  end

  test 'SS2: typing filters the listbox and never the select' do
    before = native_option_count
    assert_operator before, :>, 5

    type 'l', 'o', 'n'

    assert_popup ID, 'open'
    assert_equal ['London'], visible_option_texts
    assert_equal before, native_option_count, 'filtering changed the options the form would post'
    assert_equal 'london', select_value(ID), 'filtering changed the value'
    assert_equal 'London', control_label(ID), 'the trigger stopped showing the native select label'
  end

  test 'SS3: filtering ignores case and diacritics in both directions' do
    type 'S', 'A', 'O'
    assert_equal ['São Paulo'], visible_option_texts

    press(*Array.new(3) { :backspace })
    press 'ó'
    assert_includes visible_option_texts, 'Bogotá'
  end

  test 'SS4: clearing the text shows every option again' do
    type 'l', 'o', 'n'
    assert_equal ['London'], visible_option_texts

    press :backspace, :backspace, :backspace

    assert_equal TIMEZONES.size + 1, visible_option_texts.size, 'clearing the filter left options hidden'
    assert_equal native_option_count, visible_option_texts.size
  end

  test 'SS5: a group with nothing left in it is hidden, and the ones with matches stay' do
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

  test 'SS6: no match shows the empty state, and the count is announced as the filter narrows' do
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

  # --- closed, on the trigger ----------------------------------------------------------------

  test 'SS7: Enter, Space and Alt+ArrowDown open onto an empty field with no active option' do
    [:enter, :space, nil].each_with_index do |key, index|
      focus_trigger(ID)
      key ? press(key) : press_with(:alt, :arrow_down)

      assert_popup ID, 'open'
      assert_focus_on_search ID, "key #{index} did not move DOM focus into the search field"
      assert_equal '', search_value(ID), "key #{index} opened onto a field that was not empty"
      assert_no_active ID, "key #{index} opened with an option already active"
      assert_equal TIMEZONES.size + 1, visible_option_texts.size

      press :escape
      assert_popup ID, 'closed'
    end
  end

  test 'SS8: ArrowDown and ArrowUp open on the first and last option, with focus in the field' do
    focus_trigger(ID)
    press :arrow_down
    assert_popup ID, 'open'
    assert_active ID, 0
    assert_focus_on_search ID
    press :escape
    assert_popup ID, 'closed'

    focus_trigger(ID)
    press :arrow_up
    assert_popup ID, 'open'
    assert_active ID, TIMEZONES.size
    assert_focus_on_search ID
  end

  test 'SS9: a printable character on the closed trigger opens, seeds the field and filters' do
    focus_trigger(ID)

    press 'o'

    assert_popup ID, 'open'
    assert_focus_on_search ID
    assert_equal 'o', search_value(ID), 'the character that opened the list was swallowed'
    assert_no_active ID
    assert_includes visible_option_texts, 'Oslo'
    assert_not_includes visible_option_texts, 'Berlin', 'the seed opened the list without filtering it'

    # And typing carries on in the field it seeded.
    press 's'
    assert_equal 'os', search_value(ID)
    assert_equal %w[Lagos Oslo], visible_option_texts
  end

  test 'SS10: Escape and Tab on the closed trigger are not handled' do
    id = 'booking_city'
    page.execute_script("document.getElementById('#{id}-trigger').scrollIntoView({ block: 'center' })")
    focus_trigger(id)

    press :escape
    assert_popup id, 'closed'
    assert_focus_on_trigger id, 'Escape moved focus off a closed trigger'

    press :tab
    assert_popup id, 'closed'
    assert_not_equal "#{id}-trigger", focused_id, 'Tab left focus on the trigger'
  end

  # --- open, in the search field ---------------------------------------------------------------

  test 'SS11: the arrows wrap and Enter takes the active option, returning focus to the trigger' do
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
    assert_equal 'London', control_label(ID)
    assert_focus_on_trigger ID, 'Enter did not hand focus back to the trigger'
    assert_empty recorded_events, 'choosing the option that was already selected dispatched events'
    assert_equal TIMEZONES.size + 1, visible_option_texts.size, 'the filter outlived the close'
  end

  test 'SS12: Enter with no active option closes without choosing anything' do
    record_events(ID)
    type 'b', 'e'
    assert_popup ID, 'open'
    assert_no_active ID, 'typing left visual focus on an option'

    press :enter

    assert_popup ID, 'closed'
    assert_equal 'london', select_value(ID)
    assert_equal 'London', control_label(ID), 'the trigger showed what the user typed'
    assert_focus_on_trigger ID
    assert_empty recorded_events
  end

  test 'SS13: Escape closes with no change and returns focus to the trigger' do
    record_events(ID)
    type 'z', 'z', 'z'
    assert_selector "##{ID}-empty", text: 'No results'

    press :escape

    assert_popup ID, 'closed'
    assert_equal 'london', select_value(ID), 'a search that matched nothing changed the value'
    assert_equal 'London', control_label(ID)
    assert_focus_on_trigger ID, 'Escape did not hand focus back to the trigger'
    assert_empty recorded_events
    assert_equal TIMEZONES.size + 1, visible_option_texts.size, 'the filter outlived the close'
  end

  test 'SS14: Tab closes without choosing, and focus moves on past the trigger' do
    record_events(ID)
    type 'p', 'a'
    assert_popup ID, 'open'
    assert_equal ['Paris', 'São Paulo'], visible_option_texts
    press :arrow_down
    assert_active ID, TIMEZONES.index('Paris') + 1, 'nothing was active, so the Tab proves less'

    press :tab

    assert_popup ID, 'closed'
    assert_equal 'london', select_value(ID), 'Tab selected the active option'
    assert_equal 'London', control_label(ID)
    assert_empty recorded_events
    assert_not_equal "#{ID}-trigger", focused_id, 'Tab handed focus back to the trigger instead of moving on'
    assert_not_equal "#{ID}-search", focused_id
    assert_not page.evaluate_script("document.getElementById('#{ID}-popup').contains(document.activeElement)")
  end

  test 'SS15: the editing keys hand visual focus back to the search field' do
    type 'l', 'o'
    press :arrow_down
    assert_active ID, TIMEZONES.index('London') + 1

    press :home
    assert_no_active ID, 'Home left visual focus on an option'
    assert_equal 0, page.evaluate_script("document.getElementById('#{ID}-search').selectionStart"),
                 'Home did not reach the search field'

    press :arrow_down
    assert_active ID, TIMEZONES.index('London') + 1
    press :arrow_right
    assert_no_active ID, 'ArrowRight left visual focus on an option'

    press :arrow_down
    assert_active ID, TIMEZONES.index('London') + 1
    press :backspace
    assert_no_active ID, 'Backspace left visual focus on an option'
    # The caret was left after the "l" by ArrowRight, so Backspace takes that character.
    assert_equal 'o', search_value(ID)
  end

  # --- the query is never the value -----------------------------------------------------------

  test 'SS16: the field is empty on every open, however the last one ended' do
    %i[enter escape].each do |ending|
      type 'l', 'o', 'n'
      assert_equal 'lon', search_value(ID)
      press ending
      assert_popup ID, 'closed'

      open_search
      assert_equal '', search_value(ID), "the field kept its query across a close by #{ending}"
      assert_equal TIMEZONES.size + 1, visible_option_texts.size
      press :escape
      assert_popup ID, 'closed'
    end
  end

  test 'SS17: the trigger tracks the native select through a choice and a form reset' do
    id = 'booking_city'
    page.execute_script("document.getElementById('#{id}-trigger').scrollIntoView({ block: 'center' })")
    assert_equal 'Choose a city', control_label(id), 'the trigger does not show the prompt'

    # Chosen with the pointer, which never touches the trigger's own text.
    find("##{id}-trigger").click
    assert_popup id, 'open'
    # The prompt is not one of the options (§ Behavior, item 10), so the cities start at index 0.
    find("##{id}-option-2").click
    assert_popup id, 'closed'
    assert_equal option_value(id, 2), select_value(id)
    assert_equal 'Bogotá', control_label(id)

    # Reset from the form itself: the browser restores the select's default selectedness, and the
    # trigger re-derives from it rather than keeping what it was showing.
    page.execute_script("document.getElementById('select-form').reset()")
    assert_equal '', select_value(id)
    assert_selector "##{id}-trigger", text: 'Choose a city'
  end

  test 'SS18: a Turbo Stream that replaces the Select leaves a trigger on the new value' do
    root = page.evaluate_script("document.getElementById('#{ID}').closest('[data-slot=select]').outerHTML")
    swapped = root.sub('value="oslo"', 'value="oslo" selected="selected"')
    assert_not_equal root, swapped, 'the replacement markup is identical to what is already there'

    page.execute_script("document.getElementById('#{ID}').closest('[data-slot=select]').id = 'swap-target'")
    page.execute_script('Turbo.renderStreamMessage(arguments[0])',
                        %(<turbo-stream action="replace" target="swap-target"><template>#{swapped}</template></turbo-stream>))

    assert_selector "##{ID}-trigger", text: 'Oslo'
    assert_equal 'oslo', select_value(ID)

    # And the replacement is a working Select, not just the right markup.
    open_search
    press 'l', 'o', 'n'
    assert_equal ['London'], visible_option_texts
    press :arrow_down
    press :enter
    assert_equal 'london', select_value(ID)
    assert_equal 'London', control_label(ID)
  end

  test 'SS19: Enter never submits the form, open or closed' do
    id = 'booking_city'
    page.execute_script(<<~JS)
      window.__submits = 0
      document.getElementById('select-form').addEventListener('submit', (event) => {
        event.preventDefault()
        window.__submits += 1
      })
    JS
    page.execute_script("document.getElementById('#{id}-trigger').scrollIntoView({ block: 'center' })")
    focus_trigger(id)

    press :enter
    assert_popup id, 'open'
    press :enter
    assert_popup id, 'closed'
    assert_focus_on_trigger id

    press :enter
    assert_popup id, 'open'
    assert_equal 0, page.evaluate_script('window.__submits'),
                 'the trigger submitted the form: a button with no type="button" would'
  end
end
