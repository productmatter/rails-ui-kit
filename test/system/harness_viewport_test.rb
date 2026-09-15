# frozen_string_literal: true

require 'application_system_test_case'

# The registered screen_size was never applied to the window: driven_by only sizes a driver Rails
# registers itself, and every geometry test copied its own resize to make up for it. The base
# class now sizes the viewport before every test (docs/specs/ui-test-harness).
class HarnessViewportTest < ApplicationSystemTestCase
  test 'every test starts with a viewport of the registered size' do
    visit stress_bare_path

    assert_equal ApplicationSystemTestCase::SCREEN_SIZE, page.evaluate_script('[innerWidth, innerHeight]')
  end

  test 'a test that resized the shared window leaves the next one at the registered size' do
    resize_viewport_to(900, 700)
    visit stress_bare_path
    assert_equal [900, 700], page.evaluate_script('[innerWidth, innerHeight]')

    # What the next test's setup does.
    resize_viewport_to(*ApplicationSystemTestCase::SCREEN_SIZE)
    assert_equal ApplicationSystemTestCase::SCREEN_SIZE, page.evaluate_script('[innerWidth, innerHeight]')
  end
end
