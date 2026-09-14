# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

# The help-text swap in a real browser: animated through the presence primitive when a morph
# keeps the field, and not at all when a page load or a frame render delivers a new one
# (ui-field-model-binding § Behavior, items 19–23). It submits forms and applies streams, so
# run it with SLOW=1 after changing it.
class FieldSwapTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  FIELD = '#field-swap-username'
  DESCRIPTION = "#{FIELD} > [data-slot=field-description]".freeze
  ERROR = "#{FIELD} > [data-slot=field-error]".freeze

  # Every presence event from the demo field's parts, with the state of both parts at that moment.
  RECORDER = <<~JS.freeze
    window.__swap = []
    window.__field = document.querySelector('#{FIELD}')
    const record = (event) => {
      const field = event.target.closest('[data-slot=field]')
      if (!field || field.id !== 'field-swap-username') return
      const error = field.querySelector(':scope > [data-slot=field-error]')
      const description = field.querySelector(':scope > [data-slot=field-description]')
      window.__swap.push({
        type: event.type.split(':')[1], slot: event.target.dataset.slot, at: performance.now(),
        height: event.target.getBoundingClientRect().height,
        error: error && { hidden: error.hidden, state: error.dataset.state || null, role: error.getAttribute('role') },
        description: description && { hidden: description.hidden, state: description.dataset.state || null }
      })
    }
    ;['closing', 'closed', 'opened'].forEach((name) => document.addEventListener(`ui--presence:${name}`, record))
    document.addEventListener('turbo:before-stream-render', () => { window.__streamAt = performance.now() })
  JS

  def visit_demo
    visit field_path
    page.execute_script("document.getElementById('field-swap-preview').scrollIntoView({ block: 'center' })")
    page.execute_script(RECORDER)
  end

  def swap_log
    page.evaluate_script('window.__swap')
  end

  def entry(type, slot)
    swap_log.find { |event| event['type'] == type && event['slot'] == slot }
  end

  # Waits for the response this submission draws: the server's counter outlives a test, so the
  # wait is for a number other than the one already on the page.
  def submit(username)
    before = submission
    fill_in 'signup[username]', with: username
    find('#field-swap-submit').click
    assert_selector "#field-swap-result:not([data-submission='#{before}'])"
  end

  def submission
    page.evaluate_script("document.getElementById('field-swap-result')?.dataset.submission").to_i
  end

  def wait_for_event(type, slot)
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.02 until entry(type, slot) }
    entry(type, slot)
  end

  def same_field?
    page.evaluate_script("document.querySelector('#{FIELD}') === window.__field")
  end

  # The accessibility tree's view of one element, from Chrome itself.
  def ax_node(selector)
    browser = page.driver.browser
    root = browser.execute_cdp('DOM.getDocument', depth: 0)['root']['nodeId']
    node = browser.execute_cdp('DOM.querySelector', nodeId: root, selector: selector)['nodeId']
    browser.execute_cdp('Accessibility.getPartialAXTree', nodeId: node, fetchRelatives: false)['nodes'].first
  end

  def ax_value(node, key)
    node.dig(key, 'value')
  end

  # A stream the server renders for a username, fetched without applying it.
  def server_stream(username)
    page.evaluate_async_script(<<~JS, username)
      const [username, done] = arguments
      const token = document.querySelector('meta[name=csrf-token]')?.content
      fetch('/demos/field', {
        method: 'POST',
        headers: { Accept: 'text/vnd.turbo-stream.html', 'X-CSRF-Token': token },
        body: new URLSearchParams({ 'signup[username]': username })
      }).then((response) => response.text()).then(done)
    JS
  end

  test 'FW1: becoming invalid holds the description out while the error waits hidden, then the error enters' do
    visit_demo

    submit ''
    opened = wait_for_event('opened', 'field-error')
    closing = entry('closing', 'field-description')
    closed = entry('closed', 'field-description')

    assert same_field?, 'the response replaced the field, so nothing was animated'
    assert_operator closing['height'], :>, 0, 'the description was not laid out while it ran out'
    assert closing['error']['hidden'], 'the error showed while the description was still running out'
    assert_equal 'alert', closing['error']['role'], 'the error was not an alert before it was revealed'
    assert_operator closed['at'], :<, opened['at']
    assert_operator opened['at'] - closed['at'], :>=, 100, 'the error appeared without its entry transition'

    assert_selector ERROR, text: "can't be blank"
    assert_selector DESCRIPTION, visible: :hidden
  end

  test 'FW2: becoming valid holds the error in place until its exit settles, then removes it and enters the description' do
    visit_demo
    submit ''
    wait_for_event('opened', 'field-error')
    page.execute_script('window.__swap = []')

    submit 'jonathan'
    opened = wait_for_event('opened', 'field-description')
    closing = entry('closing', 'field-error')
    closed = entry('closed', 'field-error')

    assert same_field?
    assert_equal({ 'hidden' => false, 'state' => 'closing', 'role' => 'alert' }, closing['error'], 'the morph removed or hid the error before it ran out')
    assert closing['description']['hidden'], 'the description showed while the error was still running out'
    assert_operator closing['height'], :>, 0
    assert_operator closed['at'], :<, opened['at']
    assert_nil opened['error'], 'the error was still in the DOM once the description had entered'
    assert_operator opened['at'] - closed['at'], :>=, 100

    assert_selector DESCRIPTION, text: 'Letters and numbers'
    assert_no_selector ERROR, visible: :all
  end

  test 'FW3: a morph that arrives mid-swap settles on the newest state, in both directions' do
    visit_demo
    invalid = server_stream('')
    valid = server_stream('jonathan')

    # Invalid, then valid while the description is still running out.
    page.execute_script('Turbo.renderStreamMessage(arguments[0]); setTimeout(() => Turbo.renderStreamMessage(arguments[1]), 60)', invalid, valid)
    assert_selector "#{DESCRIPTION}[data-state=open]"
    sleep 0.5 # long enough for anything superseded to have come back and undone it
    assert_selector "#{DESCRIPTION}[data-state=open]:not([hidden])"
    assert_no_selector ERROR, visible: :all

    # Settle invalid, then valid, then invalid again while the error is still running out.
    page.execute_script('Turbo.renderStreamMessage(arguments[0])', invalid)
    assert_selector "#{ERROR}[data-state=open]"
    page.execute_script("window.__error = document.querySelector('#{ERROR}')")
    page.execute_script('Turbo.renderStreamMessage(arguments[0]); setTimeout(() => Turbo.renderStreamMessage(arguments[1]), 60)', valid, invalid)
    sleep 0.6
    assert_selector "#{ERROR}[data-state=open][role=alert]:not([hidden])", text: "can't be blank"
    assert page.evaluate_script("document.querySelector('#{ERROR}') === window.__error"), 'the returning error was removed and re-created'
    assert_selector "#{DESCRIPTION}[hidden]", visible: :all
  end

  test 'FW4: the computed description is the help text when valid, and the help text then the error when invalid' do
    visit_demo
    input = "#{FIELD} input"

    valid = ax_value(ax_node(input), 'description')
    assert_equal 'Letters and numbers. Try admin, or leave it blank.', valid
    assert_equal 'signup_username-description', find(input)['aria-describedby']

    submit ''
    wait_for_event('opened', 'field-error')

    assert_equal 'signup_username-description signup_username-error', find(input)['aria-describedby']
    assert_equal "#{valid} can't be blank", ax_value(ax_node(input), 'description')
  end

  test 'FW5: the revealed error is an alert, and stays one when its message changes' do
    visit_demo
    submit ''
    wait_for_event('opened', 'field-error')
    page.execute_script("window.__error = document.querySelector('#{ERROR}')")

    assert_equal 'alert', ax_value(ax_node(ERROR), 'role')

    submit 'admin'
    assert_selector ERROR, text: 'is already taken'
    assert page.evaluate_script("document.querySelector('#{ERROR}') === window.__error")
    assert_equal 'alert', ax_value(ax_node(ERROR), 'role')
  end

  test 'FW6: an invalid field on page load is already in its final state, with no transition and no role' do
    visit field_path

    assert_selector '#coupon-field > [data-slot=field-error]', text: 'is not a recognised code'
    assert_selector '#coupon-field > [data-slot=field-description][hidden]', visible: :all
    assert_nil find('#coupon-field > [data-slot=field-error]')['role']
    sleep 0.3
    assert_empty page.all('[data-slot=field] > [data-state]', visible: :all), 'a field part went through presence on load'
  end

  test 'FW7: a frame render that delivers an invalid field animates nothing and announces nothing' do
    visit select_path
    page.execute_script("document.getElementById('select-round-trip-preview').scrollIntoView({ block: 'center' })")
    within '#select-round-trip-preview' do
      find('#trip_city-combobox').click
      find('#trip_city-option-4').click
      find('#select-round-trip-submit').click
    end

    assert_selector '#select-round-trip-result', text: 'tokyo'
    assert_selector '#trip_city-error', text: 'is not available this week'
    assert_selector '#trip_city-description[hidden]', visible: :all
    assert_nil find('#trip_city-error')['role']
    sleep 0.3
    assert_empty page.all('#select-round-trip-preview [data-slot=field] > [data-state]', visible: :all)
  end

  test 'FW9: a page cached mid-swap is restored at rest, with no leaving error and no alert to replay' do
    visit_demo
    submit ''
    wait_for_event('opened', 'field-error')
    valid = server_stream('jonathan')

    page.execute_script(<<~JS, valid)
      Turbo.renderStreamMessage(arguments[0])
      document.addEventListener('ui--presence:closing', () => Turbo.visit('#{button_path}'), { once: true })
    JS
    assert_current_path button_path
    page.go_back
    assert_current_path field_path

    assert_selector "#{DESCRIPTION}:not([hidden])", text: 'Letters and numbers'
    assert_no_selector ERROR, visible: :all
    assert_empty page.all("#{FIELD} > [data-state=closing]", visible: :all)
  end

  test 'FW8: under prefers-reduced-motion the swap completes at once' do
    visit_demo
    emulate_media('prefers-reduced-motion', 'reduce')

    submit ''
    opened = wait_for_event('opened', 'field-error')
    closing = entry('closing', 'field-description')

    assert_operator opened['at'] - closing['at'], :<, 20, 'the swap waited on an animation under reduced motion'
    assert_operator opened['at'] - page.evaluate_script('window.__streamAt'), :<, 100
    assert_selector ERROR, text: "can't be blank"
  ensure
    emulate_media('prefers-reduced-motion', 'no-preference')
  end
end
