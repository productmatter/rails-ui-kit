# frozen_string_literal: true

require 'test_helper'
require 'action_dispatch/system_test_case'
require 'selenium-webdriver'
require 'axe/core'
require 'axe/api'

Capybara.register_driver :rails_ui_kit_headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Base class for browser tests under test/system/. Never require this file, or
# anything it requires, from test/test_helper.rb -- that would pull Capybara and
# Selenium into the unit lane. See docs/specs/ui-test-harness/spec.md.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rails_ui_kit_headless_chrome, screen_size: [1400, 1400]

  # Runs a real axe-core audit against the current Capybara page and fails with
  # axe's own violation report -- not a bare boolean -- when it finds violations.
  # `within` narrows the audit to a CSS selector, mirroring axe's own `context`.
  def assert_accessible(within: nil)
    run = Axe::API::Run.new
    run = run.within(within) if within

    audit = Axe::Core.new(page).call(run)
    assert audit.passed?, audit.failure_message
  end
end
