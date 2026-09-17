# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# The swap from the server-rendered native select to the combobox, and what has to stay true
# across it: the same box, the select still rendered and still the value store, and the control
# still named (ui-select § Behavior, items 2 and 26).
class SelectEnhancementTest < ApplicationSystemTestCase
  include SelectHelpers

  ID = 'demo_timezone'

  setup do
    visit select_path
    disable_transitions
  end

  teardown { stop_emulating_touch }

  test 'SE1: enhanced, the select is out of sight and out of the accessibility tree but still rendered' do
    assert_selector "[data-slot='select'][data-enhanced='true']"
    assert_selector "select##{ID}[aria-hidden='true'][tabindex='-1']", visible: :all

    assert_equal '0', style_of("##{ID}", 'opacity')
    assert_equal 'none', style_of("##{ID}", 'pointerEvents')
    # Still laid out: a browser cannot focus, or show a validation bubble on, a control it does
    # not render, so `required` would block submission with nothing to show for it.
    assert_not_equal 'none', style_of("##{ID}", 'display'), 'the select was taken out of layout'
    assert_no_selector "select##{ID}[hidden]", visible: :all
    assert_no_selector "select##{ID}[inert]", visible: :all
    assert_operator laid_out_rect("##{ID}")['height'], :>, 0
  end

  test 'SE2: the combobox lands exactly on the box the select occupies, so the swap shifts nothing' do
    combobox_rect = laid_out_rect("##{ID}-combobox")
    select_rect = laid_out_rect("##{ID}")

    %w[top left width height].each do |side|
      assert_in_delta combobox_rect[side], select_rect[side], 0.5,
                      "the select's #{side} does not match the combobox's, so enhancing moves the page"
    end
  end

  test 'SE3: the popup matches the control width and opens under it' do
    combobox(ID).click
    assert_popup ID, 'open'

    control = laid_out_rect("##{ID}-combobox")
    popup = laid_out_rect("##{ID}-popup")

    assert_in_delta control['width'], popup['width'], 1, 'the popup does not match the control width'
    assert_in_delta control['left'], popup['left'], 1
    assert_operator popup['top'], :>=, control['bottom'] - 1, 'the popup is not anchored under the control'
  end

  test 'SE4: nothing in the popup carries autofocus, and opening never moves DOM focus into it' do
    assert_no_selector "##{ID}-popup [autofocus]", visible: :all

    focus_combobox(ID)
    press :arrow_down
    assert_popup ID, 'open'
    assert_focus_on_combobox ID, 'opening the popup moved DOM focus into it'
  end

  test 'SE5: the combobox and its listbox are named by the Field label' do
    label_id = "#{ID}-label"
    assert_selector "label##{label_id}[for='#{ID}']"
    assert_selector "##{ID}-combobox[aria-labelledby='#{label_id}']"
    assert_selector "##{ID}-listbox[aria-labelledby='#{label_id}']", visible: :all
  end

  test 'SE6: without a Field, the caller name reaches both the select and the combobox' do
    assert_selector "select#standalone_plan[aria-label='Billing plan']", visible: :all
    assert_selector "#standalone_plan-combobox[aria-label='Billing plan']"
    assert_no_selector '#standalone_plan-combobox[aria-labelledby]'
  end

  test 'SE7: host code changes the value by writing the select and dispatching change' do
    assert_equal 'London', combobox_label(ID)

    page.execute_script(<<~JS, ID)
      const select = document.getElementById(arguments[0])
      select.value = 'tokyo'
      select.dispatchEvent(new Event('change', { bubbles: true }))
    JS

    assert_selector "##{ID}-combobox", text: 'Tokyo'
    assert_selector "##{ID}-option-19[data-selected='true']", visible: :all
    assert_selector "##{ID}-listbox [role=option][data-selected='true']", count: 1, visible: :all
  end

  # The swap is the component's own CSS, so the browser makes it the moment the pointer changes;
  # the accessibility tree is ui--select's, so it is checked in Chrome's own tree, both ways.
  test 'SE8: on a coarse pointer, select-only mode stays the native select and its platform picker' do
    id = 'standalone_plan'
    assert_combobox_is_the_control id

    emulate_touch
    assert_no_selector "##{id}-combobox", wait: 5
    assert_selector "select##{id}:not([tabindex])[aria-hidden='false']", visible: true
    assert_operator laid_out_rect("##{id}")['height'], :>, 0, 'the native select is not rendered to tap'
    assert_equal '1', style_of("##{id}", 'opacity'), 'the native select is still transparent'
    assert ax_node("select##{id}"), 'the native select is not in the accessibility tree'
    assert_nil ax_node("##{id}-combobox"), 'the hidden combobox is still in the accessibility tree'

    stop_emulating_touch
    assert_combobox_is_the_control id
  end

  test 'SE9: native_on_touch: false enhances on a coarse pointer, for a caller who wants one behaviour' do
    emulate_touch

    assert_selector "[data-slot='select']:has(select##{ID})[data-enhanced='true']"
    assert_selector "##{ID}-combobox"
    assert_operator laid_out_rect("##{ID}-combobox")['height'], :>, 0
  end

  # Checked again after each way a Select can be re-rendered, because that -- not page load -- is
  # where a stale copy left behind would show up as two elements sharing an id.
  test 'SE10: every id on the page is unique, on load and after a re-render' do
    assert_operator page.evaluate_script("document.querySelectorAll('[data-slot=select]').length"), :>, 5
    assert_empty duplicate_ids, 'two elements share an id on load'

    page.execute_script("document.getElementById('trip_city-combobox').scrollIntoView({ block: 'center' })")
    find('#trip_city-combobox').click
    assert_popup 'trip_city', 'open'
    find('#trip_city-option-4').click
    find('#select-round-trip-submit').click
    assert_selector '[data-slot=field-error]'
    assert_empty duplicate_ids, 'the 422 re-render left a stale copy behind'

    page.execute_script(<<~JS)
      const root = document.getElementById('demo_status').closest('[data-slot=select]')
      root.id = 'stream-target'
      Turbo.renderStreamMessage(
        `<turbo-stream action="replace" target="stream-target"><template>${root.outerHTML}</template></turbo-stream>`
      )
    JS
    assert_selector '#demo_status-combobox'
    assert_empty duplicate_ids, 'a Turbo Stream replace left a stale copy behind'
  end

  test 'SE11: two Selects on one page keep their own active option and their own value' do
    first = ID
    second = 'demo_status'

    focus_combobox(first)
    press :enter
    press :end
    assert_popup first, 'open'
    assert_active first, 19
    assert_no_active second

    press :escape
    assert_popup first, 'closed'
    focus_combobox(second)
    press :enter
    press :home
    assert_active second, 0
    assert_no_active first, "the second Select moved the first one's active option"

    press :enter
    assert_equal 'pending', select_value(second)
    assert_equal 'london', select_value(first), 'choosing in one Select changed the other'
    assert_equal 'London', combobox_label(first)
  end

  private

  def duplicate_ids
    page.evaluate_script(<<~JS)
      (() => {
        const counts = {}
        for (const element of document.querySelectorAll('[id]')) counts[element.id] = (counts[element.id] || 0) + 1
        return Object.entries(counts).filter(([, count]) => count > 1).map(([id]) => id)
      })()
    JS
  end

  def assert_combobox_is_the_control(id)
    assert_selector "##{id}-combobox", visible: true
    assert_operator laid_out_rect("##{id}-combobox")['height'], :>, 0
    assert_selector "select##{id}[tabindex='-1'][aria-hidden='true']", visible: :all
    assert_equal '0', style_of("##{id}", 'opacity'), 'the select is not laid transparently over the combobox'
    assert ax_node("##{id}-combobox"), 'the combobox is not in the accessibility tree'
    assert_nil ax_node("select##{id}"), 'the covered select is still in the accessibility tree'
  end

  # ax_node (Chrome's accessibility tree for one element) comes from ApplicationSystemTestCase's
  # BrowserHelpers.
  def style_of(selector, property)
    page.evaluate_script('getComputedStyle(document.querySelector(arguments[0]))[arguments[1]]',
                         selector, property)
  end

  # (pointer: coarse) is not one of the media features setEmulatedMedia accepts; a touch-capable
  # mobile device is what actually makes it match.
  def emulate_touch
    page.driver.browser.execute_cdp('Emulation.setTouchEmulationEnabled', enabled: true, maxTouchPoints: 5)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 390, height: 844,
                                                                          deviceScaleFactor: 3, mobile: true)
    assert page.evaluate_script("matchMedia('(pointer: coarse)').matches"), 'the coarse pointer was not emulated'
  end

  def stop_emulating_touch
    page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
    page.driver.browser.execute_cdp('Emulation.setTouchEmulationEnabled', enabled: false)
  end
end
