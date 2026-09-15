# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

class UiOverlayFocusTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  OUTSIDE = [1340, 1240].freeze

  test 'modal: focus enters the overlay on open and returns to the trigger on Escape' do
    visit primitives_overlay_path
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    assert_equal 'modal-content', focused_id

    press :escape
    assert_state '#modal-content', 'closed'
    assert_equal 'modal-trigger', focused_id
  end

  test 'modal: focus returns to the trigger after a backdrop dismissal and after a programmatic close' do
    visit primitives_overlay_path
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    click_at(*OUTSIDE)
    assert_state '#modal-content', 'closed'
    assert_equal 'modal-trigger', focused_id

    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    find('#modal-close').click
    assert_state '#modal-content', 'closed'
    assert_equal 'modal-trigger', focused_id
  end

  test 'layer: focus enters on open and returns to the trigger on Escape, outside click and programmatic close' do
    visit primitives_overlay_path

    find('#menu-trigger').click
    assert_state '#menu-content', 'open'
    assert_equal 'menu-content', focused_id
    press :escape
    assert_state '#menu-content', 'closed'
    assert_equal 'menu-trigger', focused_id

    find('#menu-trigger').click
    assert_state '#menu-content', 'open'
    click_at(*OUTSIDE)
    assert_state '#menu-content', 'closed'
    assert_equal 'menu-trigger', focused_id

    find('#menu-trigger').click
    assert_state '#menu-content', 'open'
    page.execute_script("document.querySelector('#menu-overlay').setAttribute('data-ui--overlay-open-value', 'false')")
    assert_state '#menu-content', 'closed'
    assert_equal 'menu-trigger', focused_id
  end

  test 'a dismissal that deliberately moved focus somewhere else keeps it there' do
    visit primitives_overlay_path
    find('#menu-trigger').click
    assert_state '#menu-content', 'open'

    find('#fade-open').click
    assert_state '#menu-content', 'closed'
    assert_equal 'fade-open', focused_id, 'the overlay stole focus back from the element the user clicked'
  end

  test 'an overlay with no focusable children still takes focus and still gives it back' do
    visit primitives_overlay_path
    inject_overlay('empty', %(<p id="empty-text">Nothing focusable in here.</p>))

    find('#empty-trigger').click
    assert_state '#empty-content', 'open'
    assert_equal 'empty-content', focused_id
    assert_equal '-1', page.evaluate_script("document.querySelector('#empty-content').getAttribute('tabindex')")

    press :escape
    assert_state '#empty-content', 'closed'
    assert_equal 'empty-trigger', focused_id
  end

  test 'initialFocus names what takes focus on open, and the trigger still gets it back' do
    visit primitives_overlay_path
    inject_overlay('search', %(<input id="search-field" type="text">), values: { 'initial-focus' => 'input' })

    find('#search-trigger').click
    assert_state '#search-content', 'open'
    assert_equal 'search-field', focused_id

    press :escape
    assert_state '#search-content', 'closed'
    assert_equal 'search-trigger', focused_id
  end

  test 'focus comes back inside when the element holding it is swapped out from under it' do
    visit primitives_overlay_path
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'

    # Removing the focused element announces nothing -- no blur, no focusout -- and leaves focus
    # on <body>, outside the dialog, where Tab starts from the top of the page. This is what a
    # Turbo Stream or a frame swap inside an open overlay does.
    page.execute_script(<<~JS)
      const content = document.querySelector('#modal-content')
      content.querySelector('#modal-close').focus()
      window.__focusBefore = document.activeElement.id
      content.querySelector('#modal-close').remove()
    JS

    assert_equal 'modal-close', page.evaluate_script('window.__focusBefore')
    assert_equal 'modal-content', focused_id, 'focus was left on <body> behind an open modal'

    # Content swapped in over the focused element still says where focus belongs, and is obeyed.
    page.execute_script(<<~JS)
      const content = document.querySelector('#modal-content')
      content.innerHTML = '<button id="doomed">Replaced next</button>'
      document.querySelector('#doomed').focus()
      content.innerHTML = '<input id="swapped-field" autofocus>'
    JS
    assert_equal 'swapped-field', focused_id
  end

  test 'moveFocus false leaves focus where it already was, for a layer that must not steal it' do
    visit primitives_overlay_path
    inject_overlay('quiet', %(<button id="quiet-button">Inside</button>), values: { 'move-focus' => 'false' })

    find('#quiet-trigger').click
    assert_state '#quiet-content', 'open'
    assert_equal 'quiet-trigger', focused_id, 'a layer with moveFocus false stole focus on open'

    press :escape
    assert_state '#quiet-content', 'closed'
    assert_equal 'quiet-trigger', focused_id
  end

  # A combobox keeps DOM focus on its input for as long as its listbox is open. Focus that falls to
  # <body> while the content changes -- a filter, a Turbo Stream -- is not the overlay's to recover.
  test 'moveFocus false never pulls focus in, even when focus falls to <body> and the content changes' do
    visit primitives_overlay_path
    inject_overlay('quiet', %(<button id="quiet-button">Inside</button>), values: { 'move-focus' => 'false' })

    find('#quiet-trigger').click
    assert_state '#quiet-content', 'open'
    assert_equal 'quiet-trigger', focused_id

    page.execute_script(<<~JS)
      document.activeElement.blur()
      document.querySelector('#quiet-content').innerHTML = '<input id="quiet-swapped">'
    JS
    assert_selector '#quiet-swapped'

    assert page.evaluate_script('document.activeElement === document.body'),
           "focus was pulled into a layer with moveFocus false, onto ##{focused_id}"
    assert_state '#quiet-content', 'open'
  end

  test 'the trigger is operable from the keyboard alone, and reports its state' do
    visit primitives_overlay_path
    trigger = find('#menu-trigger')
    assert_equal 'menu-content', trigger['aria-controls']
    assert_equal 'false', trigger['aria-expanded']

    page.execute_script('arguments[0].focus()', trigger)
    press :enter
    assert_state '#menu-content', 'open'
    assert_equal 'true', trigger['aria-expanded']
    assert_equal 'menu-content', focused_id

    press :escape
    assert_state '#menu-content', 'closed'
    assert_equal 'false', trigger['aria-expanded']
    assert focused?(trigger)
  end

  test 'a trigger that already names what it controls keeps its aria-controls' do
    visit primitives_overlay_path
    inject_overlay('picker', %(<ul id="picker-listbox" role="listbox"><li role="option">One</li></ul>),
                   trigger_attributes: %(aria-controls="picker-listbox"))
    trigger = find('#picker-trigger')
    assert_equal 'picker-listbox', trigger['aria-controls']

    trigger.click
    assert_state '#picker-content', 'open'
    assert_equal 'true', trigger['aria-expanded']
    assert_equal 'picker-listbox', trigger['aria-controls'], 'opening overwrote the aria-controls the markup set'
  end

  private

  # Builds the markup a component would render, so these cases don't need a demo of their own.
  def inject_overlay(name, inner_html, values: {}, trigger_attributes: '')
    attributes = values.map { |key, value| %(wrapper.setAttribute('data-ui--overlay-#{key}-value', '#{value}')) }.join("\n")
    page.execute_script(<<~JS)
      const wrapper = document.createElement('div')
      wrapper.id = '#{name}-overlay'
      wrapper.setAttribute('data-controller', 'ui--overlay')
      #{attributes}
      wrapper.innerHTML = `
        <button id="#{name}-trigger" #{trigger_attributes} data-ui--overlay-target="trigger" data-action="click->ui--overlay#toggle">#{name}</button>
        <div id="#{name}-content" data-ui--overlay-target="content" class="m-auto bg-white p-4">#{inner_html}</div>`
      document.querySelector('#menu-overlay').after(wrapper)
    JS
    assert_selector "##{name}-trigger[aria-expanded='false']"
  end
end
