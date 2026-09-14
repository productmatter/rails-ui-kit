# frozen_string_literal: true

require 'test_helper'
require 'support/field_models'

module Ui
  # The value a model-bound Field fills, held against the Rails helper for the same record,
  # in each of the kit's controls' own shape (ui-field-model-binding § Behavior, item 16).
  class FieldModelValueTest < ViewComponent::TestCase
    def view
      vc_test_controller.view_context
    end

    # The helper's markup, without the hidden authenticity and method inputs form_with adds.
    def rails(record, &)
      Nokogiri::HTML5.fragment(view.form_with(model: record, url: '/', &))
    end

    def render_bound(record, attribute, &)
      render_inline(Ui::FieldComponent.new(model: record, attribute: attribute), &)
    end

    test 'an Input\'s value equals form.text_field\'s' do
      user = FieldModels::User.new(email: 'ada@example.com')
      expected = rails(user) { |form| form.text_field(:email) }.at_css('input:not([type=hidden])')['value']

      render_bound(user, :email)

      assert_equal 'ada@example.com', expected
      assert_equal expected, page.find('input')['value']
    end

    test 'a _before_type_cast reader is used when the value came from the user, as form.text_field does' do
      [true, false].each do |from_user|
        record = FieldModels::Measurement.new(age_before_type_cast: 'abc', age_came_from_user: from_user)
        expected = rails(record) { |form| form.text_field(:age) }.at_css('input:not([type=hidden])')['value']

        render_bound(record, :age)

        assert_equal expected, page.find('input')['value'], "came_from_user: #{from_user}"
      end
      assert_equal %w[abc 0], [true, false].map { |from_user|
        rails(FieldModels::Measurement.new(age_before_type_cast: 'abc', age_came_from_user: from_user)) { |form| form.text_field(:age) }.at_css('input:not([type=hidden])')['value']
      }, 'the fixture no longer distinguishes the two readers'
    end

    test 'a nil value renders no value attribute, as form.text_field does' do
      render_bound(FieldModels::User.new, :email)

      assert_nil rails(FieldModels::User.new) { |form| form.text_field(:email) }.at_css('input:not([type=hidden])')['value']
      assert_nil page.find('input')['value']
    end

    test 'password and file Inputs render no value, as password_field and file_field don\'t' do
      user = FieldModels::User.new(password: 'hunter2', avatar: 'me.png')
      assert_nil rails(user) { |form| form.password_field(:password) }.at_css('input:not([type=hidden])')['value']
      assert_nil rails(user) { |form| form.file_field(:avatar) }.at_css('input:not([type=hidden])')['value']

      { password: 'password', avatar: 'file' }.each do |attribute, type|
        render_bound(user, attribute) { |field| field.with_control(Ui::InputComponent, type: type) }
        assert_nil page.find('input', visible: :all)['value'], "a #{type} input echoed its value"
        assert_not_includes page.native.to_html, user.public_send(attribute)
      end
    end

    test 'a Textarea gets the value as its content, as form.text_area does' do
      user = FieldModels::User.new(bio: "Line one\nLine two")
      expected = rails(user) { |form| form.text_area(:bio) }.at_css('textarea').text

      render_bound(user, :bio) { |field| field.with_control(Ui::TextareaComponent) }

      assert_equal "Line one\nLine two", expected
      assert_equal expected, page.find('textarea').value
    end

    test 'a Select gets the value as selected:' do
      user = FieldModels::User.new(city: 'lisbon')

      render_bound(user, :city) do |field|
        field.with_control(Ui::SelectComponent, options: [%w[Berlin berlin], %w[Lisbon lisbon]], native_on_touch: false)
      end

      assert_selector 'select option[value=lisbon][selected]', visible: :all
    end

    test 'a caller value wins' do
      user = FieldModels::User.new(email: 'ada@example.com', city: 'lisbon')

      render_bound(user, :email) { |field| field.with_control(Ui::InputComponent, value: 'grace@example.com') }
      assert_equal 'grace@example.com', page.find('input')['value']

      render_bound(user, :city) do |field|
        field.with_control(Ui::SelectComponent, options: [%w[Berlin berlin], %w[Lisbon lisbon]], selected: 'berlin')
      end
      assert_selector 'select option[value=berlin][selected]', visible: :all
      assert_no_selector 'select option[value=lisbon][selected]', visible: :all
    end

    test 'a custom control gets no derived value, and the block form reads field.value' do
      user = FieldModels::User.new(email: 'ada@example.com')
      render_in_view_context do
        render(inline: <<~ERB, locals: { user: user })
          <%= render Ui::FieldComponent.new(model: user, attribute: :email) do |field| %>
            <% field.with_control { |c| tag.input(**c.attributes, data: { from_block: field.value }) } %>
          <% end %>
        ERB
      end

      input = page.find('input')
      assert_nil input['value']
      assert_equal 'ada@example.com', input['data-from-block']
    end

    test 'the name form fills no value' do
      render_inline(Ui::FieldComponent.new(name: 'user[email]')) { |field| field.with_control(Ui::InputComponent) }

      assert_nil page.find('input')['value']
    end
  end
end
