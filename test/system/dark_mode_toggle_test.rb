# frozen_string_literal: true

require 'application_system_test_case'

class DarkModeToggleTest < ApplicationSystemTestCase
  test 'toggling dark mode adds and removes .dark on <html>' do
    visit root_path
    page.execute_script('localStorage.clear()')
    visit root_path # reload so the controller re-evaluates with a clean theme

    toggle = find("button[aria-label='Toggle dark mode']")

    refute dark_mode_enabled?

    toggle.click
    assert dark_mode_enabled?

    toggle.click
    refute dark_mode_enabled?
  end

  private

  def dark_mode_enabled?
    page.evaluate_script("document.documentElement.classList.contains('dark')")
  end
end
