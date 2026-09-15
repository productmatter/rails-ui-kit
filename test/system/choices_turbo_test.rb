# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'choices_helpers'

# Choices holds no state of its own: every checked state lives in a real input, which is what
# makes dirty tracking and Turbo's page cache work with no help from the component
# (ui-choices § Behavior, item 20, and § Business rules, rule 1).
class ChoicesTurboTest < ApplicationSystemTestCase
  include ChoicesHelpers

  setup do
    visit choices_path
  end

  def watch_form_change
    page.execute_script(<<~JS)
      const form = document.querySelector('#choices-round-trip form')
      window.__formChange = []
      form.addEventListener('form:changed', () => window.__formChange.push('changed'))
      form.addEventListener('form:pristine', () => window.__formChange.push('pristine'))
      form.setAttribute('data-controller', 'ui--form-change')
    JS
    assert_selector '#choices-round-trip form[data-controller="ui--form-change"]'
    # ui--form-change announces its starting state on connect; what is under test is what happens
    # to a choice after that, so the log starts once it has settled.
    assert_equal %w[pristine], form_change_events
    page.execute_script('window.__formChange = []')
  end

  def form_change_events
    page.evaluate_script('window.__formChange')
  end

  test 'CT1 ui--form-change turns dirty when a choice changes and pristine when it changes back' do
    watch_form_change

    find('#membership_role_ids_2').click
    assert_equal %w[changed], form_change_events

    find('#membership_role_ids_2').click
    assert_equal %w[changed pristine], form_change_events,
                 'unchecking the box it checked did not put the form back to pristine'
  end

  test 'CT2 a radio choice is dirty tracking too, through the same FormData comparison' do
    watch_form_change

    find('#membership_plan_growth').click
    assert_equal %w[changed], form_change_events

    find('#membership_plan_starter').click
    assert_equal %w[changed pristine], form_change_events
  end

  test 'CT3 Back from a cached page restores the choices the user left' do
    find('#demo_role_ids_2').click
    find('#demo_plan_starter').click
    assert_equal %w[1 2], checked_values('fieldset#demo_role_ids')

    page.execute_script('Turbo.visit(arguments[0])', installation_path)
    assert_selector 'h1', text: 'Installation'

    page.go_back
    assert_selector 'h1', text: 'Choices'

    assert_equal %w[1 2], checked_values('fieldset#demo_role_ids'),
                 'the page cache lost the boxes the user checked'
    assert_equal %w[starter], checked_values('fieldset#demo_plan')
  end

  test 'CT4 a required group restored from the cache still enforces itself' do
    page.execute_script("document.getElementById('choices-required-submit').scrollIntoView({ block: 'center' })")
    find('#required_role_ids_1').click

    page.execute_script('Turbo.visit(arguments[0])', installation_path)
    assert_selector 'h1', text: 'Installation'
    page.go_back
    assert_selector 'h1', text: 'Choices'

    assert_equal %w[1], checked_values('fieldset#required_role_ids')
    assert_equal '', validation_message('#required_role_ids_1')

    find('#required_role_ids_1').click
    assert_equal 'Select at least one option.', validation_message('#required_role_ids_1'),
                 'the restored group did not re-derive its constraint'
  end
end
