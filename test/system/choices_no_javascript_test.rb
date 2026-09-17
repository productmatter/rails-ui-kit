# frozen_string_literal: true

require 'application_system_test_case'

# With JavaScript off, Choices is what it was server-rendered as: real inputs that submit. Driven
# by rack_test -- no browser at all, which is the strongest possible form of "JavaScript never
# ran" (ui-choices § Behavior, item 14, and § Business rules, rule 1).
class ChoicesNoJavascriptTest < ApplicationSystemTestCase
  driven_by :rack_test

  setup { visit choices_path }

  test 'CN1 the groups are fieldsets of real inputs, named and described without a single script' do
    assert_selector 'fieldset#demo_plan[role=radiogroup][aria-labelledby=demo_plan-label]'
    assert_selector 'label#demo_plan-label:not([for])', text: 'Plan'
    assert_selector 'fieldset#demo_role_ids:not([role])'
    assert_selector 'input[type=radio][name="demo[plan]"]', count: 3, visible: :all
    assert_selector 'input[type=checkbox][name="demo[role_ids][]"]', count: 3, visible: :all
  end

  test 'CN2 a checkbox group posts its choices, and the hidden entry is there to clear them' do
    within('#choices-round-trip') do
      check 'Editor'
      click_button 'Save'
    end

    assert_text 'Server received: 1, 2'
    assert_selector "input[value='2'][checked]", visible: :all
  end

  test 'CN3 unchecking everything clears the attribute, through the blank entry' do
    within('#choices-round-trip') do
      uncheck 'Admin'
      click_button 'Save'
    end

    assert_text 'Server received: no roles'
    assert_selector '[data-slot=field-error]', text: 'needs at least one role'
  end

  test 'CN4 a required checkbox group posts anyway, and the server answers with the error' do
    # The hint is rendered server-side, so a screen reader user meets it whether or not the
    # controller ever connects; the enforcement is the server's here.
    assert_selector 'span#required_role_ids-required', text: 'Select at least one option.', visible: :all
    assert_selector 'fieldset#required_role_ids[data-required=true][aria-describedby~=required_role_ids-required]'
    assert_no_selector '#required_role_ids input[required]', visible: :all

    within('#choices-round-trip') do
      uncheck 'Admin'
      click_button 'Save'
    end
    assert_selector '[data-slot=field-error]', text: 'needs at least one role'
  end

  test 'CN5 a required radio group carries required on every radio, with no controller anywhere' do
    assert_selector '#required_plan input[type=radio][required]', count: 3, visible: :all
    assert_no_selector 'fieldset[role=radiogroup][data-controller]', visible: :all
    # The one controller the kit attaches, and only where the browser has no constraint of its own.
    assert_selector 'fieldset#required_role_ids[data-controller="ui--choices"]', visible: :all
    assert_equal page.all('fieldset[data-controller]', visible: :all).size,
                 page.all('fieldset[data-controller="ui--choices"]', visible: :all).size
  end

  test 'CN6 a locked, checked value still posts, through the hidden input beside it' do
    assert_selector '#locked_role_ids_1[disabled][checked]', visible: :all
    carriers = page.all('#choices-locked-form input[type=hidden]', visible: :all).map { |input| input[:value] }

    assert_equal ['', '1'], carriers
    assert_equal ['locked[role_ids][]'],
                 page.all('#choices-locked-form input[type=hidden]', visible: :all).map { |input| input[:name] }.uniq
  end
end
