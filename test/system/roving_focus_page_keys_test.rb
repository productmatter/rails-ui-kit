# frozen_string_literal: true

require 'application_system_test_case'
require 'primitives_helpers'

# PageDown and PageUp, which the APG select-only combobox needs: a jump of pageStep items that
# stops at the ends. Off unless a group sets pageStep, so existing menus and listboxes keep ignoring
# both keys.
class RovingFocusPageKeysTest < ApplicationSystemTestCase
  include PrimitivesHelpers

  COUNT = 25

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
    visit primitives_navigation_path
  end

  test 'RP1: in a select-only combobox, a page is 10 options and the ends clamp' do
    inject_listbox(values: { 'page-step' => 10, 'loop' => false })
    focus_combobox
    record_focus_calls

    press :page_down
    assert_active 10
    press :page_down
    assert_active 20
    press :page_down
    assert_active COUNT
    press :page_down
    assert_active COUNT

    press :page_up
    assert_active 15
    press :page_up
    assert_active 5
    press :page_up
    assert_active 1

    assert focused?(@combobox), 'DOM focus left the combobox'
    assert_empty focus_calls, 'the controller called .focus() on an option'
    assert last_key_prevented?, 'a handled page key was left to scroll the page'
  end

  test 'RP2: hidden options, and disabled ones under skipDisabled, are not counted in a page' do
    inject_listbox(values: { 'page-step' => 10, 'loop' => false, 'skip-disabled' => true })
    page.execute_script(<<~JS)
      for (const n of [3, 4, 5, 6, 7]) document.querySelector(`#page-option-${n}`).hidden = true
      document.querySelector('#page-option-15').setAttribute('aria-disabled', 'true')
    JS
    focus_combobox

    # 1, 2, then 8 through 16 with 15 skipped: the tenth navigable option is 16.
    press :page_down
    assert_active 16
  end

  test 'RP3: with loop on, a jump stops at the end, and only a jump from the end wraps' do
    inject_listbox(values: { 'page-step' => 10, 'loop' => true })
    focus_combobox

    press(*Array.new(3) { :page_down })
    assert_active COUNT, 'a page jump wrapped part-way through'
    press :page_down
    assert_active 1

    press :page_up
    assert_active COUNT
  end

  test 'RP4: without pageStep the group leaves both keys alone' do
    inject_listbox(values: { 'loop' => false })
    focus_combobox
    press :arrow_down
    assert_active 1

    press :page_down
    assert_active 1
    assert_not last_key_prevented?, 'PageDown was cancelled by a group that does not handle it'
    press :page_up
    assert_active 1
  end

  private

  # The markup a select-only combobox renders: a non-editable input target, so the group owns
  # every navigation key it handles.
  def inject_listbox(values:)
    attributes = values.map { |key, value| %(data-ui--roving-focus-#{key}-value="#{value}") }.join(' ')
    page.execute_script(<<~JS, attributes, options_html)
      const group = document.createElement('div')
      group.innerHTML = `
        <div data-controller="ui--roving-focus" data-ui--roving-focus-focus-model-value="activedescendant"
             data-ui--roving-focus-active-class="bg-accent" ${arguments[0]}>
          <div id="page-combobox" role="combobox" tabindex="0" aria-controls="page-listbox"
               aria-expanded="true" data-ui--roving-focus-target="input">Choose</div>
          <ul id="page-listbox" role="listbox" class="max-h-40 overflow-y-auto">${arguments[1]}</ul>
        </div>`
      document.querySelector('main').prepend(group)
      document.addEventListener('keydown', (event) => { window.__lastKeyPrevented = event.defaultPrevented })
    JS
    assert_selector '#page-option-1[tabindex="-1"]'
    @combobox = find_by_id('page-combobox')
  end

  def options_html
    (1..COUNT).map { |n| %(<li role="option" id="page-option-#{n}" data-ui--roving-focus-target="item">Option #{n}</li>) }.join
  end

  def focus_combobox
    page.execute_script('arguments[0].focus()', @combobox)
    assert focused?(@combobox)
  end

  def assert_active(number, message = nil)
    eventually { assert_equal "page-option-#{number}", @combobox['aria-activedescendant'], message }
  end

  def last_key_prevented?
    page.evaluate_script('window.__lastKeyPrevented')
  end

  def record_focus_calls
    page.execute_script(<<~JS)
      window.__focusCalls = []
      const focus = HTMLElement.prototype.focus
      HTMLElement.prototype.focus = function (...args) {
        if (this.closest && this.closest('#page-listbox')) window.__focusCalls.push(this.id)
        return focus.apply(this, args)
      }
    JS
  end

  def focus_calls
    page.evaluate_script('window.__focusCalls')
  end
end
