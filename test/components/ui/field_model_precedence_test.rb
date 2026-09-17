# frozen_string_literal: true

require 'test_helper'
require 'support/field_models'

module Ui
  # What raises, and the one precedence rule: an explicit keyword replaces its derived value
  # and every other derivation still applies (ui-field-model-binding § Behavior, items 2
  # and 3).
  class FieldModelPrecedenceTest < ViewComponent::TestCase
    def invalid_user
      FieldModels::User.new.tap(&:validate)
    end

    def assert_raises_naming(pattern, &)
      error = assert_raises(ArgumentError, &)
      assert_match pattern, error.message
    end

    test 'neither name: nor model: raises' do
      assert_raises_naming(/needs name:.*or model: with attribute:/) { Ui::FieldComponent.new }
    end

    test 'model: without attribute: raises' do
      assert_raises_naming(/needs attribute:/) { Ui::FieldComponent.new(model: FieldModels::User.new) }
    end

    test 'attribute: without model: raises' do
      assert_raises_naming(/needs model:/) { Ui::FieldComponent.new(name: 'user[email]', attribute: :email) }
    end

    test 'model: nil raises rather than rendering a nameless field' do
      assert_raises_naming(/to_model/) { Ui::FieldComponent.new(model: nil, attribute: :email) }
    end

    test 'a symbol raises and points to name:' do
      assert_raises_naming(/pass name:/) { Ui::FieldComponent.new(model: :user, attribute: :email) }
    end

    test 'a string, a hash and a model class each raise' do
      [+'user', { email: 'a' }, FieldModels::User].each do |model|
        assert_raises_naming(/to_model/) { Ui::FieldComponent.new(model: model, attribute: :email) }
      end
    end

    test 'a to_model result without model_name and errors raises' do
      shapeless = Struct.new(:email) do
        def to_model = self
      end

      assert_raises_naming(/model_name and errors/) { Ui::FieldComponent.new(model: shapeless.new, attribute: :email) }
    end

    test 'an attribute path or a predicate name raises' do
      ['address.city', 'comments_attributes][0][body', 'tags[]', :admin?].each do |attribute|
        assert_raises_naming(/single attribute name/) { Ui::FieldComponent.new(model: FieldModels::User.new, attribute: attribute) }
      end
    end

    test 'an explicit name: replaces the derived one, and the id follows it' do
      render_inline(Ui::FieldComponent.new(model: invalid_user, attribute: :email, name: 'account[email]'))

      assert_selector "input#account_email[name='account[email]'][required][aria-invalid='true']"
      assert_selector "label[for='account_email']", text: 'Email'
    end

    test 'an explicit errors: replaces the model\'s, and an empty array shows none' do
      render_inline(Ui::FieldComponent.new(model: invalid_user, attribute: :email, errors: []))

      assert_no_selector '[data-slot=field-error]'
      assert_selector "input[name='field_models_user[email]'][required]:not([aria-invalid])"
    end

    test 'explicit errors are not merged with the model\'s' do
      render_inline(Ui::FieldComponent.new(model: invalid_user, attribute: :email, errors: ['is taken']))

      assert_selector '[data-slot=field-error]', exact_text: 'is taken'
    end

    test 'an explicit required: false replaces derivation' do
      render_inline(Ui::FieldComponent.new(model: invalid_user, attribute: :email, required: false))

      assert_selector "input[name='field_models_user[email]']:not([required])"
      assert_selector '[data-slot=field-error]', text: "can't be blank"
    end

    test 'a label block replaces the derived text' do
      render_inline(Ui::FieldComponent.new(model: invalid_user, attribute: :email)) do |field|
        field.with_label { 'Work email' }
      end

      assert_selector 'label[for=field_models_user_email]', text: 'Work email'
      assert_no_selector 'label', text: /\AEmail/
      assert_selector "input[name='field_models_user[email]'][required][aria-invalid='true']"
    end

    test 'an explicit control_id: replaces the derived id' do
      render_inline(Ui::FieldComponent.new(model: invalid_user, attribute: :email, control_id: 'ns_user_email'))

      assert_selector "input#ns_user_email[name='field_models_user[email]']"
      assert_selector 'label[for=ns_user_email]'
    end
  end
end
