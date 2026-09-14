# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

class UiOverlayDismissTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  # A point on the page well clear of every trigger and panel on the demo page.
  OUTSIDE = [1340, 1240].freeze

  setup { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test 'a click wholly outside a layer dismisses it, animating out before the browser hides it' do
    visit primitives_overlay_path
    open_menu
    record_states('#menu-content')

    click_at(*OUTSIDE)

    assert_state '#menu-content', 'closed'
    assert_not page.evaluate_script("document.querySelector('#menu-content').matches(':popover-open')")
    assert_equal %w[closing closed], recorded_states, 'light dismiss skipped the exit animation'
    assert_equal 'false', find('#menu-trigger')['aria-expanded']
  end

  test 'a drag that starts inside a layer and ends outside it leaves the layer open' do
    visit primitives_overlay_path
    open_menu

    drag(center_of('#menu-content'), OUTSIDE)

    sleep 0.3
    assert_equal 'open', state_of('#menu-content')
    assert page.evaluate_script("document.querySelector('#menu-content').matches(':popover-open')")
  end

  test 'pressing the trigger of an open layer closes it rather than reopening it' do
    visit primitives_overlay_path
    open_menu

    find('#menu-trigger').click

    assert_state '#menu-content', 'closed'
    sleep 0.3
    assert_equal 'closed', state_of('#menu-content')
    assert_equal 'false', find('#menu-trigger')['aria-expanded']
  end

  test 'a click on the backdrop dismisses a modal' do
    visit primitives_overlay_path
    open_modal

    click_at(*OUTSIDE)

    assert_state '#modal-content', 'closed'
    assert_not page.evaluate_script("document.querySelector('#modal-content').open")
  end

  test 'drag-selecting text from inside a modal out onto its backdrop leaves the modal open' do
    visit primitives_overlay_path
    open_modal

    text = rect_of('#modal-text')
    drag([text['left'] + 10, text['top'] + 8], OUTSIDE)

    sleep 0.3
    assert_equal 'open', state_of('#modal-content')
    assert page.evaluate_script("document.querySelector('#modal-content').matches(':modal')")
  end

  test 'a listener that cancels ui--overlay:dismiss keeps a modal open against Escape and the backdrop' do
    visit primitives_overlay_path
    count_dismiss_events('#guarded-overlay')
    find('#guarded-trigger').click
    assert_state '#guarded-content', 'open'

    press :escape
    sleep 0.3
    assert_equal 'open', state_of('#guarded-content')
    assert page.evaluate_script("document.querySelector('#guarded-content').matches(':modal')")

    click_at(*OUTSIDE)
    sleep 0.3
    assert_equal 'open', state_of('#guarded-content')
    assert_equal 2, page.evaluate_script('window.__dismissals')

    # Programmatic close never asks.
    find('#guarded-close').click
    assert_state '#guarded-content', 'closed'
    assert_equal 2, page.evaluate_script('window.__dismissals')
  end

  test 'a vetoed modal refuses Escape however often it is pressed, not only the first time' do
    visit primitives_overlay_path
    count_dismiss_events('#guarded-overlay')
    find('#guarded-trigger').click
    assert_state '#guarded-content', 'open'

    # Chrome only lets a close request be vetoed while the window holds history-action user
    # activation, and consumes it on the first veto: from the second Escape on, <dialog>'s own
    # `cancel` arrives non-cancelable and the dialog closes whatever the guard says. A guard
    # exists to protect unsaved work, so the key is taken before it becomes a close request.
    3.times { press :escape }
    sleep 0.3

    assert_equal 'open', state_of('#guarded-content')
    assert page.evaluate_script("document.querySelector('#guarded-content').matches(':modal')")
    assert_equal 3, page.evaluate_script('window.__dismissals'), 'a later Escape never reached the guard'
  end

  test 'ui--overlay:dismiss names the gesture, so a listener can refuse one and allow another' do
    visit primitives_overlay_path
    record_dismiss_reasons('#modal-overlay')

    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    press :escape
    assert_state '#modal-content', 'closed'

    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    click_at(*OUTSIDE)
    assert_state '#modal-content', 'closed'

    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    inject_dismiss_action('#modal-content')
    find('#modal-dismiss').click
    assert_state '#modal-content', 'closed'

    assert_equal %w[escape outside programmatic], page.evaluate_script('window.__reasons')
  end

  test 'a layer names its light dismissal too, though the browser only says that one happened' do
    visit primitives_overlay_path
    record_dismiss_reasons('#menu-overlay')

    open_menu
    press :escape
    assert_state '#menu-content', 'closed'

    open_menu
    click_at(*OUTSIDE)
    assert_state '#menu-content', 'closed'

    assert_equal %w[escape outside], page.evaluate_script('window.__reasons')
  end

  test 'once the listener stops cancelling, the same Escape dismisses the modal' do
    visit primitives_overlay_path
    find('#guarded-trigger').click
    assert_state '#guarded-content', 'open'

    find('#guard-toggle').click
    assert_not find('#guard-toggle').checked?

    press :escape
    assert_state '#guarded-content', 'closed'
  end

  test 'a listener that cancels ui--overlay:dismiss keeps a layer open against light dismiss and Escape' do
    visit primitives_overlay_path
    count_dismiss_events('#menu-overlay', cancel: true)
    open_menu
    find('#menu-item-edit').send_keys(:shift) # focus a control inside, the way a keyboard user would be

    click_at(*OUTSIDE)
    sleep 0.3
    assert_equal 'open', state_of('#menu-content')
    assert page.evaluate_script("document.querySelector('#menu-content').matches(':popover-open')"), 'the vetoed layer stayed hidden'
    assert_equal 'true', find('#menu-trigger')['aria-expanded']

    page.execute_script("document.querySelector('#menu-item-edit').focus()")
    press :escape
    sleep 0.3
    assert_equal 'open', state_of('#menu-content')
    assert page.evaluate_script("document.querySelector('#menu-content').matches(':popover-open')")
    assert_equal 'menu-item-edit', focused_id, 'a vetoed Escape left focus where the browser moved it'
    assert_equal 2, page.evaluate_script('window.__dismissals')
  end

  test 'dismissible: false refuses Escape and outside clicks, while a programmatic close still works' do
    visit primitives_overlay_path
    inject_layer('sticky', dismissible: false)
    find('#sticky-trigger').click
    assert_state '#sticky-content', 'open'

    press :escape
    click_at(*OUTSIDE)
    sleep 0.3
    assert_equal 'open', state_of('#sticky-content')
    assert page.evaluate_script("document.querySelector('#sticky-content').matches(':popover-open')")

    page.execute_script("document.querySelector('#sticky-overlay').setAttribute('data-ui--overlay-open-value', 'false')")
    assert_state '#sticky-content', 'closed'
  end

  test 'a backdrop target enters and leaves with the content, and clicking it dismisses the overlay' do
    visit primitives_overlay_path
    inject_layer('dimmed', backdrop: true)

    find('#dimmed-trigger').click
    assert_state '#dimmed-content', 'open'
    assert_equal 'open', state_of('#dimmed-backdrop')
    assert_not hidden?('#dimmed-backdrop')

    click_at(*OUTSIDE)

    assert_state '#dimmed-content', 'closed'
    assert_state '#dimmed-backdrop', 'closed'
    assert hidden?('#dimmed-backdrop')
  end

  test 'opening one layer closes another, and the displaced one is simply closed rather than dismissed' do
    visit primitives_overlay_path
    inject_second_layer
    count_dismiss_events('#menu-overlay')
    open_menu

    find('#second-trigger').click
    assert_state '#second-content', 'open'
    assert_state '#menu-content', 'closed'
    assert_equal 'false', find('#menu-trigger')['aria-expanded']
    assert_equal 0, page.evaluate_script('window.__dismissals')

    sleep 0.3
    assert page.evaluate_script("document.querySelector('#second-content').matches(':popover-open')"), 'the displaced layer fought its way back'
  end

  private

  def open_menu
    find('#menu-trigger').click
    assert_state '#menu-content', 'open'
  end

  def open_modal
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
  end

  def center_of(selector)
    rect = rect_of(selector)
    [rect['left'] + (rect['width'] / 2), rect['top'] + (rect['height'] / 2)]
  end

  def click_at(point_x, point_y)
    page.driver.browser.action.move_to_location(point_x.to_i, point_y.to_i).click.perform
  end

  # A real pointer drag: press inside, move through a midpoint (some engines ignore a single
  # jump), release outside.
  def drag(from, to)
    gesture = move_to(page.driver.browser.action, from).click_and_hold
    gesture = move_to(gesture, from.zip(to).map { |pair| pair.sum / 2 })
    move_to(gesture, to).release.perform
  end

  def move_to(gesture, point)
    gesture.move_to_location(point.first.to_i, point.last.to_i)
  end

  def record_states(selector)
    page.execute_script(<<~JS)
      window.__states = []
      const element = document.querySelector('#{selector}')
      new MutationObserver(() => window.__states.push(element.dataset.state))
        .observe(element, { attributes: true, attributeFilter: ['data-state'] })
    JS
  end

  def recorded_states
    page.evaluate_script('window.__states').chunk_while { |a, b| a == b }.map(&:first)
  end

  def record_dismiss_reasons(selector)
    page.execute_script(<<~JS)
      window.__reasons = []
      document.querySelector('#{selector}').addEventListener('ui--overlay:dismiss', (event) => {
        window.__reasons.push(event.detail.reason)
      })
    JS
  end

  # The public action a component calls on a person's behalf -- a Close button that should still
  # be vetoable -- as opposed to #close, which never asks.
  def inject_dismiss_action(selector)
    page.execute_script(<<~JS)
      const button = document.createElement('button')
      button.id = 'modal-dismiss'
      button.setAttribute('data-action', 'click->ui--overlay#dismiss')
      button.textContent = 'Dismiss'
      document.querySelector('#{selector}').appendChild(button)
    JS
  end

  def count_dismiss_events(selector, cancel: false)
    page.execute_script(<<~JS)
      window.__dismissals = 0
      document.querySelector('#{selector}').addEventListener('ui--overlay:dismiss', (event) => {
        window.__dismissals++
        if (#{cancel}) event.preventDefault()
      })
    JS
  end

  # The markup a component would render, for the cases the demo page doesn't need to show.
  def inject_layer(name, dismissible: true, backdrop: false)
    backdrop_html = backdrop ? %(<div id="#{name}-backdrop" data-ui--overlay-target="backdrop" class="fixed inset-0 bg-black/40" hidden></div>) : ''
    page.execute_script(<<~JS)
      const wrapper = document.createElement('div')
      wrapper.id = '#{name}-overlay'
      wrapper.setAttribute('data-controller', 'ui--overlay')
      wrapper.setAttribute('data-ui--overlay-dismissible-value', '#{dismissible}')
      wrapper.innerHTML = `
        <button id="#{name}-trigger" data-ui--overlay-target="trigger" data-action="click->ui--overlay#toggle">#{name}</button>
        #{backdrop_html}
        <div id="#{name}-content" data-ui--overlay-target="content" role="menu" aria-label="#{name}" class="m-auto bg-white p-2">
          <button role="menuitem">Only item</button>
        </div>`
      document.querySelector('#menu-overlay').after(wrapper)
    JS
    assert_selector "##{name}-trigger[aria-expanded='false']"
  end

  def inject_second_layer
    page.execute_script(<<~JS)
      const wrapper = document.createElement('div')
      wrapper.id = 'second-overlay'
      wrapper.setAttribute('data-controller', 'ui--overlay')
      wrapper.innerHTML = `
        <button id="second-trigger" data-ui--overlay-target="trigger" data-action="click->ui--overlay#toggle">Second</button>
        <div id="second-content" data-ui--overlay-target="content" role="menu" aria-label="Second" class="m-auto mt-4 p-2 bg-white">
          <button role="menuitem">Only item</button>
        </div>`
      document.querySelector('#menu-overlay').after(wrapper)
    JS
    assert_selector '#second-trigger[aria-expanded="false"]'
  end
end
