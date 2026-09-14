# frozen_string_literal: true

require 'test_helper'
require 'support/field_models'

module Ui
  # Label text resolves in form.label's order, and each step is held against form.label's
  # own output for the same record (ui-field-model-binding § Behavior, items 6–8).
  class FieldModelLabelTest < ViewComponent::TestCase
    def view
      vc_test_controller.view_context
    end

    def rails_label(record, attribute)
      html = view.form_with(model: record, url: '/') { |form| form.label(attribute) }
      Nokogiri::HTML5.fragment(html).at_css('label').text
    end

    def field_label(record, attribute)
      render_inline(Ui::FieldComponent.new(model: record, attribute: attribute))
      page.find('label').text
    end

    def with_translations(translations)
      I18n.backend.store_translations(:en, translations)
      yield
    ensure
      I18n.backend.reload!
    end

    def assert_label_matches(record, attribute, expected)
      assert_equal expected, rails_label(record, attribute), 'the fixture no longer exercises this step'
      assert_equal rails_label(record, attribute), field_label(record, attribute)
    end

    test 'helpers.label under the param key wins over everything' do
      translations = { helpers: { label: { person: { email: 'Contact' } } },
                       activemodel: { attributes: { 'field_models/person': { email: 'Mail' } } } }
      with_translations(translations) { assert_label_matches FieldModels::Person.new, :email, 'Contact' }
    end

    test 'helpers.label under the i18n key comes next' do
      translations = { helpers: { label: { 'field_models/blog/post': { title: 'Headline' } } },
                       activemodel: { attributes: { 'field_models/blog/post': { title: 'Name' } } } }
      with_translations(translations) do
        assert_equal [:'field_models/blog/post', 'post'], [FieldModels::Blog::Post.model_name.i18n_key, FieldModels::Blog::Post.model_name.param_key]
        assert_label_matches FieldModels::Blog::Post.new, :title, 'Headline'
      end
    end

    test 'then human_attribute_name, through activemodel.attributes' do
      with_translations(activemodel: { attributes: { 'field_models/user': { nickname: 'Handle' } } }) do
        assert_label_matches FieldModels::User.new, :nickname, 'Handle'
      end
    end

    test 'then the humanised attribute, for a class without human_attribute_name' do
      assert_label_matches FieldModels::Bare.new, :email, 'Email'
    end

    test 'with a record and no block, a label and an Input render' do
      render_inline(Ui::FieldComponent.new(model: FieldModels::User.new, attribute: :nickname))

      assert_selector "div[data-slot=field] > label[for=field_models_user_nickname][id='field_models_user_nickname-label']", exact_text: 'Nickname'
      assert_selector "div[data-slot=field] > input[data-slot=input][type=text][name='field_models_user[nickname]']"
    end

    test 'with_label with attributes and no block keeps the derived text' do
      render_inline(Ui::FieldComponent.new(model: FieldModels::User.new, attribute: :nickname)) do |field|
        field.with_label(class: 'text-base')
      end

      assert_selector 'label.text-base', exact_text: 'Nickname'
    end

    test 'the name form still renders no label or control unless asked' do
      render_inline(Ui::FieldComponent.new(name: 'user[email]'))

      assert_no_selector 'label'
      assert_no_selector 'input'
    end
  end
end
