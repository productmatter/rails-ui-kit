# frozen_string_literal: true

require 'application_system_test_case'

class DarkModeToggleTest < ApplicationSystemTestCase
  test 'toggling dark mode adds and removes .dark on <html>' do
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

  private

  def dark_mode_enabled?
    page.evaluate_script("document.documentElement.classList.contains('dark')")
  end
end
