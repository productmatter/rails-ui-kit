# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'toast_helpers'

class ToastTest < ApplicationSystemTestCase
  include ToastHelpers

  # What is announced (docs/specs/ui-toast, § Behavior, item 13): once, when the toast connects --
  # its title and description, then the actions hint when it has actions. Nothing else, over a
  # whole countdown, a pause and a dismissal.
  test 'T3: the polite region receives Title. Description once, and nothing more through a countdown, a pause and a dismissal' do
    visit toast_path
    wait_for_toast_api
    record_region_changes

    trigger_toast(type: 'success', title: 'Saved', description: 'Your changes are live.', duration: 1500)
    assert_selector "[data-ui--toast-container-target='politeRegion']", text: 'Saved. Your changes are live.', visible: :all
    toast = settled_toast

    page.driver.browser.action.move_to(toast.native).perform
    sleep 0.5
    page.driver.browser.action.move_to_location(5, 5).perform
    assert_no_selector TOAST, wait: 4

    # Clearing an already-empty region is not a mutation, so the one write is all there is.
    assert_equal ['Saved. Your changes are live.'], region_changes('politeRegion'),
                 'the region was written more than once: a countdown, pause or dismissal was announced'
    assert_empty region_changes('assertiveRegion')
  end

  test 'T4: a toast with actions appends the resolved actions hint, and an error goes to the assertive region' do
    visit toast_path
    wait_for_toast_api

    trigger_toast(type: 'error', title: 'Couldn\'t archive', actions: [{ label: 'Retry', href: '/retry', method: 'post' }])
    hint = I18n.t('rails_ui_kit.toast.actions_hint')
    assert_selector "[data-ui--toast-container-target='assertiveRegion']", text: "Couldn't archive. #{hint}", visible: :all
  end

  test 'T5: the actions hint is read from the container, so it switches with the locale' do
    visit toast_path(locale: :fr)
    trigger_toast(type: 'success', description: 'Archivé.', actions: [{ label: 'Annuler', href: '/undo', method: 'patch' }])

    assert_selector "[data-ui--toast-container-target='politeRegion']", text: 'Archivé. Appuyez sur F8 pour atteindre ses actions.', visible: :all
  end

  test 'T1: a toast with the live regions present announces and does not warn' do
    visit toast_path
    install_console_warning_capture

    page.execute_script("window.triggerToast('success', 'All good')")
    assert_selector "[data-ui--toast-target='description']", text: 'All good'
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
    assert_selector "[data-ui--toast-target='description']", text: 'Saved'

    warnings = console_warnings
    assert_equal 1, warnings.size, "expected exactly one warning, got: #{warnings}"
    assert_includes warnings.first, 'politeRegion'
    assert_includes warnings.first, 'Ui::ToastContainerComponent'

    # A second toast -- even a different type, whose missing region has a different name --
    # still doesn't add a second warning: the guard lives on the container, not the toast.
    page.execute_script("window.triggerToast('error', 'Failed again')")
    assert_selector "[data-ui--toast-target='description']", text: 'Failed again'
    assert_equal 1, console_warnings.size

    # The toast itself never knew its announcement failed: it renders and dismisses normally.
    toast = find("[data-controller~='ui--toast']", text: 'Failed again')
    toast.find("[data-action='click->ui--toast#close']").click
    assert_no_selector "[data-ui--toast-target='description']", text: 'Failed again'
  end

  private

  def record_region_changes
    page.execute_script(<<~JS)
      window.__regionChanges = { politeRegion: [], assertiveRegion: [] }
      Object.keys(window.__regionChanges).forEach((name) => {
        const region = document.querySelector(`[data-ui--toast-container-target="${name}"]`)
        new MutationObserver(() => window.__regionChanges[name].push(region.textContent))
          .observe(region, { childList: true, characterData: true, subtree: true })
      })
    JS
  end

  def region_changes(name)
    page.evaluate_script('window.__regionChanges[arguments[0]]', name)
  end

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
