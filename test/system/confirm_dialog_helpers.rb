# frozen_string_literal: true

require_relative 'ui_overlay_helpers'

# Shared vocabulary for the confirm-dialog browser tests. Not a second harness:
# ApplicationSystemTestCase stays the base class.
module ConfirmDialogHelpers
  include UiOverlayHelpers

  # The controller installs window.defaultConfirmDialog on connect, which is a tick after the
  # response: a call fired the moment the page arrives can lose that race on a slow machine.
  def wait_for_confirm_api
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.02 until page.evaluate_script("typeof window.defaultConfirmDialog === 'function'")
    end
  rescue Timeout::Error
    flunk 'window.defaultConfirmDialog was never installed'
  end

  def open_default_confirm(options)
    wait_for_confirm_api
    page.execute_script(<<~JS, options.is_a?(String) ? options : options.transform_keys(&:to_s))
      window.__answer = 'pending'
      window.__error = null
      window.defaultConfirmDialog(arguments[0]).then((answer) => { window.__answer = answer },
                                                     (error) => { window.__error = String(error) })
    JS
    assert_confirm_open
  end

  def open_custom_confirm(selector)
    wait_for_confirm_api
    page.execute_script(<<~JS, selector)
      window.__answer = 'pending'
      window.customConfirmDialog(arguments[0]).then((answer) => { window.__answer = answer })
    JS
    assert_selector "#{selector}[open]"
    assert_state selector, 'open'
  end

  def assert_confirm_open
    assert_selector 'dialog#default-confirm[open]'
    assert_state '#default-confirm', 'open'
  end

  def confirm_button
    find('dialog[open] form button[value=confirm]')
  end

  def cancel_button
    find('dialog[open] form button[value=cancel]')
  end

  def cancel_confirm
    cancel_button.click
    assert_no_selector 'dialog[open]'
  end

  def classes_of(element)
    element[:class].split.sort
  end

  # The classes Ui::ButtonComponent rendered into that dialog's own <template> for the variant,
  # read out of the template rather than written here.
  def variant_classes(dialog_id, variant)
    html = page.evaluate_script(<<~JS, dialog_id, variant)
      document.getElementById(arguments[0])
        .querySelector(`template[data-ui--dialog-confirm-template="${arguments[1]}"]`)
        .content.firstElementChild.className
    JS
    html.split.sort
  end

  def assert_destructive_default
    assert_equal 'destructive', confirm_button['data-ui--dialog-confirm-variant']
    assert_equal variant_classes('default-confirm', 'destructive'), classes_of(confirm_button)
    assert_equal I18n.t('rails_ui_kit.confirm_dialog.confirm_label'), confirm_button.text.strip
    assert_equal I18n.t('rails_ui_kit.confirm_dialog.cancel_label'), cancel_button.text.strip
  end
end
