# frozen_string_literal: true

require 'application_system_test_case'

class ToastTest < ApplicationSystemTestCase
  test 'T1: a toast with the live regions present announces and does not warn' do
    visit toast_path
    install_console_warning_capture

    page.execute_script("window.triggerToast('success', 'All good')")
    assert_selector "[data-ui--toast-target='title']", text: 'All good'
    # The announcement itself lands a frame later than the toast's own markup -- wait for it
    # rather than reading the region synchronously.
    assert_selector "[data-ui--toast-container-target='politeRegion']", text: 'All good', visible: :all

    assert_empty console_warnings
  end

  test 'T2: a toast triggered with no live region present warns once per container, and still renders and dismisses normally' do
    visit toast_path
    install_console_warning_capture

    # Simulates an app that copy-pasted the old container markup: the container, its stack
    # and its templates are all present, but the persistent live regions are missing. The
    # lookup in ui--toast#announce is a plain document-wide querySelector, so this has to
    # remove the docs page's own regions rather than add a second, region-less container
    # alongside them -- otherwise the existing regions would still be found.
    page.execute_script(<<~JS)
      document.querySelectorAll(
        '[data-ui--toast-container-target="politeRegion"], [data-ui--toast-container-target="assertiveRegion"]'
      ).forEach(function (region) { region.remove() })
    JS

    page.execute_script("window.triggerToast('success', 'Saved')")
    assert_selector "[data-ui--toast-target='title']", text: 'Saved'

    warnings = console_warnings
    assert_equal 1, warnings.size, "expected exactly one warning, got: #{warnings}"
    assert_includes warnings.first, 'politeRegion'
    assert_includes warnings.first, 'Ui::ToastContainerComponent'

    # A second toast -- even a different type, whose missing region has a different name --
    # still doesn't add a second warning: the guard lives on the container, not the toast.
    page.execute_script("window.triggerToast('error', 'Failed again')")
    assert_selector "[data-ui--toast-target='title']", text: 'Failed again'
    assert_equal 1, console_warnings.size

    # The toast itself never knew its announcement failed: it renders and dismisses normally.
    toast = find("[data-controller~='ui--toast']", text: 'Failed again')
    toast.find("[data-action='click->ui--toast#close']").click
    assert_no_selector "[data-ui--toast-target='title']", text: 'Failed again'
  end

  private

  # Captures console.warn calls made from here on, without silencing them -- the real warning
  # still reaches the browser's own console too.
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

  def console_warnings
    page.evaluate_script('window.__consoleWarnings')
  end
end
