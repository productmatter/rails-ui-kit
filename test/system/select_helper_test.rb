# frozen_string_literal: true

require 'application_system_test_case'
require 'rails_ui_kit/test_helpers'
require_relative 'select_helpers'

# The helper host applications get. Enhanced, the native select is transparent, so a host's
# `select "Pending", from: "Status"` no longer finds it; this drives the widget instead, and these
# are the checks that it keeps working in both modes (ui-select open-questions.md).
class SelectHelperTest < ApplicationSystemTestCase
  include SelectHelpers
  include RailsUiKit::TestHelpers

  setup do
    visit select_path
    disable_transitions
  end

  teardown do
    page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
    page.driver.browser.execute_cdp('Emulation.setTouchEmulationEnabled', enabled: false)
  end

  test 'SH1: it chooses in select-only mode, writing the select and announcing it' do
    record_events('demo_timezone')

    ui_select 'Tokyo', from: 'Timezone'

    assert_equal 'tokyo', select_value('demo_timezone')
    assert_equal 'Tokyo', combobox_label('demo_timezone')
    assert_popup 'demo_timezone', 'closed'
    assert_equal ['input:tokyo:true', 'change:tokyo:true'], recorded_events
  end

  test 'SH2: it chooses in search mode' do
    record_events('demo_city')

    ui_select 'Oslo', from: 'City'

    assert_equal 'oslo', select_value('demo_city')
    assert_equal 'Oslo', control_label('demo_city')
    assert_popup 'demo_city', 'closed'
    assert_equal ['input:oslo:true', 'change:oslo:true'], recorded_events
  end

  test 'SH3: it finds a Select by its own accessible name, and by the name the form posts' do
    ui_select 'Enterprise', from: 'Billing plan'
    assert_equal 'enterprise', select_value('standalone_plan')

    ui_select 'Lisbon', from: 'demo[timezone]'
    assert_equal 'lisbon', select_value('demo_timezone')
  end

  test 'SH4: a missing option fails with a message naming the Select and what it offers' do
    error = assert_raises(RailsUiKit::TestHelpers::OptionNotFound) do
      ui_select 'Atlantis', from: 'Timezone'
    end

    assert_match(/has no option "Atlantis"/, error.message)
    assert_match(/"Timezone"/, error.message)
    assert_match(/It offers:/, error.message)
    assert_match(/London/, error.message)
  end

  test 'SH6: a name that matches two Selects fails the way Capybara own ambiguity does' do
    # The Modal on this page carries a second Select labelled "City", which is exactly the
    # situation where picking the first match silently would write to the wrong control.
    #
    # Both have to be on screen when the ambiguity is checked: a Modal locks the scroll behind it,
    # and a label the viewport has scrolled past is one the driver reports as not displayed, so
    # the Select it names stops answering to it. Hence the scroll, and hence opening the Modal
    # from script rather than by pressing its trigger, which would scroll the page to the trigger.
    page.execute_script("document.getElementById('demo_city').scrollIntoView({ block: 'center' })")
    page.execute_script("document.getElementById('select-modal-trigger').click()")
    assert_selector '#modal_city-combobox'

    error = assert_raises(Capybara::Ambiguous) { ui_select 'Tokyo', from: 'City' }
    assert_match(/found 2 Selects/, error.message)
  end

  test 'SH7: a name that matches nothing says so' do
    error = assert_raises(RailsUiKit::TestHelpers::OptionNotFound) { ui_select 'Tokyo', from: 'Nowhere' }
    assert_match(/found no Ui::SelectComponent for "Nowhere"/, error.message)
  end

  # A prompt is a placeholder, not a listed option (ui-select § Behavior, item 10), so asking for
  # it by name means the button a person would press -- not a listbox row, which isn't there.
  test 'SH8: asking for the prompt by name presses the clear button' do
    record_events('demo_role')
    ui_select 'Admin', from: 'Role'
    assert_equal 'admin', select_value('demo_role')

    ui_select 'Choose a role', from: 'Role'

    assert_equal '', select_value('demo_role')
    assert_equal 'Choose a role', combobox_label('demo_role')
    assert_equal ['input:admin:true', 'change:admin:true', 'input::true', 'change::true'], recorded_events
  end

  test 'SH5: where the Select is not enhanced, it falls back to Capybara own select' do
    page.driver.browser.execute_cdp('Emulation.setTouchEmulationEnabled', enabled: true, maxTouchPoints: 5)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 390, height: 844,
                                                                          deviceScaleFactor: 3, mobile: true)
    assert_no_selector '#standalone_plan-combobox', wait: 5

    ui_select 'Growth', from: 'Billing plan'

    assert_equal 'growth', select_value('standalone_plan')
  end
end
