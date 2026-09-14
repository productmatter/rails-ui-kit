# frozen_string_literal: true

require 'application_system_test_case'

class MediaQueryTest < ApplicationSystemTestCase
  setup { visit media_query_path }

  test 'reflects breakpoint state and updates it as the viewport crosses the breakpoint' do
    page.driver.browser.manage.window.resize_to(1200, 900)
    assert_equal 'true', watched['data-media-matches']

    page.driver.browser.manage.window.resize_to(500, 900)
    assert_equal 'false', watched['data-media-matches']

    page.driver.browser.manage.window.resize_to(1200, 900)
    assert_equal 'true', watched['data-media-matches']
  end

  test 'toggles the matches class with the query state' do
    page.driver.browser.manage.window.resize_to(1200, 900)
    assert_includes watched['class'].split, 'border-primary'

    page.driver.browser.manage.window.resize_to(500, 900)
    assert_not_includes watched['class'].split, 'border-primary'
  end

  test 'releases its change listener on disconnect' do
    page.execute_script(<<~JS)
      window.__mediaQueryRemoveCalls = 0
      const original = MediaQueryList.prototype.removeEventListener
      MediaQueryList.prototype.removeEventListener = function (...args) {
        window.__mediaQueryRemoveCalls += 1
        return original.apply(this, args)
      }

      const probe = document.createElement('div')
      probe.id = 'media-query-disconnect-probe'
      probe.setAttribute('data-controller', 'ui--media-query')
      probe.setAttribute('data-ui--media-query-query-value', '(min-width: 768px)')
      document.body.appendChild(probe)
    JS

    # The probe is a bare, empty <div> -- zero-height, so Capybara/Selenium treats it
    # as not "visible" even though it's in the DOM with the attribute set.
    assert page.has_css?('#media-query-disconnect-probe[data-media-matches]', visible: :all)

    page.execute_script("document.getElementById('media-query-disconnect-probe').remove()")

    assert_equal 1, page.evaluate_script('window.__mediaQueryRemoveCalls')
  end

  private

  def watched
    find('[data-controller="ui--media-query"]')
  end
end
