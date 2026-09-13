# frozen_string_literal: true

require 'application_system_test_case'

class SpinnerTest < ApplicationSystemTestCase
  setup do
    visit spinner_path
    disable_transitions
  end

  test 'every spinner exposes role=status with a non-empty accessible name' do
    preview.all('[data-slot=spinner]').each do |spinner|
      assert_equal 'status', spinner['role']
      name = page.evaluate_script('arguments[0].textContent.trim()', spinner)
      assert_not_empty name, 'spinner has no accessible name'
    end
  end

  test 'the spinner preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#spinner-preview')

    use_dark_mode(true)
    assert_accessible(within: '#spinner-preview')
  end

  private

  def preview
    find_by_id('spinner-preview')
  end
end
