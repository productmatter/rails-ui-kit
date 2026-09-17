# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'confirm_dialog_helpers'

# Nothing custom crosses JavaScript, and an invalid option is loud in development and test and safe
# in production (docs/specs/ui-confirm-dialog, § Behavior, item 9; ui-toast § Business rules,
# rules 2 and 4). The strict flag is rendered from Ruby, so "not strict" is emulated by writing the
# attribute the component renders, never by guessing in the browser.
class ConfirmDialogValidationTest < ApplicationSystemTestCase
  include ConfirmDialogHelpers

  ICON_ATTACK = '<svg onload="window.__injected = true"></svg>'

  test 'CX1: strict, an option carrying markup rejects before the dialog opens, and injects nothing' do
    visit confirm_dialog_path
    before = element_count

    error = rejected_call(icon: ICON_ATTACK)

    assert_match(/icon is not an option/, error)
    assert_no_selector 'dialog[open]'
    assert_equal before, element_count, 'an element was injected by a rejected option'
    assert_nil page.evaluate_script('window.__injected')
  end

  test 'CX2: strict, an unknown confirm_variant and a non-string value reject too' do
    visit confirm_dialog_path

    assert_match(/no confirm button for the variant danger/, rejected_call(confirm_variant: 'danger'))
    assert_no_selector 'dialog[open]'
    assert_match(/title must be a string/, rejected_call(title: 12))
    assert_no_selector 'dialog[open]'
  end

  test 'CX3: not strict, the same options warn and the dialog opens at its rendered defaults' do
    visit confirm_dialog_path
    relax_strictness
    before = element_count

    warnings = capture_warnings do
      open_default_confirm(icon: ICON_ATTACK, confirm_variant: 'danger', message: 'Delete this item?')
    end

    assert_match(/icon is not an option/, warnings.join("\n"))
    assert_match(/no confirm button for the variant danger/, warnings.join("\n"))
    assert_equal before, element_count, 'an element was injected by a dropped option'
    assert_nil page.evaluate_script('window.__injected')
    assert_equal 'Delete this item?', find('#default-confirm [data-ui--dialog-message]').text
    assert_equal 'destructive', confirm_button['data-ui--dialog-confirm-variant']
    cancel_confirm
  end

  test 'CX4: a message aimed at a dialog rendered with a body is rejected, and the body survives' do
    visit confirm_dialog_path
    make_body_dialog_the_default

    assert_match(/rich content in its body slot/, rejected_call('Delete this item?'))
    assert_no_selector 'dialog[open]'

    relax_strictness
    warnings = capture_warnings { open_default_confirm('Delete this item?') }

    assert_match(/rich content in its body slot/, warnings.join("\n"))
    assert_selector '#default-confirm [data-ui--dialog-body] p', text: 'Archiving hides it'
    assert_no_selector '#default-confirm', text: 'Delete this item?'
    cancel_confirm
  end

  private

  # The dialog the docs app renders with a body slot, made the one defaultConfirmDialog targets --
  # which is what a host gets by rendering its own default dialog with rich content.
  def make_body_dialog_the_default
    page.execute_script(<<~JS)
      document.getElementById('default-confirm').id = 'layout-confirm'
      document.getElementById('archive-confirm').id = 'default-confirm'
    JS
  end

  def relax_strictness
    page.execute_script("document.getElementById('default-confirm').dataset.strict = 'false'")
  end

  def rejected_call(options)
    wait_for_confirm_api
    page.execute_script(<<~JS, options.is_a?(String) ? options : options.transform_keys(&:to_s))
      window.__error = null
      window.defaultConfirmDialog(arguments[0]).then(() => { window.__error = 'resolved' },
                                                     (error) => { window.__error = String(error) })
    JS
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.02 until page.evaluate_script('window.__error') }
    page.evaluate_script('window.__error')
  end

  def capture_warnings
    page.execute_script(<<~JS)
      window.__warnings = []
      window.__consoleWarn ||= console.warn
      console.warn = (...args) => { window.__warnings.push(args.join(' ')); window.__consoleWarn(...args) }
    JS
    yield
    page.evaluate_script('window.__warnings')
  end

  def element_count
    page.evaluate_script("document.querySelectorAll('svg, img, script, iframe').length")
  end
end
