# frozen_string_literal: true

require 'test_helper'
require 'support/field_models'

module Ui
  # The server-rendered half of the help-text swap: an invalid field's description is hidden
  # and its error is where it was, a valid field shows the description and no error, and
  # aria-describedby is right in both (ui-field-model-binding § Behavior, items 19, 20 and 22).
  class FieldMessageSwapTest < ViewComponent::TestCase
    def description
      page.find('[data-slot=field-description]', visible: :all)
    end

    def control
      page.find('input', visible: :all)
    end

    def render_named(errors: nil, **options)
      render_inline(Ui::FieldComponent.new(name: 'user[email]', errors: errors, **options)) do |field|
        field.with_label { 'Email' }
        field.with_control(Ui::InputComponent)
        field.with_description { 'We only use this for receipts.' }
      end
    end

    def render_bound(user)
      render_inline(Ui::FieldComponent.new(model: user, attribute: :email)) do |field|
        field.with_description { 'Your work address.' }
      end
    end

    test 'an invalid field hides its description and shows the error after it' do
      render_named(errors: ['is invalid'])

      assert description.matches_css?('[hidden]', visible: :all)
      assert_no_selector '[data-slot=field-description]'
      assert_selector '[data-slot=field-description][hidden] + [data-slot=field-error]', visible: :all
      assert_selector '[data-slot=field-error]:not([hidden])', exact_text: 'is invalid'
    end

    test 'a valid field shows its description and renders no error' do
      render_named

      assert_selector '[data-slot=field-description]:not([hidden])', text: 'We only use this for receipts.'
      assert_no_selector '[data-slot=field-error]', visible: :all
    end

    test 'the model-bound form swaps the same way, both ways' do
      render_bound(FieldModels::User.new.tap(&:validate))
      assert_selector '[data-slot=field-description][hidden]', visible: :all
      assert_selector '[data-slot=field-error]', text: "can't be blank"

      render_bound(FieldModels::User.new(email: 'ada@example.com').tap(&:validate))
      assert_selector '[data-slot=field-description]:not([hidden])'
      assert_no_selector '[data-slot=field-error]', visible: :all
    end

    test 'aria-describedby names the description when valid, and the description then the error when invalid' do
      render_named
      assert_equal 'user_email-description', control['aria-describedby']

      render_named(errors: ['is invalid'])
      assert_equal 'user_email-description user_email-error', control['aria-describedby']
      assert_equal 'user_email-description', description['id'], 'the hidden description is referenced, so it must keep its id'
    end

    test 'a field with no description shows the error alone' do
      render_inline(Ui::FieldComponent.new(name: 'email', errors: ['is invalid'])) { |field| field.with_control(Ui::InputComponent) }

      assert_selector '[data-slot=field-error]', text: 'is invalid'
      assert_equal 'email-error', control['aria-describedby']
    end

    test 'a caller\'s hidden: on the description is still theirs on a valid field' do
      render_inline(Ui::FieldComponent.new(name: 'email')) do |field|
        field.with_description(hidden: true) { 'Hint' }
      end

      assert_selector '[data-slot=field-description][hidden]', visible: :all
    end

    test 'the wrapper carries ui--field, joined with a caller\'s own controllers' do
      render_named
      assert_selector "[data-slot=field][data-controller='ui--field']"

      render_named(data: { controller: 'autosave' })
      assert_selector "[data-slot=field][data-controller='ui--field autosave']"
    end

    test 'the description and the error fade on data-state, and not under reduced motion' do
      render_named(errors: ['is invalid'])

      [description, page.find('[data-slot=field-error]')].each do |part|
        classes = part['class'].split
        assert_includes classes, 'data-[state=closing]:opacity-0'
        assert_includes classes, 'data-[state=closed]:opacity-0'
        assert_includes classes, 'motion-reduce:transition-none'
      end
    end

    test 'no role on a server-rendered error' do
      render_named(errors: ['is invalid'])

      assert_nil page.find('[data-slot=field-error]')['role']
    end
  end
end
