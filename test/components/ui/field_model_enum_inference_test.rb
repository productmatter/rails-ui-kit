# frozen_string_literal: true

require 'test_helper'
require 'support/test_order'

module Ui
  # A model-bound Field's control takes model: a record and a class (item 2, additive): Select
  # and Choices' option source infers model: from enum: alone, and infers enum: itself from the
  # bound attribute when the control names no source at all and the attribute is one of the
  # record class's enums (ui-field-model-binding).
  class FieldModelEnumInferenceTest < ViewComponent::TestCase
    def render_bound(record, attribute, &)
      render_inline(Ui::FieldComponent.new(model: record, attribute: attribute), &)
    end

    def option_values
      page.all('option', visible: :all).map { |option| option['value'] }
    end

    test 'a record given as model: alongside enum: renders, instead of raising NoMethodError' do
      order = TestOrder.new(status: 'shipped')

      render_bound(order, :status) do |field|
        field.with_control(Ui::SelectComponent, model: order, enum: :status)
      end

      assert_equal %w[pending shipped delivered], option_values
      assert_selector 'option[value=shipped][selected]', visible: :all
    end

    test 'enum: with no model: completes from the field\'s record class' do
      order = TestOrder.new(status: 'shipped')

      render_bound(order, :status) do |field|
        field.with_control(Ui::SelectComponent, enum: :status)
      end

      assert_equal %w[pending shipped delivered], option_values
    end

    test 'no source at all infers enum: from the bound attribute, and renders the same options as stating it' do
      order = TestOrder.new(status: 'shipped')

      render_bound(order, :status) { |field| field.with_control(Ui::SelectComponent) }
      inferred = option_values

      render_bound(order, :status) { |field| field.with_control(Ui::SelectComponent, enum: :status) }
      explicit = option_values

      assert_equal explicit, inferred
      assert_equal %w[pending shipped delivered], inferred
    end

    test 'inference renders the same options for Choices as for Select' do
      order = TestOrder.new(status: 'shipped')

      render_bound(order, :status) { |field| field.with_control(Ui::ChoicesComponent) }
      choices_values = page.all('input', visible: :all).map { |input| input['value'] }.reject(&:empty?)

      render_bound(order, :status) { |field| field.with_control(Ui::SelectComponent) }

      assert_equal option_values, choices_values
    end

    test 'a non-enum attribute infers nothing, so a control with no source still raises' do
      order = TestOrder.new(note: 'a plain string')

      error = assert_raises(ArgumentError) do
        render_bound(order, :note) { |field| field.with_control(Ui::SelectComponent) }
      end
      assert_match(/needs exactly one option source/, error.message)
    end

    test 'a caller-stated source is never overridden by inference' do
      order = TestOrder.new(status: 'shipped')

      render_bound(order, :status) do |field|
        field.with_control(Ui::SelectComponent, options: %w[x y])
      end

      assert_equal %w[x y], option_values
    end

    test 'a control outside a model-bound Field is unaffected' do
      assert_raises(ArgumentError) do
        render_inline(Ui::FieldComponent.new(name: 'order[status]')) do |field|
          field.with_control(Ui::SelectComponent)
        end
      end
    end
  end
end
