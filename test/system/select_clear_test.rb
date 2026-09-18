# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# A prompt is a placeholder, not a choice (ui-select § Behavior, item 10). The native select keeps
# the prompt option Rails rendered, because that option is how a select holds "nothing chosen"; the
# listbox never lists it; and a clear button beside the control is the only way back to it. It
# shows only while there is a prompt option to return to, which is also why a page rendered with a
# value has none — Rails rendered no prompt there.
class SelectClearTest < ApplicationSystemTestCase
  include SelectHelpers

  # Select-only and search mode, each with a prompt and nothing selected: the state a person
  # reaches the clear button from.
  SELECT_ONLY = 'demo_role'
  SEARCHING = 'demo_team'

  setup do
    visit select_path
    disable_transitions
    scroll_to_control(SELECT_ONLY)
  end

  def scroll_to_control(id)
    page.execute_script("document.getElementById(arguments[0]).scrollIntoView({ block: 'center' })", id)
  end

  def clear_button(id)
    find("##{id}-clear")
  end

  def assert_clear_showing(id, message = 'the clear button is not showing')
    assert page.has_css?("##{id}-clear"), message
  end

  def assert_no_clear(id, message = 'a clear button is showing where there is nothing to return to')
    assert page.has_no_css?("##{id}-clear"), message
  end

  # The listbox's option texts, as a screen reader and a pointer both meet them.
  def listbox_texts(id)
    page.evaluate_script(<<~JS, id)
      Array.from(document.querySelectorAll(`#${arguments[0]}-listbox [role="option"]`))
           .map((option) => option.textContent.trim())
    JS
  end

  def native_texts(id)
    page.evaluate_script('Array.from(document.getElementById(arguments[0]).options).map((o) => o.text)', id)
  end

  def selected_index(id)
    page.evaluate_script('document.getElementById(arguments[0]).selectedIndex', id)
  end

  # Chooses the first option the way a pointer does, in whichever mode the Select is in.
  def choose_first(id)
    control(id).click
    assert_popup id, 'open'
    find("##{id}-option-0").click
    assert_popup id, 'closed'
  end

  # --- the prompt is not a choice ------------------------------------------------------------

  test 'SC1: the listbox never lists the prompt, in either mode, and the select always holds it' do
    control(SELECT_ONLY).click
    assert_popup SELECT_ONLY, 'open'
    assert_equal %w[Owner Admin Member], listbox_texts(SELECT_ONLY)
    assert_equal ['Choose a role', 'Owner', 'Admin', 'Member'], native_texts(SELECT_ONLY),
                 'the native select lost the option that holds "nothing chosen"'
    press :escape

    scroll_to_control(SEARCHING)
    control(SEARCHING).click
    assert_popup SEARCHING, 'open'
    assert_not_includes listbox_texts(SEARCHING), 'Choose a team'
    assert_equal 'Auckland', listbox_texts(SEARCHING).first
    assert_equal 'Choose a team', native_texts(SEARCHING).first
    press :escape

    # And a blank is untouched: it is a choice in Rails' terms, so it stays listed in both.
    scroll_to_control('demo_city')
    assert_includes native_texts('demo_city'), 'No preference'
    assert_includes listbox_texts('demo_city'), 'No preference'
  end

  test 'SC2: the control still shows the prompt as the placeholder it is' do
    assert_equal 'Choose a role', control_label(SELECT_ONLY)
    assert_selector "##{SELECT_ONLY}-combobox [data-placeholder='true']", text: 'Choose a role'
    assert_equal '', select_value(SELECT_ONLY)
  end

  # --- pressing it -----------------------------------------------------------------------------

  test 'SC3: select-only mode — a choice shows it, pressing it returns to the prompt and moves focus' do
    record_events(SELECT_ONLY)
    assert_no_clear SELECT_ONLY, 'a Select with nothing chosen has nothing to clear'

    choose_first(SELECT_ONLY)
    assert_equal 'owner', select_value(SELECT_ONLY)
    assert_clear_showing SELECT_ONLY

    clear_button(SELECT_ONLY).click

    assert_equal '', select_value(SELECT_ONLY)
    assert_equal 0, selected_index(SELECT_ONLY), 'the select is not on the prompt option'
    assert_equal 'Choose a role', control_label(SELECT_ONLY)
    assert_selector "##{SELECT_ONLY}-combobox [data-placeholder='true']"
    assert_equal ['input:owner:true', 'change:owner:true', 'input::true', 'change::true'], recorded_events,
                 'clearing is a user choice like any other, so it dispatches what one dispatches'
    # Once pressed it is gone, so focus goes to the control rather than being left on nothing.
    assert_focus_on_combobox SELECT_ONLY, 'focus was left on a button that is no longer there'
    assert_no_clear SELECT_ONLY
  end

  test 'SC4: search mode — the same press, with focus back on the trigger' do
    scroll_to_control(SEARCHING)
    record_events(SEARCHING)

    choose_first(SEARCHING)
    assert_equal 'auckland', select_value(SEARCHING)
    assert_clear_showing SEARCHING

    clear_button(SEARCHING).click

    assert_equal '', select_value(SEARCHING)
    assert_equal 0, selected_index(SEARCHING)
    assert_equal 'Choose a team', control_label(SEARCHING)
    assert_equal ['input:auckland:true', 'change:auckland:true', 'input::true', 'change::true'], recorded_events
    assert_focus_on_trigger SEARCHING, 'focus was left on a button that is no longer there'
    assert_no_clear SEARCHING
  end

  test 'SC5: a required Select it has cleared blocks its form again' do
    id = 'booking_plan'
    scroll_to_control(id)
    page.execute_script(<<~JS)
      window.__submits = 0
      document.getElementById('select-form').addEventListener('submit', () => { window.__submits += 1 })
    JS
    # The other required Select in this form is answered first, so what blocks the form is the one
    # under test rather than whichever the browser reaches first.
    focus_trigger('booking_city')
    press :enter
    press :arrow_down
    press :enter
    assert_not_equal '', select_value('booking_city')

    scroll_to_control(id)
    choose_first(id)
    assert_equal 'starter', select_value(id)
    assert_not page.evaluate_script("document.getElementById('#{id}').validity.valueMissing")

    clear_button(id).click

    assert_equal '', select_value(id)
    assert page.evaluate_script("document.getElementById('#{id}').validity.valueMissing"),
           'a cleared required select does not report itself invalid, so nothing blocks the form'

    find('#select-form button[type=submit]').click
    assert_equal 0, page.evaluate_script('window.__submits'), 'a cleared required Select let the form through'
    assert_focus_on_combobox id, 'the browser could not land focus on the control it complained about'
  end

  # --- where it never shows --------------------------------------------------------------------

  test 'SC6: no clear button where there is no prompt option to return to' do
    # Rendered with a value: Rails renders no prompt, so there is no placeholder state to go back
    # to. Clearing a saved value is what include_blank: is for, and that blank is a listed option.
    assert_no_clear 'demo_timezone'
    assert_no_selector '#demo_timezone-clear', visible: :all, wait: 0

    # include_blank: and no prompt.
    assert_no_clear 'demo_city'
    assert_no_selector '#demo_city-clear', visible: :all, wait: 0
  end

  test 'SC7: a disabled Select shows none, even after its value is set from host code' do
    id = 'demo_archived'
    scroll_to_control(id)
    assert_no_clear id

    page.execute_script(<<~JS, id)
      const select = document.getElementById(arguments[0])
      select.value = 'growth'
      select.dispatchEvent(new Event('change', { bubbles: true }))
    JS

    assert_equal 'growth', select_value(id)
    assert_selector "##{id}-combobox[aria-disabled='true']"
    assert_no_clear id, 'a disabled Select offered a button that would change its value'
  end

  # --- the button itself -------------------------------------------------------------------

  test 'SC8: it is a sibling of the control, a 24px target, named for what it clears' do
    choose_first(SELECT_ONLY)
    assert_clear_showing SELECT_ONLY

    sibling = page.evaluate_script(<<~JS, SELECT_ONLY)
      (() => {
        const button = document.getElementById(`${arguments[0]}-clear`)
        const control = document.getElementById(`${arguments[0]}-combobox`)
        return button.parentElement === control.parentElement && !control.contains(button)
      })()
    JS
    assert sibling, 'the clear button is inside the control: interactive content there is invalid'

    rect = laid_out_rect("##{SELECT_ONLY}-clear")
    assert_operator rect['width'], :>=, 24, 'the target is under the 24x24 floor (WCAG 2.5.8)'
    assert_operator rect['height'], :>=, 24, 'the target is under the 24x24 floor (WCAG 2.5.8)'

    # The computed name Chrome hands a screen reader, not the attribute it was built from.
    assert_equal "#{I18n.t('rails_ui_kit.select.clear_label')} Role", accessible_name("##{SELECT_ONLY}-clear")
  end

  test 'SC9: it draws a flush outline when focused, and no box-shadow' do
    choose_first(SELECT_ONLY)
    focus_visibly(clear_button(SELECT_ONLY))

    outline = outline_of(clear_button(SELECT_ONLY))
    assert_not_equal 'none', outline['style'], 'the clear button has no focus indicator'
    assert_operator outline['width'].to_f, :>=, 2, 'the focus outline is too thin'
    assert_equal 'none', page.evaluate_script('getComputedStyle(arguments[0]).boxShadow', clear_button(SELECT_ONLY)),
                 'a box-shadow focus ring vanishes in forced-colors mode'
    ratio = contrast_ratio(color_of(:outline, clear_button(SELECT_ONLY)),
                           color_of(:background, find("##{SELECT_ONLY}-combobox")))
    assert_operator ratio, :>=, 3, "the focus ring is #{ratio.round(2)}:1 on the control it sits in"
  end

  test 'SC10: the control keeps its text clear of the button, and only while it is showing' do
    before = padding_end(SELECT_ONLY)

    choose_first(SELECT_ONLY)
    assert_clear_showing SELECT_ONLY
    after = padding_end(SELECT_ONLY)

    assert_operator after, :>, before, 'the control gave the clear button no room, so its text runs under it'
    # Where the control's text may actually reach: its box, less the room it just took.
    box = laid_out_rect("##{SELECT_ONLY}-combobox")
    button = laid_out_rect("##{SELECT_ONLY}-clear")
    assert_operator box['right'] - after, :<=, button['left'], 'the control text box reaches under the button'

    clear_button(SELECT_ONLY).click
    assert_equal before, padding_end(SELECT_ONLY), 'the room outlived the button that needed it'
  end

  def padding_end(id)
    page.evaluate_script(<<~JS, id)
      parseFloat(getComputedStyle(document.getElementById(`${arguments[0]}-combobox`)).paddingInlineEnd)
    JS
  end

  # --- the keyboard, the popup and reset -------------------------------------------------------

  test 'SC11: Tab from the control reaches it, and Enter and Space press it' do
    %i[enter space].each do |key|
      choose_first(SELECT_ONLY)
      assert_clear_showing SELECT_ONLY

      focus_combobox(SELECT_ONLY)
      press :tab
      assert_equal "#{SELECT_ONLY}-clear", focused_id, "Tab from the control did not reach the clear button (#{key})"

      press key
      assert_equal '', select_value(SELECT_ONLY), "#{key} did not press the clear button"
      assert_focus_on_combobox SELECT_ONLY
    end
  end

  test 'SC12: no key on the control clears it: the button is the only way' do
    choose_first(SELECT_ONLY)
    focus_combobox(SELECT_ONLY)

    %i[escape backspace delete].each do |key|
      press key
      assert_equal 'owner', select_value(SELECT_ONLY), "#{key} cleared the Select"
    end

    press_with(:alt, :backspace)
    assert_equal 'owner', select_value(SELECT_ONLY), 'Alt+Backspace cleared the Select'
  end

  test 'SC13: a press while the popup is open closes the popup first' do
    choose_first(SELECT_ONLY)
    control(SELECT_ONLY).click
    assert_popup SELECT_ONLY, 'open'

    clear_button(SELECT_ONLY).click

    assert_popup SELECT_ONLY, 'closed'
    assert_equal '', select_value(SELECT_ONLY)
    assert_focus_on_combobox SELECT_ONLY
  end

  test 'SC14: a form reset that puts the select back on the prompt hides it again' do
    id = 'booking_plan'
    scroll_to_control(id)
    choose_first(id)
    assert_clear_showing id

    find('#select-form button[type=reset]').click

    assert_equal '', select_value(id)
    assert_equal 'Choose a plan', control_label(id)
    assert_no_clear id, 'the button outlived the value that justified it'
  end

  # --- accessibility ---------------------------------------------------------------------------

  test 'SC15: the page passes an axe audit with the button showing, light and dark, in both modes' do
    choose_first(SELECT_ONLY)
    scroll_to_control(SEARCHING)
    choose_first(SEARCHING)
    assert_clear_showing SELECT_ONLY
    assert_clear_showing SEARCHING

    %w[light dark].each do |mode|
      use_dark_mode(mode == 'dark')
      assert_accessible(within: '#select-prompt-preview')
    end
  end

  # ax_node (Chrome's accessibility tree for one element) comes from BrowserHelpers.
  def accessible_name(selector)
    ax_node(selector)&.dig('name', 'value')
  end
end
