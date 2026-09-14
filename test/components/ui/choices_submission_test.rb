# frozen_string_literal: true

require 'test_helper'
require 'active_record'

# What the rendered group actually does to a record when the form is submitted
# (ui-choices § Business rules, rule 2). The entry list is built from the markup the way a
# browser builds one -- hidden fields always, checked inputs only, nothing disabled and nothing
# inside a disabled fieldset -- then parsed by Rack and assigned through strong parameters, so
# the thing under test is the markup, not a hand-written params hash.
#
# ActiveRecord is real here, in memory: `ids_writer`'s blank-dropping is the behaviour the
# hidden field depends on, and stubbing it would prove nothing.
class ChoicesSubmissionTest < ViewComponent::TestCase
  ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
  ActiveRecord::Schema.suppress_messages do
    ActiveRecord::Schema.define do
      create_table(:submission_users, force: true) { |t| t.string :plan }
      create_table(:submission_roles, force: true) { |t| t.string :name }
      create_table(:submission_roles_submission_users, id: false, force: true) do |t|
        t.integer :submission_user_id
        t.integer :submission_role_id
      end
    end
  end

  class SubmissionRole < ActiveRecord::Base
    self.table_name = 'submission_roles'
  end

  class SubmissionUser < ActiveRecord::Base
    self.table_name = 'submission_users'
    has_and_belongs_to_many :submission_roles, join_table: 'submission_roles_submission_users'
  end

  setup do
    SubmissionUser.delete_all
    SubmissionRole.delete_all
    @admin = SubmissionRole.create!(name: 'Admin')
    @editor = SubmissionRole.create!(name: 'Editor')
    @user = SubmissionUser.create!(submission_role_ids: [@admin.id, @editor.id])
  end

  def roles
    [@admin, @editor]
  end

  def markup(**attributes)
    render_inline(Ui::ChoicesComponent.new(collection: roles, value_method: :id, text_method: :name, **attributes))
    page.native
  end

  # Exactly what a browser puts in the entry list: a disabled fieldset contributes nothing at
  # all, a disabled input never submits, and an unchecked box never submits.
  def entry_list(fragment, checked: nil)
    return [] if fragment.at_css('fieldset[disabled]')

    fragment.css('input').reject { |input| skip_entry?(input, checked) }
            .map { |input| [input['name'], input['value'].to_s] }
  end

  def skip_entry?(input, checked)
    return true if input['disabled']
    return false unless %w[checkbox radio].include?(input['type'])
    return !checked.include?(input['value']) unless checked.nil?

    input['checked'].nil?
  end

  def submit(fragment, checked: nil)
    query = entry_list(fragment, checked: checked).map { |name, value| "#{CGI.escape(name)}=#{CGI.escape(value)}" }
    Rack::Utils.parse_nested_query(query.join('&'))
  end

  def assign(params)
    permitted = ActionController::Parameters.new(params).require(:submission_user)
                                            .permit(:plan, submission_role_ids: [])
    @user.update!(permitted)
    @user.reload.submission_role_ids
  end

  test 'CS1 unchecking every box clears the association, through Rails own blank entry' do
    params = submit(markup(name: 'submission_user[submission_role_ids]', multiple: true), checked: [])

    assert_equal({ 'submission_user' => { 'submission_role_ids' => [''] } }, params)
    assert_empty assign(params)
  end

  test 'CS2 without the hidden field the key never arrives, and the old roles survive' do
    params = submit(markup(name: 'submission_user[submission_role_ids]', multiple: true, include_hidden: false),
                    checked: [])

    assert_empty params
    assert_raises(ActionController::ParameterMissing) { assign(params) }
    assert_equal [@admin.id, @editor.id], @user.reload.submission_role_ids
  end

  test 'CS3 a checked, locked value survives a save that unchecks every other box' do
    fragment = markup(name: 'submission_user[submission_role_ids]', multiple: true,
                      checked: [@admin.id], disabled_values: [@admin.id])
    params = submit(fragment, checked: [])

    assert_equal [@admin.id.to_s], assign(params).map(&:to_s)
  end

  test 'CS4 a locked checked radio survives an untouched save and loses to a radio the user chose' do
    fragment = markup(name: 'submission_user[plan]', multiple: false, collection: nil, options: %w[pro free],
                      checked: 'pro', disabled_values: %w[pro])

    untouched = submit(fragment, checked: [])
    assert_equal({ 'submission_user' => { 'plan' => 'pro' } }, untouched)

    chosen = submit(fragment, checked: ['free'])
    assert_equal({ 'submission_user' => { 'plan' => 'free' } }, chosen,
                 'Rack keeps the last value for a repeated non-array key, so the user choice has to be last')
    assign(chosen)
    assert_equal 'free', @user.reload.plan
  end

  test 'CS5 a disabled group contributes no entry at all, carriers included' do
    fragment = markup(name: 'submission_user[submission_role_ids]', multiple: true, disabled: true,
                      checked: [@admin.id], disabled_values: [@admin.id])

    assert_empty submit(fragment)
    assert_equal [@admin.id, @editor.id], @user.reload.submission_role_ids
  end

  test 'CS6 a radio group with nothing checked submits the blank entry Rails submits' do
    params = submit(markup(name: 'submission_user[plan]', collection: nil, options: %w[pro free]))

    assert_equal({ 'submission_user' => { 'plan' => '' } }, params)
    assign(params)
    assert_equal '', @user.reload.plan
  end
end
