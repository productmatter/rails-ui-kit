# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'
require 'rails_ui_kit/test_helpers'

# `multiple: true`, in the browser: a pick toggles and the list stays open, the control joins the
# chosen labels or shows the empty label, Space and Enter toggle the active option, Escape closes,
# search still filters, and the form posts name[] -- on the Select page's "Several choices" demo.
class SelectMultipleTest < ApplicationSystemTestCase
  include SelectHelpers
  include RailsUiKit::TestHelpers

  ROUNDS = 'filter_rounds'
  CITIES = 'filter_cities'

  setup { visit select_path }

  # What the form would post for the field: FormData, so the hidden empty value is counted too.
  def posted(name)
    page.evaluate_script("new FormData(document.getElementById('select-multiple-form')).getAll(arguments[0])", name)
  end

  def chosen(id)
    page.evaluate_script('Array.from(document.getElementById(arguments[0]).selectedOptions).map((o) => o.value)', id)
  end

  def aria_selected(id)
    page.evaluate_script(
      "Array.from(document.querySelectorAll('##{id}-listbox [role=option]')).map((o) => o.getAttribute('aria-selected'))"
    )
  end

  test 'SM1: nothing chosen shows the empty label as a placeholder, and posts only the hidden empty value' do
    assert_equal 'Any round', control_label(ROUNDS)
    assert_selector "##{ROUNDS}-combobox [data-placeholder='true']"
    assert_equal [''], posted('filter[rounds][]')
  end

  test 'SM2: a click toggles one option, the list stays open, and the label joins what is chosen' do
    control(ROUNDS).click
    assert_popup(ROUNDS, 'open')

    find("##{ROUNDS}-option-0").click
    find("##{ROUNDS}-option-3").click

    assert_popup(ROUNDS, 'open')
    assert_equal %w[starter owner], chosen(ROUNDS)
    assert_equal 'Starter, Owner', control_label(ROUNDS)
    assert_equal %w[true false false true false false], aria_selected(ROUNDS)
    assert_selector "##{ROUNDS}-option-0[data-selected='true']"

    find("##{ROUNDS}-option-0").click
    assert_equal %w[owner], chosen(ROUNDS)
    assert_equal 'Owner', control_label(ROUNDS)
  end

  test 'SM3: Space and Enter toggle the active option and keep the list open; Escape closes' do
    focus_combobox(ROUNDS)
    press(:arrow_down)
    assert_popup(ROUNDS, 'open')
    # Opened on nothing chosen, nothing is active yet -- the single-value key table, unchanged.
    press(:arrow_down)
    assert_active(ROUNDS, 0)

    press(:space)
    press(:arrow_down)
    press(:enter)
    assert_popup(ROUNDS, 'open')
    assert_equal %w[starter growth], chosen(ROUNDS)

    press(:space)
    assert_equal %w[starter], chosen(ROUNDS)

    press(:escape)
    assert_popup(ROUNDS, 'closed')
    assert_focus_on_combobox(ROUNDS)
    assert_equal 'Starter', control_label(ROUNDS)
  end

  test 'SM4: Tab closes without toggling the option it leaves' do
    focus_combobox(ROUNDS)
    press(:arrow_down)
    assert_popup(ROUNDS, 'open')
    press(:tab)

    assert_popup(ROUNDS, 'closed')
    assert_empty chosen(ROUNDS)
  end

  test 'SM5: each pick dispatches input and change from the select' do
    record_events(ROUNDS)
    control(ROUNDS).click
    find("##{ROUNDS}-option-1").click

    assert_equal ['input:growth:true', 'change:growth:true'], recorded_events
  end

  test 'SM6: search filters, Enter toggles the active city, and the list stays open' do
    assert_equal 'London, Paris', control_label(CITIES)

    control(CITIES).click
    assert_popup(CITIES, 'open')
    find("##{CITIES}-search").send_keys('tok')
    press(:arrow_down)
    press(:enter)

    assert_popup(CITIES, 'open')
    assert_equal %w[london paris tokyo], chosen(CITIES)

    press(:escape)
    assert_popup(CITIES, 'closed')
    assert_equal 'London, Paris, Tokyo', control_label(CITIES)
  end

  test 'SM7: the form posts every chosen value under name[], after the hidden empty one' do
    control(ROUNDS).click
    find("##{ROUNDS}-option-2").click
    find("##{ROUNDS}-option-4").click

    assert_equal ['', 'enterprise', 'admin'], posted('filter[rounds][]')
  end

  test 'SM8: a form reset puts the chosen values and the label back' do
    control(CITIES).click
    find("##{CITIES}-option-0").click
    press(:escape)
    assert_equal 'Auckland, London, Paris', control_label(CITIES)

    page.execute_script("document.getElementById('select-multiple-form').reset()")

    assert_text 'London, Paris'
    assert_equal %w[london paris], chosen(CITIES)
  end

  test 'SM9: ui_select adds an option, leaves a chosen one chosen, and closes the list' do
    ui_select 'Growth', from: 'Offer on'
    ui_select 'Admin', from: 'Offer on'
    ui_select 'Growth', from: 'Offer on'

    assert_equal %w[growth admin], chosen(ROUNDS)
    assert_popup(ROUNDS, 'closed')
  end

  test 'SM11: typing makes the first match active, so Enter toggles it without an arrow' do
    # Keys only: a pointer left resting where the list re-renders would activate the option that
    # moves under it, which is hover doing its job and not what this test measures.
    page.driver.browser.action.move_to_location(5, 5).perform
    focus_trigger(CITIES)
    press(:enter)
    assert_popup(CITIES, 'open')
    press('i')
    press('s')
    assert_active(CITIES, TIMEZONES.index('Lisbon'), 'the first match is not active after typing')

    press(:enter)
    assert_popup(CITIES, 'open')
    assert_equal %w[lisbon london paris], chosen(CITIES)

    press(:enter)
    assert_equal %w[london paris], chosen(CITIES), 'Enter again did not un-choose the first match'

    # An empty query matches everything, and leaves nothing active, as the open list does.
    press(:backspace)
    press(:backspace)
    assert_no_active(CITIES, 'an emptied query left an option active')
  end

  test 'SM12: the clear button appears once something is chosen and goes back to the empty label' do
    assert page.has_no_css?("##{ROUNDS}-clear"), 'a clear button shows with nothing chosen'
    control(ROUNDS).click
    find("##{ROUNDS}-option-0").click
    find("##{ROUNDS}-option-3").click
    assert page.has_css?("##{ROUNDS}-clear"), 'no clear button once something is chosen'

    record_events(ROUNDS)
    find("##{ROUNDS}-clear").click

    assert_popup(ROUNDS, 'closed')
    assert_empty chosen(ROUNDS)
    assert_equal 'Any round', control_label(ROUNDS)
    assert_selector "##{ROUNDS}-combobox [data-placeholder='true']"
    assert_equal [''], posted('filter[rounds][]')
    assert_equal ['input::true', 'change::true'], recorded_events, 'clearing is not one input and one change'
    assert_focus_on_combobox(ROUNDS)
    assert page.has_no_css?("##{ROUNDS}-clear"), 'the clear button outlived what it cleared'
  end

  test 'SM13: Tab from the control reaches the clear button, and Enter and Space press it' do
    %i[enter space].each do |key|
      ui_select 'Growth', from: 'Offer on'
      focus_combobox(ROUNDS)
      press(:tab)
      assert_equal "#{ROUNDS}-clear", focused_id, "Tab from the control did not reach the clear button (#{key})"

      press(key)
      assert_empty chosen(ROUNDS), "#{key} did not press the clear button"
      assert_focus_on_combobox(ROUNDS)
    end
  end

  test 'SM14: the search Select clears the same way, and ui_select with the empty label presses it' do
    ui_select 'Anywhere', from: 'Cities'

    assert_empty chosen(CITIES)
    assert_equal 'Anywhere', control_label(CITIES)
    assert_focus_on_trigger(CITIES)

    ui_select 'Anywhere', from: 'Cities'
    assert_empty chosen(CITIES), 'ui_select with the empty label and nothing chosen did something'
  end

  test 'SM10: the open multiple Select passes axe' do
    control(ROUNDS).click
    find("##{ROUNDS}-option-0").click
    assert_popup(ROUNDS, 'open')

    assert_accessible within: '#select-multiple-preview'
  end
end
