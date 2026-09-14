# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# Step 1 of the lifecycle in docs/specs/ui-modal-turbo: following a data-turbo-stream trigger
# renders the modal into the layout container, names it, moves focus into it and locks the page.
class ModalTurboOpenTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  test 'a data-turbo-stream link renders the modal into the layout container' do
    assert_no_selector '#modal dialog'

    open_modal(1)

    assert_selector '#modal dialog', text: 'Acme rebrand'
    assert page.evaluate_script("document.querySelector('#modal dialog').matches(':modal')"),
           'the dialog is rendered but not in the top layer'
    # The container is the layout's plain div, and it stays put for the next modal.
    assert page.evaluate_script("document.querySelector('#modal').tagName === 'DIV'")
  end

  test 'the modal is named, focus moves into it, and the page behind is scroll-locked' do
    open_modal(1)

    assert_named 'Acme rebrand'
    assert page.evaluate_script("document.querySelector('#modal dialog').contains(document.activeElement)"),
           'focus is not inside the dialog'
    assert scroll_locked?
  end

  test 'the content is inside the modal content frame, ready to be swapped on its own' do
    open_modal(1)

    assert_selector '#modal dialog turbo-frame#project_modal_content h2', text: 'Acme rebrand'
  end

  test 'the Edit trigger opens straight into the edit state of the same modal' do
    open_modal(1, trigger: 'edit')

    assert_selector '#modal dialog turbo-frame#project_modal_content', text: 'Edit project'
    assert_selector '#modal dialog input[name="project[name]"]'
  end
end
