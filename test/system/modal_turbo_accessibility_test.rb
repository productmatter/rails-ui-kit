# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# Accessibility is definition-of-done for every demo in this scope, not a later pass
# (ui-component-library § Business rules, rule 6). A real axe audit, in each state the modal
# actually renders.
class ModalTurboAccessibilityTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  test 'the demo modal passes an axe audit when open' do
    open_modal(1)

    assert_accessible(within: '#modal')
  end

  test 'the edit state passes an axe audit' do
    open_modal(1, trigger: 'edit')

    assert_accessible(within: '#modal')
  end

  test 'the validation-error state passes an axe audit' do
    open_modal(1, trigger: 'edit')
    fill_in 'Name', with: 'Q3 campaign'
    within('#modal') { click_on 'Save' }
    assert_selector '#modal turbo-frame#project_modal_content', text: 'is already taken'

    assert_accessible(within: '#modal')
  end

  test 'the read-only frame modal passes an axe audit' do
    open_activity_modal(1)

    assert_accessible(within: 'turbo-frame#project_activity_modal')
  end

  test 'the page itself passes an axe audit with no modal open' do
    assert_accessible
  end
end
