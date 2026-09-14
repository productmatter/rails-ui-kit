# frozen_string_literal: true

require 'test_helper'
require 'support/field_models'

module Ui
  # The name and id a model-bound Field derives, held against what form_with(model:) and
  # fields_for actually render for the same record, never against a written-out string
  # (ui-field-model-binding § Behavior, items 4 and 5; § Business rules, rule 3).
  class FieldModelNamingTest < ViewComponent::TestCase
    def view
      vc_test_controller.view_context
    end

    def rails_input(record, attribute)
      html = view.form_with(model: record, url: '/') { |form| form.text_field(attribute) }
      Nokogiri::HTML5.fragment(html).at_css('input[type=text]')
    end

    def field_input(record, attribute, **)
      render_inline(Ui::FieldComponent.new(model: record, attribute: attribute, **))
      page.find('input[data-slot=input]', visible: :all)
    end

    def assert_matches_form_with(record, attribute)
      rails = rails_input(record, attribute)
      field = field_input(record, attribute)

      assert_equal rails['name'], field['name']
      assert_equal rails['id'], field['id']
    end

    test 'a plain record gets form_with\'s name and id' do
      assert_matches_form_with FieldModels::User.new, :email
    end

    test 'a module-namespaced record gets form_with\'s name and id' do
      assert_matches_form_with FieldModels::Admin::User.new, :email
    end

    test 'a record with a custom model_name gets form_with\'s name and id' do
      assert_matches_form_with FieldModels::Person.new, :email
    end

    # The trap: field_id given the record uses model_name.singular, which disagrees with
    # form_with for a relatively named model. Derivation goes through the param key.
    test 'an engine-isolated record gets form_with\'s id, not field_id(record)\'s' do
      record = FieldModels::Blog::Post.new
      assert_matches_form_with record, :title

      assert_not_equal view.field_id(record, :title), field_input(record, :title)['id'],
                       'field_id(record, …) and form_with agree here, so this case no longer proves anything'
    end

    test 'a nested record given its full name gets the id fields_for renders' do
      comment = FieldModels::Comment.new
      html = view.form_with(model: FieldModels::Blog::Post.new, url: '/') do |form|
        form.fields_for(:comments_attributes, comment, index: 0) { |nested| nested.text_field(:body) }
      end
      rails = Nokogiri::HTML5.fragment(html).at_css('input[type=text]')

      field = field_input(comment, :body, name: rails['name'])

      assert_equal rails['name'], field['name']
      assert_equal rails['id'], field['id']
    end

    test 'the label names the derived id' do
      field_input(FieldModels::User.new, :email)

      assert_selector "label[for='#{page.find('input', visible: :all)['id']}']"
    end
  end
end
