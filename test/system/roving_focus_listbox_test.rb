# frozen_string_literal: true

require 'application_system_test_case'
require 'primitives_helpers'

# The activedescendant model: DOM focus never leaves the input, the option is announced through
# aria-activedescendant, and .focus() is never called on an option -- the bug that
# Dropdown's removed kind: "listbox" had, and the reason Select replaced it.
class RovingFocusListboxTest < ApplicationSystemTestCase
  include PrimitivesHelpers

  OPTIONS = %w[apricot apple blackberry blueberry cherry damson elderberry].map { |name| "roving-option-#{name}" }

  setup do
    visit primitives_navigation_path
    page.execute_script("document.querySelector('#roving-listbox').scrollIntoView({ block: 'center' })")
    @input = find('#roving-listbox-input')
  end

  test 'RL1: no option is active until one is chosen' do
    assert_nil @input['aria-activedescendant']
    assert_empty(all('#roving-listbox [role="option"]').select { |option| option[:class].include?('bg-foreground') })
  end

  test 'RL2: arrows move aria-activedescendant while DOM focus stays in the input' do
    focus_input
    record_focus_calls

    press :arrow_down
    assert_active OPTIONS[0]
    press :arrow_down
    assert_active OPTIONS[1]
    press :arrow_up
    assert_active OPTIONS[0]
    press :arrow_up
    assert_active OPTIONS.last # wrapped

    assert focused?(@input), 'DOM focus left the input'
    assert_empty focus_calls, 'the controller called .focus() on an option'
  end

  test 'RL3: the active option carries the active class, and only it' do
    focus_input
    press :arrow_down
    press :arrow_down

    active = all('#roving-listbox [role="option"]').select { |option| option[:class].include?('bg-foreground') }
    assert_equal([OPTIONS[1]], active.map { |option| option[:id] })
  end

  test 'RL4: every option is out of the tab sequence; the input is the tab stop' do
    all('#roving-listbox [role="option"]').each do |option|
      assert_equal '-1', option['tabindex']
    end

    focus_input
    press :arrow_down
    assert_equal '-1', find("##{OPTIONS[0]}")['tabindex'], 'an option was made tabbable'
  end

  test 'RL5: the input keeps its own editing keys -- typing, Home and End' do
    focus_input
    press :arrow_down
    assert_active OPTIONS[0]

    press 'a', 'p', 'p'
    assert_equal 'app', @input.value
    assert_active OPTIONS[0], 'typing into an editable input moved the active option'

    press :home
    assert_equal 0, page.evaluate_script('arguments[0].selectionStart', @input), 'Home did not reach the input'
    assert_active OPTIONS[0], 'Home was taken from the input'

    press :end
    assert_equal 3, page.evaluate_script('arguments[0].selectionStart', @input)
    assert_active OPTIONS[0], 'End was taken from the input'
  end

  test 'RL6: clicking an option keeps DOM focus in the input' do
    focus_input
    record_focus_calls

    find("##{OPTIONS[4]}").click

    assert_active OPTIONS[4]
    assert focused?(@input), 'clicking an option pulled DOM focus out of the input'
    assert_empty focus_calls
  end

  test 'RL7: the active option is scrolled into view inside a scrolling listbox' do
    focus_input
    list = find('#roving-listbox-options')

    # The first press activates the first option, so one press per option lands on the last.
    press(*Array.new(OPTIONS.size) { :arrow_down })
    assert_active OPTIONS.last

    eventually do
      option = rect(find("##{OPTIONS.last}"))
      box = rect(list)
      assert_operator option['bottom'], :<=, box['bottom'] + 1
      assert_operator option['top'], :>=, box['top'] - 1
    end
  end

  test 'RL8: aria-activedescendant always names an element that exists' do
    focus_input
    press :arrow_down
    press :arrow_down

    id = @input['aria-activedescendant']
    assert_selector "##{id}[role='option']"
  end

  private

  def focus_input
    page.execute_script('arguments[0].focus()', @input)
    assert focused?(@input)
  end

  def assert_active(id, message = nil)
    eventually { assert_equal id, @input['aria-activedescendant'], message }
  end

  # Every .focus() call on an element inside the listbox group, recorded at the prototype.
  def record_focus_calls
    page.execute_script(<<~JS)
      window.__focusCalls = []
      const focus = HTMLElement.prototype.focus
      HTMLElement.prototype.focus = function (...args) {
        if (this.closest && this.closest('#roving-listbox [role="listbox"]')) window.__focusCalls.push(this.id)
        return focus.apply(this, args)
      }
    JS
  end

  def focus_calls
    page.evaluate_script('window.__focusCalls')
  end
end
