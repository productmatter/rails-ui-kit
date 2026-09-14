# frozen_string_literal: true

require 'test_helper'
require 'support/field_models'

module Ui
  # Errors come from errors[attribute], the key Rails' error_wrapping reads, and a Field's
  # control never passes through field_error_proc (ui-field-model-binding § Behavior,
  # items 13 and 17).
  class FieldModelErrorsTest < ViewComponent::TestCase
    def invalid_user
      FieldModels::User.new.tap(&:validate)
    end

    test 'errors are the model\'s messages for the attribute, joined into one error' do
      user = invalid_user
      user.errors.add(:email, :invalid)

      render_inline(Ui::FieldComponent.new(model: user, attribute: :email))

      assert_selector '[data-slot=field-error]', exact_text: user.errors[:email].to_sentence
      assert_equal 1, page.all('[data-slot=field-error]').size
      assert_selector "input[aria-invalid='true'][aria-describedby='field_models_user_email-error']"
      assert_selector "[data-slot=field][data-invalid='true']"
    end

    test 'another attribute\'s errors don\'t mark this field' do
      user = FieldModels::User.new(email: 'a@b.c')
      user.errors.add(:nickname, :taken)

      render_inline(Ui::FieldComponent.new(model: user, attribute: :email))

      assert_no_selector '[data-slot=field-error]'
      assert_no_selector '[aria-invalid]'
    end

    test 'a field_error_proc that wraps visibly never wraps a Field control' do
      original = ActionView::Base.field_error_proc
      ActionView::Base.field_error_proc = ->(html, _instance) { %(<div class="field_with_errors">#{html}</div>).html_safe }
      user = invalid_user

      rails = vc_test_controller.view_context.form_with(model: user, url: '/') { |form| form.text_field(:email) }
      assert_includes rails, 'field_with_errors', 'the proc no longer wraps form.text_field, so this proves nothing'

      render_inline(Ui::FieldComponent.new(model: user, attribute: :email))
      assert_no_selector '.field_with_errors'
      assert_selector '[data-slot=field-error]'
    ensure
      ActionView::Base.field_error_proc = original
    end
  end
end
