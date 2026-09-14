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
    page.driver.browser.manage.window.resize_to(1400, 1400)
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
    assert_selector "select#standalone_plan[aria-label='Plan']", visible: :all
    assert_selector "#standalone_plan-combobox[aria-label='Plan']"
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

  test 'SE8: on a coarse pointer, select-only mode stays the native select and its platform picker' do
    id = 'standalone_plan'
    assert_selector "##{id}-combobox"

    emulate_touch
    assert_selector "[data-slot='select']:has(select##{id})[data-enhanced='false']"
    assert_no_selector "##{id}-combobox"
    assert_selector "select##{id}:not([tabindex])[aria-hidden='false']", visible: :all
    assert_operator laid_out_rect("##{id}")['height'], :>, 0, 'the native select is not rendered to tap'

    stop_emulating_touch
    assert_selector "##{id}-combobox"
    assert_selector "[data-slot='select']:has(select##{id})[data-enhanced='true']"
  end

  test 'SE9: native_on_touch: false enhances on a coarse pointer, for a caller who wants one behaviour' do
    emulate_touch

    assert_selector "[data-slot='select']:has(select##{ID})[data-enhanced='true']"
    assert_selector "##{ID}-combobox"
    assert_operator laid_out_rect("##{ID}-combobox")['height'], :>, 0
  end

  private

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
