# frozen_string_literal: true

require 'application_system_test_case'

# Every invariant seen to fail (docs/specs/ui-stress-page § Business rules, rule 5): each fault is
# planted on the bare page, in a host's layout, and the helper must report it under that
# invariant's name, naming the element, and under no other. A helper that only ever passes proves
# nothing about the pages it passes on.
class KitInvariantsTest < ApplicationSystemTestCase
  BARE = '#stress-bare'
  GIF = 'data:image/gif;base64,R0lGODlhAQABAAAAACw='

  test 'a clean page passes every invariant' do
    visit_bare

    assert_kit_invariants(focus: :body)
  end

  test 'an overlay declared open passes while it holds the scroll lock and focus' do
    visit_bare
    page.execute_script("window.defaultConfirmDialog('Planted')")
    wait_until(<<~JS)
      (() => {
        const dialog = document.querySelector('dialog[data-controller~="ui--dialog"]')
        return dialog.matches(':modal') && dialog.dataset.state === 'open' && dialog.contains(document.activeElement) &&
          !dialog.getAnimations().some((animation) => !['finished', 'idle'].includes(animation.playState))
      })()
    JS

    assert_kit_invariants(open: ['dialog[data-controller~="ui--dialog"]'])
  end

  test 'invariant 1 reports a scroll lock left behind' do
    visit_bare
    page.execute_script("document.body.style.overflow = 'hidden'")

    assert_match 'overflow: hidden', assert_reports_only(:scroll)
  end

  test 'invariant 1 reports a scroll lock released away from where it locked' do
    visit_bare
    page.execute_script("Object.assign(document.body.style, { position: 'fixed', top: '-120px' })")
    wait_until('!!window.__kitLockWatch.locked')
    page.execute_script("Object.assign(document.body.style, { position: '', top: '' })")
    wait_until('window.__kitLockWatch.releases.length > 0')

    assert_match 'the scroll lock released at 0,0, not 0,120 where it locked', assert_reports_only(:scroll)
  end

  test 'invariant 2 reports an open element nobody declared' do
    visit_bare
    plant('<div id="planted-popover" popover>Planted</div>')
    page.execute_script("document.getElementById('planted-popover').showPopover()")

    message = assert_reports_only(:open)
    assert_match 'open but not declared: <div id="planted-popover"', message
    assert_match 'no connected ui--overlay claiming it', message
  end

  test 'invariant 3 reports an element stuck closing' do
    visit_bare
    plant('<div id="planted-closing" data-state="closing">Planted</div>')

    assert_match 'stuck closing: <div id="planted-closing"', assert_reports_only(:transitions)
  end

  test 'invariant 4 reports an aria-expanded that lies' do
    visit_bare
    plant('<button type="button" id="planted-trigger" aria-expanded="true" aria-controls="planted-panel">Planted</button>' \
          '<div id="planted-panel" popover>Panel</div>')

    assert_match 'aria-expanded="true" but <div id="planted-panel"', assert_reports_only(:expanded)
  end

  test 'invariant 5 reports focus lost with the node that held it' do
    visit_bare
    plant('<button type="button" id="planted-focus">Planted</button>')
    page.execute_script("document.getElementById('planted-focus').focus()")
    page.execute_script("document.getElementById('planted-focus').remove()")

    assert_match 'focus is on <body>', assert_reports_only(:focus, focus: nil)
  end

  test 'invariant 6 reports an accessibility violation' do
    visit_bare
    plant(%(<img id="planted-image" src="#{GIF}">))

    message = assert_reports_only(:accessible)
    assert_match 'image-alt', message
    assert_match 'planted-image', message
  end

  test 'invariant 7 reports a console.error logged before the page loaded' do
    capture_console
    planted = add_script_to_new_documents("console.error('planted before load')")
    visit_bare(capture: false)

    assert_match 'console.error: planted before load', assert_reports_only(:console)
  ensure
    remove_script_from_new_documents(planted) if planted
  end

  test 'invariant 7 fails, rather than reporting silence, when capture was never installed' do
    visit_bare(capture: false)

    assert_match 'console capture was not installed', assert_reports_only(:console)
  end

  test 'invariant 8 reports an element naming a ui-- controller that never connected' do
    visit_bare
    # A registered controller planted in the same mutation is the settle signal: once it has
    # connected, Stimulus has processed the unregistered one too.
    plant('<div id="planted-missing" data-controller="ui--planted-missing"></div>' \
          '<div id="planted-settle" data-controller="ui--presence" hidden></div>')
    wait_until("!!Stimulus.getControllerForElementAndIdentifier(document.getElementById('planted-settle'), 'ui--presence')")

    assert_match 'ui--planted-missing is not connected: <div id="planted-missing"', assert_reports_only(:controllers)
  end

  test 'invariant 9 reports a duplicate id' do
    visit_bare
    plant('<span id="planted-twice">One</span><span id="planted-twice">Two</span>')

    assert_match 'id "planted-twice" is on 2 elements', assert_reports_only(:ids)
  end

  # axe audits a rendered element's aria-controls too, so a visible one fails both. Invariant 9
  # also covers what axe skips: the same reference on an element that isn't rendered.
  test 'invariant 9 reports a dangling aria-controls' do
    visit_bare
    plant('<div id="planted-dangling" aria-controls="planted-nowhere">Planted</div>')

    assert_match 'aria-controls="planted-nowhere" names no element: <div id="planted-dangling"', assert_reports_only(:ids, :accessible)
  end

  test 'invariant 9 reports a dangling aria-controls axe does not audit' do
    visit_bare
    plant('<div id="planted-dangling" aria-controls="planted-nowhere" hidden>Planted</div>')

    assert_match 'aria-controls="planted-nowhere" names no element: <div id="planted-dangling"', assert_reports_only(:ids)
  end

  private

  # The page has settled when the layout's own kit controllers have connected.
  def visit_bare(capture: true)
    capture_console if capture
    visit stress_bare_path
    wait_until(<<~JS)
      (() => {
        const dialog = document.querySelector('dialog[data-controller~="ui--dialog"]')
        return !!window.Stimulus && !!dialog && !!Stimulus.getControllerForElementAndIdentifier(dialog, 'ui--dialog')
      })()
    JS
    record_arrival
  end

  def plant(html)
    page.execute_script('document.querySelector(arguments[0]).insertAdjacentHTML("beforeend", arguments[1])', BARE, html)
  end

  # Asserts the helper fails naming exactly these invariants, and returns its message. The bare
  # page was a document render, so focus on <body> is declared unless a test says otherwise.
  def assert_reports_only(*keys, focus: :body)
    error = assert_raises(Minitest::Assertion) { assert_kit_invariants(focus: focus) }
    KitInvariants::INVARIANTS.each do |key, label|
      if keys.include?(key)
        assert_includes error.message, label
      else
        assert_not_includes error.message, label, "expected only #{keys.join(', ')}, got:\n#{error.message}"
      end
    end
    error.message
  end

  def wait_until(expression, timeout: Capybara.default_max_wait_time)
    Timeout.timeout(timeout) { sleep 0.02 until page.evaluate_script(expression) }
  rescue Timeout::Error
    flunk "timed out waiting for #{expression}"
  end
end
