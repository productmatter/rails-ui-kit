# frozen_string_literal: true

require 'application_system_test_case'

class SeparatorTest < ApplicationSystemTestCase
  setup do
    visit separator_path
    disable_transitions
  end

  test 'a decorative separator carries role=none' do
    separator = preview.all('[data-slot=separator]').first
    assert_equal 'none', separator['role']
  end

  test 'a decorative separator is not exposed to the accessibility tree' do
    assert page.evaluate_script(<<~JS, preview.all('[data-slot=separator]').first)
      (() => { const node = arguments[0]; return node.getAttribute('role') === 'none' })()
    JS
  end

  test 'the separator preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#separator-preview')

    use_dark_mode(true)
    assert_accessible(within: '#separator-preview')
  end

  private

  def preview
    find_by_id('separator-preview')
  end
end
