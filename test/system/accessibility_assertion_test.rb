# frozen_string_literal: true

require 'application_system_test_case'
require 'erb'

class AccessibilityAssertionTest < ApplicationSystemTestCase
  KNOWN_BAD_PAGE = <<~HTML
    <html lang="en">
      <head><title>Axe fixture</title></head>
      <body>
        <main>
          <h1>Axe fixture</h1>
          <img src="x.png">
        </main>
      </body>
    </html>
  HTML

  test 'assert_accessible fails with axe violation report on a page seeded with a known violation' do
    visit "data:text/html,#{ERB::Util.url_encode(KNOWN_BAD_PAGE)}"

    error = assert_raises(Minitest::Assertion) { assert_accessible }

    assert_match(/accessibility violation/i, error.message)
    assert_match(/image-alt/, error.message)
  end
end
