# frozen_string_literal: true

require 'application_system_test_case'

class HarnessSmokeTest < ApplicationSystemTestCase
  # Scoped to the rendered Button previews rather than the full page: the docs
  # chrome around them (sidebar, prop tables) has pre-existing color-contrast and
  # scrollable-region violations that are the component audit's problem, not
  # this harness's. See docs/specs/ui-test-harness/status.md.
  test 'drives a real rendered examples/ page and audits its component preview for accessibility' do
    visit button_path
    assert_selector 'h1', text: 'Button'

    page.execute_script(<<~JS)
      var heading = Array.from(document.querySelectorAll('h2')).find((h) => h.textContent.trim() === 'Preview')
      heading.nextElementSibling.id = 'axe-preview-target'
    JS

    assert_accessible(within: '#axe-preview-target')
  end
end
