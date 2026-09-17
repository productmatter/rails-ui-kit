# frozen_string_literal: true

require 'test_helper'
require 'support/field_models'

module Ui
  # A group inside a Field (ui-choices § Behavior, item 10): the label names it without `for`,
  # the fieldset takes the id, name, description, error, invalid state and required, and the
  # record's value arrives as `checked:`. Everything here is Field's existing wiring being
  # routed, not new wiring.
  class FieldChoicesTest < ViewComponent::TestCase
    class Membership
      include ActiveModel::API

      attr_accessor :role_ids, :plan

      validates :plan, presence: true
    end

    ROLES = [Struct.new(:id, :name).new(1, 'Admin'), Struct.new(:id, :name).new(2, 'Editor')].freeze

    def render_field(field_attributes = {}, control_attributes = {})
      render_inline(Ui::FieldComponent.new(**field_attributes)) do |field|
        field.with_label { 'Roles' } unless field_attributes.key?(:model)
        field.with_control(Ui::ChoicesComponent, collection: ROLES, value_method: :id, text_method: :name,
                                                 **control_attributes)
        field.with_description { 'People with no role see nothing.' }
      end
    end

    test 'FC1 the label keeps its id and drops for, and the fieldset carries aria-labelledby' do
      render_field({ name: 'user[role_ids]' }, { multiple: true })

      assert_selector 'label#user_role_ids-label:not([for])', text: 'Roles'
      assert_selector "fieldset#user_role_ids[aria-labelledby='user_role_ids-label']", visible: :all
      assert_selector "input[type=checkbox][name='user[role_ids][]']", count: 2, visible: :all
    end

    test 'FC2 an Input, Textarea or Select field still names its control with for' do
      { Ui::InputComponent => 'input', Ui::TextareaComponent => 'textarea', Ui::SelectComponent => 'select' }
        .each do |component, element|
        render_inline(Ui::FieldComponent.new(name: 'user[email]')) do |field|
          field.with_label { 'Email' }
          field.with_control(component, **(component == Ui::SelectComponent ? { options: %w[a b] } : {}))
        end

        assert_selector "label[for='user_email']#user_email-label", text: 'Email'
        assert_selector "#{element}#user_email", visible: :all
      end
    end

    test 'FC3 the description, the error and then the hint are what describe the group' do
      render_field({ name: 'user[role_ids]', errors: ['must have at least one'], required: true },
                   { multiple: true })

      assert_selector "fieldset[aria-describedby='user_role_ids-description user_role_ids-error " \
                      "user_role_ids-required'][aria-invalid='true']", visible: :all
      assert_selector 'fieldset[data-required=true]', visible: :all
      assert_selector 'span#user_role_ids-required', text: 'Select at least one option.', visible: :all
      assert_selector '[data-slot=field-required-indicator]'
    end

    test 'FC4 a required radio group inside a Field is required on every radio and describes no hint' do
      render_inline(Ui::FieldComponent.new(name: 'account[plan]', required: true)) do |field|
        field.with_label { 'Plan' }
        field.with_control(Ui::ChoicesComponent, options: %w[pro free])
      end

      assert_selector 'input[type=radio][required]', count: 2, visible: :all
      assert_selector 'fieldset[role=radiogroup]:not([aria-describedby])', visible: :all
    end

    test 'FC5 a model-bound Field hands the record value over as checked:' do
      record = Membership.new(role_ids: [2], plan: 'pro')

      render_inline(Ui::FieldComponent.new(model: record, attribute: :role_ids)) do |field|
        field.with_control(Ui::ChoicesComponent, multiple: true, collection: ROLES,
                                                 value_method: :id, text_method: :name)
      end

      assert_selector "input[value='2'][checked]", visible: :all
      assert_no_selector "input[value='1'][checked]", visible: :all
    end

    test 'FC6 a checked: the caller states wins over the record value, as selected: does for Select' do
      record = Membership.new(role_ids: [2])

      render_inline(Ui::FieldComponent.new(model: record, attribute: :role_ids)) do |field|
        field.with_control(Ui::ChoicesComponent, multiple: true, checked: [1], collection: ROLES,
                                                 value_method: :id, text_method: :name)
      end

      assert_selector "input[value='1'][checked]", visible: :all
      assert_no_selector "input[value='2'][checked]", visible: :all
    end

    test 'FC7 a model-bound required radio group derives required from the validator' do
      render_inline(Ui::FieldComponent.new(model: Membership.new, attribute: :plan)) do |field|
        field.with_control(Ui::ChoicesComponent, options: %w[pro free])
      end

      assert_selector 'label:not([for])', text: 'Plan'
      assert_selector 'input[type=radio][required]', count: 2, visible: :all
      # The group is named by whatever id Field derived for this record, not by a name a test
      # restates: the two have to be the same id, which is the point.
      label_id = page.find('label[data-slot=label]')['id']
      assert_selector "fieldset[aria-labelledby='#{label_id}']", visible: :all
    end
  end
end
