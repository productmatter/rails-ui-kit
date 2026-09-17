# frozen_string_literal: true

require 'application_system_test_case'

class DarkModeToggleTest < ApplicationSystemTestCase
  # CDP media emulation outlives the test that set it -- the browser session is shared -- so a
  # test that emulated a dark OS preference would otherwise decide the initial state of whichever
  # test runs next. Reset it, and pin the OS preference where a test's assertions depend on it.
  teardown { page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: []) }

  test 'toggling dark mode adds and removes .dark on <html>' do
    emulate_color_scheme('light')
    visit root_path
    page.execute_script('localStorage.clear()')
    visit root_path # reload so the controller re-evaluates with a clean theme

    # Found by its Stimulus target, not its label: the controller rewrites the
    # label to describe the action it would take next.
    toggle = find("button[data-ui--dark-mode-target='toggle']", match: :first)

    refute dark_mode_enabled?

    toggle.click
    assert dark_mode_enabled?
    assert_equal 'true', toggle['aria-pressed']

    toggle.click
    refute dark_mode_enabled?
    assert_equal 'false', toggle['aria-pressed']
  end

  test 'toggling saves under the kit namespace and leaves a host own theme key alone' do
    visit root_path
    page.execute_script('localStorage.clear(); localStorage.setItem("theme", "system")')
    visit root_path

    find("button[data-ui--dark-mode-target='toggle']", match: :first).click

    assert dark_mode_enabled?
    assert_equal 'dark', page.evaluate_script('localStorage.getItem("rails_ui_kit:theme")')
    assert_equal 'system', page.evaluate_script('localStorage.getItem("theme")')
  end

  test "a host's own value under the generic theme key leaves the OS preference in charge" do
    emulate_color_scheme('dark')
    visit root_path
    page.execute_script('localStorage.clear(); localStorage.setItem("theme", "system")')
    visit root_path

    assert_selector "button[data-ui--dark-mode-target='toggle'][aria-pressed='true']", match: :first
    assert dark_mode_enabled?
  end

  test 'a preference saved under the old key survives until the user toggles again' do
    emulate_color_scheme('light')
    visit root_path
    page.execute_script('localStorage.clear(); localStorage.setItem("theme", "dark")')
    visit root_path

    assert_selector "button[data-ui--dark-mode-target='toggle'][aria-pressed='true']", match: :first
    assert dark_mode_enabled?

    find("button[data-ui--dark-mode-target='toggle']", match: :first).click
    visit root_path

    assert_selector "button[data-ui--dark-mode-target='toggle'][aria-pressed='false']", match: :first
    refute dark_mode_enabled?
  end

  private

  def emulate_color_scheme(value)
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [{ name: 'prefers-color-scheme', value: value }])
  end

  def dark_mode_enabled?
    page.evaluate_script("document.documentElement.classList.contains('dark')")
  end
end
