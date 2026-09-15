# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# Ui::ModalComponent's own regressions -- each one a bug this component has actually had. The
# full Turbo lifecycle lives in test/system/modal_turbo_*_test.rb, which drives the same demo.
class ModalTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  test 'M1: closing a modal rendered into a plain div removes it, leaving no backdrop to block clicks' do
    open_modal(1)

    within('#modal') { click_on 'Close' }
    no_modal

    # A real click on a page link navigates -- nothing left behind intercepts it.
    click_on 'Turbo Confirm'
    assert_selector 'h1', text: 'Turbo Confirm'
  end

  test 'M6: closing a modal inside a turbo-frame with a sibling only removes the modal, not the sibling' do
    open_activity_modal(1)

    page.execute_script(<<~JS)
      const frame = document.querySelector('turbo-frame#project_activity_modal')
      const sibling = document.createElement('div')
      sibling.id = 'frame-modal-sibling'
      sibling.textContent = 'sibling content'
      frame.appendChild(sibling)
    JS

    within('turbo-frame#project_activity_modal') { click_on 'Close' }

    assert_no_selector '[data-controller~="ui--modal"]'
    assert_selector '#frame-modal-sibling', visible: :all
  end

  test "M2: a Turbo Stream that empties the modal's container unlocks the body and restores focus" do
    open_modal(1)
    assert scroll_locked?

    stream('<turbo-stream action="update" target="modal"><template></template></turbo-stream>')

    no_modal
    assert_scroll_unlocked
    assert_equal 'open_project_1', focused_id
  end

  test 'M3: after Turbo navigation and Back, the modal is gone, unlocked, and the trigger opens a real modal again' do
    open_modal(1)

    # The open dialog's native backdrop blocks every click, including a sidebar link, so
    # trigger the Turbo visit directly -- this is exactly the path a real navigation takes.
    page.execute_script('Turbo.visit(arguments[0])', '/installation')
    assert_selector 'h1', text: 'Installation'

    page.go_back
    assert_selector 'h1', text: 'Modal & Turbo'
    no_modal
    assert_scroll_unlocked

    open_modal(1)
    assert page.evaluate_script("document.querySelector('#modal dialog').matches(':modal')")
  end

  test 'M4: a track_changes modal falls back to the browser confirm() when the default confirm dialog is missing' do
    inject_track_changes_modal

    page.execute_script("document.getElementById('m4-form').dispatchEvent(new CustomEvent('form:changed', { bubbles: true }))")
    page.execute_script("document.getElementById('default-confirm').remove()")

    # The injected wrapper sets neither data-ui--modal-unsaved-changes-title-value nor
    # -message-value, so this also proves ui--modal falls back to its English default text
    # (rather than an owning component's translation) when those attributes are absent.
    accept_confirm 'You have unsaved changes. Are you sure you want to close?' do
      find('#m4-input').send_keys(:escape)
    end

    assert_no_selector "[data-controller~='ui--modal']"
  end

  # The attribute names Ui::ModalComponent renders are the ones ui--modal reads: a prompt the call
  # site named reaches the confirm dialog, not the controller's English fallback.
  test 'M8: the unsaved-changes prompt ui--modal shows is the one its value attributes carry' do
    inject_track_changes_modal({ 'data-ui--modal-unsaved-changes-title-value' => 'Hold on',
                                 'data-ui--modal-unsaved-changes-message-value' => 'Really discard?' })
    page.execute_script("document.getElementById('m4-form').dispatchEvent(new CustomEvent('form:changed', { bubbles: true }))")

    find('#m4-input').send_keys(:escape)

    assert_selector 'dialog[open]#default-confirm [data-ui--dialog-title]', text: 'Hold on'
    assert_selector 'dialog[open]#default-confirm', text: 'Really discard?'
  end

  # 0.2.0 markup names ui--modal alone: it never opens, which used to say nothing at all.
  test 'M9: a modal missing its ui--overlay companion warns once, naming what stops working' do
    visit modal_turbo_path
    install_console_warning_capture

    inject_track_changes_modal({ 'id' => 'm9-wrapper', 'data-controller' => 'ui--modal' }, opens: false)
    # A close button reaches for the overlay a second time; the warning still says it once.
    page.execute_script(<<~JS)
      var button = document.createElement('button')
      button.setAttribute('data-action', 'ui--modal#close')
      document.querySelector('#m9-wrapper dialog').appendChild(button)
      setTimeout(function () { button.click() }, 50)
    JS
    sleep 0.3
    assert_no_selector '#m9-wrapper dialog[open]'

    warnings = modal_warnings
    assert_equal 1, warnings.length, "expected one ui--modal warning, got: #{warnings}"
    assert_includes warnings.first, 'no "ui--overlay" controller found'
    assert_includes warnings.first, 'never opens'
  end

  # Stimulus connects ui--modal before ui--overlay, so a check made during connect would warn
  # about every correct modal, the way Dropdown once did about ui--anchor.
  test 'M10: a complete modal connects without a missing-companion warning' do
    visit modal_turbo_path
    install_console_warning_capture

    inject_track_changes_modal
    sleep 0.2

    assert_empty modal_warnings
  end

  test "M7: the demo modal's dialog is named via aria-labelledby pointing at its heading" do
    open_modal(1)

    assert_equal 'project_modal_title', dialog['aria-labelledby']
    assert_equal 'Acme rebrand', find('#project_modal_title').text
  end

  test 'closing then reopening via stream ends with the new modal open, locked, and focused' do
    open_modal(1)
    within('#modal') { click_on 'Close' }
    no_modal

    open_modal(2)

    assert_selector '#modal dialog', text: 'Q3 campaign'
    assert scroll_locked?
    assert page.evaluate_script("document.querySelector('#modal dialog').contains(document.activeElement)")
  end

  test 'an autofocused field in the newly rendered content frame keeps focus' do
    open_modal(1)
    track_frame_renders
    page.execute_script(<<~JS)
      document.addEventListener('turbo:before-frame-render', (event) => {
        const field = event.detail.newFrame.querySelector('input[name="project[name]"]')
        if (field) field.setAttribute('autofocus', '')
      })
    JS

    within '#modal turbo-frame#project_modal_content' do
      click_on 'Edit'
    end

    assert_focus_in_dialog_after_frame_render(1)
    assert_equal 'project[name]', page.evaluate_script('document.activeElement.name')
  end

  private

  # There is no track_changes demo with a hand-written form, so build one matching the exact
  # markup Ui::ModalComponent renders (data-controller, targets and values), which Stimulus picks
  # up and connects the same as if it had come from the server.
  # Captures console.warn calls made from here on, without silencing them.
  def install_console_warning_capture
    page.execute_script(<<~JS)
      window.__consoleWarnings = []
      var originalWarn = console.warn.bind(console)
      console.warn = function () {
        window.__consoleWarnings.push(Array.from(arguments).map(String).join(' '))
        originalWarn.apply(console, arguments)
      }
    JS
  end

  def modal_warnings
    page.evaluate_script('window.__consoleWarnings').grep(/ui--modal:/)
  end

  def inject_track_changes_modal(attributes = {}, opens: true)
    page.execute_script(<<~JS, attributes)
      var wrapper = document.createElement('div')
      Object.entries(Object.assign({
        'id': 'm4-wrapper', 'data-controller': 'ui--modal ui--overlay',
        'data-ui--modal-track-changes-value': 'true', 'data-ui--modal-close-on-backdrop-value': 'true',
        'data-ui--overlay-mode-value': 'modal', 'data-ui--overlay-open-value': 'true', 'data-ui--overlay-scroll-lock-value': 'true',
        'data-action': 'ui--overlay:dismiss->ui--modal#guardDismiss:self ui--overlay:closed->ui--modal#remove:self'
      }, arguments[0])).forEach(function([name, value]) { wrapper.setAttribute(name, value) })
      wrapper.innerHTML = '<dialog data-ui--overlay-target="content" class="fixed p-0 m-0">' +
        '<form id="m4-form"><input id="m4-input" type="text" name="title"></form>' +
        '</dialog>'
      document.body.appendChild(wrapper)
    JS
    assert_selector 'dialog[open]' if opens
  end
end
