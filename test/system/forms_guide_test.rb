# frozen_string_literal: true

require 'application_system_test_case'
require 'rails_ui_kit/test_helpers'

# The demo docs/guides/forms.md is quoted from, driven the way a host app's own system test would
# drive its form. The guide's test-helper sample is a slice of this file.
class FormsGuideTest < ApplicationSystemTestCase
  include RailsUiKit::TestHelpers

  setup do
    Member.reset!
    visit edit_member_path(Member::SEED[:id])
  end

  test 'a save through every kind of field comes back with what was saved' do
    fill_in 'Name', with: 'Sam Okafor'
    ui_select 'Invited', from: 'Status'
    ui_select 'Growth', from: 'Team'
    check 'Viewer'
    fill_in 'City', with: 'Porto'
    click_on 'Save'

    assert_text 'Sam Okafor saved.'
    assert_equal 'invited', find_field('member[status]', visible: :all).value
    assert_equal '3', find_field('member[team_id]', visible: :all).value
    assert_checked_field 'Viewer'
    assert_field 'City', with: 'Porto'
  end

  test 'a member with no team comes back 422, with the error on the field that edits it' do
    ui_select 'No team', from: 'Team'
    fill_in 'Name', with: 'Sam Okafor'
    click_on 'Save'

    assert_selector '#member_team_id-error', text: 'must exist'
    assert_field 'Name', with: 'Sam Okafor'
  end

  test 'the docs page opens the demo, and has no accessibility violations' do
    visit forms_guide_path
    assert_accessible(within: 'main')
    click_on 'Open the demo form'

    assert_field 'Name', with: 'Sam Rivera'
  end

  test 'a locked role survives a hidden input removed in the browser' do
    page.execute_script(<<~JS)
      document.querySelector('input[type=hidden][name="member[role_ids][]"][value="1"]').remove()
    JS
    click_on 'Save'

    assert_text 'saved.'
    assert_includes Member.find(Member::SEED[:id]).role_ids, 1
  end
end
