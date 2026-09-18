# frozen_string_literal: true

require 'test_helper'
require 'support/field_models'

module Ui
  # Required detection reads an unconditional presence validator and nothing else, and one
  # resolved value drives the control, the wrapper and the label marker together
  # (ui-field-model-binding § Behavior, items 9–14).
  class FieldModelRequiredTest < ViewComponent::TestCase
    NOT_REQUIRED = %i[conditional unless_conditional on_create on_update on_custom allow_nil allow_blank
                      length numericality inclusion format comparison acceptance custom_method
                      each_validator validates_with unknown_option].freeze

    # The three places, read together, so a test can't pass with them disagreeing.
    def required_state
      [page.has_css?('[data-slot=field][data-required=true]'),
       page.has_css?('[required]', visible: :all),
       page.has_css?('label [data-slot=field-required-indicator][aria-hidden=true]')]
    end

    def assert_required(message = nil)
      assert_equal [true, true, true], required_state, message
    end

    def assert_not_required(message = nil)
      assert_equal [false, false, false], required_state, message
    end

    def render_bound(record, attribute, **, &)
      render_inline(Ui::FieldComponent.new(model: record, attribute: attribute, **), &)
    end

    test 'an unconditional presence validator marks the field required' do
      render_bound(FieldModels::Validated.new, :plain)
      assert_required
    end

    test 'message: and strict: keep a presence validator unconditional' do
      %i[with_message strict].each do |attribute|
        render_bound(FieldModels::Validated.new, attribute)
        assert_required "#{attribute} should be required"
      end
    end

    test 'every conditional, weakened, indirect or opaque validation leaves the field not required' do
      NOT_REQUIRED.each do |attribute|
        render_bound(FieldModels::Validated.new, attribute)
        assert_not_required "#{attribute} should not be required"
      end
    end

    test 'the unknown-option case really is a presence validator, so it tests the option rule' do
      validator = FieldModels::Validated.validators_on(:unknown_option).sole

      assert_equal :presence, validator.kind
      assert_includes validator.options.keys, :if_feature
    end

    test 'a class without validators_on is not required' do
      render_bound(FieldModels::Bare.new, :email)
      assert_not_required
    end

    test 'required: true and required: false override derivation both ways' do
      render_bound(FieldModels::Validated.new, :conditional, required: true)
      assert_required

      render_bound(FieldModels::Validated.new, :plain, required: false)
      assert_not_required
    end

    test 'a with_control required: outranks the field\'s, whichever order the parts are set in' do
      render_bound(FieldModels::Validated.new, :plain, required: true) do |field|
        field.with_control(Ui::InputComponent, required: false)
        field.with_label(class: 'text-base')
      end
      assert_not_required

      render_bound(FieldModels::Validated.new, :conditional) do |field|
        field.with_label(class: 'text-base')
        field.with_control(Ui::InputComponent, required: true)
      end
      assert_required
    end

    test 'a form param string for required: resolves the way the control renders it' do
      render_bound(FieldModels::Validated.new, :plain) { |field| field.with_control(Ui::InputComponent, required: 'false') }
      assert_not_required
    end

    test 'the name form with required: true behaves the same' do
      render_inline(Ui::FieldComponent.new(name: 'user[email]', required: true)) do |field|
        field.with_label { 'Email' }
        field.with_control(Ui::InputComponent)
      end
      assert_required

      render_inline(Ui::FieldComponent.new(name: 'user[email]')) do |field|
        field.with_control(Ui::InputComponent, required: true)
        field.with_label { 'Email' }
      end
      assert_required
    end

    test 'the name form without required renders none of the three' do
      render_inline(Ui::FieldComponent.new(name: 'user[email]')) do |field|
        field.with_label { 'Email' }
        field.with_control(Ui::InputComponent)
      end
      assert_not_required
    end

    test 'the block form receives the resolved required' do
      render_in_view_context do
        render(inline: <<~ERB, locals: { record: FieldModels::Validated.new })
          <%= render Ui::FieldComponent.new(model: record, attribute: :plain) do |field| %>
            <% field.with_control { |c| render(Ui::TextareaComponent.new(**c.attributes)) } %>
          <% end %>
        ERB
      end
      assert_required
    end

    test 'the marker is hidden from assistive technology and outside the label text node' do
      render_bound(FieldModels::Validated.new, :plain)

      marker = page.find('label [data-slot=field-required-indicator]')
      assert_equal 'true', marker['aria-hidden']
      assert_equal '*', marker.text
      assert_includes marker['class'], 'text-destructive'
    end

    test 'native controls get required, not aria-required' do
      render_bound(FieldModels::Validated.new, :plain)

      assert_no_selector '[aria-required]'
    end

    # The hidden required-label span (ui-select § Behavior, item 17, "Required is the label's to
    # say"): present only alongside the marker, named for a direct aria-labelledby reference, and
    # resolving call site -> host locale -> kit default like every other chrome string.
    test 'the hidden required-label span exists beside the marker, with its id and the chrome default text' do
      render_bound(FieldModels::Validated.new, :plain)

      label_id = page.find('label')['id']
      span = page.find('label [data-slot=field-required-text]', visible: :all)
      assert_equal "#{label_id}-required", span['id']
      assert span['hidden']
      assert_equal I18n.t('rails_ui_kit.field.required_label'), span.text(:all)
    end

    test 'the hidden required-label span is absent when the field is not required' do
      render_bound(FieldModels::Bare.new, :email)

      assert_no_selector '[data-slot=field-required-text]', visible: :all
    end

    test 'the required-label span reads the fr locale file, per render' do
      I18n.with_locale(:fr) do
        render_bound(FieldModels::Validated.new, :plain)

        assert_selector '[data-slot=field-required-text]', text: 'obligatoire', visible: :all
      end
    end

    test 'a call-site required_label wins over the locale file' do
      render_bound(FieldModels::Validated.new, :plain, required_label: 'needed')

      assert_selector '[data-slot=field-required-text]', text: 'needed', visible: :all
    end
  end
end
