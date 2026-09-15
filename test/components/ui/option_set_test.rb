# frozen_string_literal: true

require 'test_helper'
require 'support/test_order'

module Ui
  # The option model itself, now that more than one component reads it (ui-choices § Behavior,
  # item 3). What Select renders from it stays in select_options_test.rb; what belongs to every
  # component that shares it is here: where the class lives, whose name an ArgumentError carries,
  # and the source element each item came from.
  class OptionSetTest < ActiveSupport::TestCase
    Author = Struct.new(:id, :name)

    def authors
      [Author.new(1, 'Ada'), Author.new(2, 'Grace')]
    end

    def option_set(component: 'Ui::SelectComponent', **source)
      Ui::OptionSet.new(component: component, **source)
    end

    test 'the option model is Ui::OptionSet, and nothing is left under Ui::Select' do
      assert_kind_of Ui::OptionSet, option_set(options: %w[S M L])
      assert_not defined?(Ui::Select::OptionSet), 'Ui::Select::OptionSet still resolves'
    end

    test 'an ArgumentError names the component the caller wrote, not whichever one shares the model' do
      %w[Ui::SelectComponent Ui::ChoicesComponent].each do |component|
        missing = assert_raises(ArgumentError) { option_set(component: component) }
        assert_match(/\A#{Regexp.escape(component)} needs exactly one option source/, missing.message)

        two = assert_raises(ArgumentError) { option_set(component: component, options: %w[S], enum: :status) }
        assert_match(/\A#{Regexp.escape(component)} needs exactly one option source/, two.message)

        no_model = assert_raises(ArgumentError) { option_set(component: component, enum: :status) }
        assert_equal "#{component}: enum: needs model:", no_model.message

        no_methods = assert_raises(ArgumentError) { option_set(component: component, collection: authors) }
        assert_equal "#{component}: collection: needs value_method: and text_method:", no_methods.message
      end
    end

    test 'each item carries the collection element it came from' do
      items = option_set(collection: authors, value_method: :id, text_method: :name).items

      assert_equal authors, items.map(&:object)
      assert_equal %w[Ada Grace], items.map(&:text)
    end

    test 'model: takes a record as well as a class, coerced to the class that answers the enum mapping' do
      by_class = option_set(model: TestOrder, enum: :status).items
      by_record = option_set(model: TestOrder.new, enum: :status).items

      assert_equal by_class.map(&:value), by_record.map(&:value)
    end

    test 'a grouped collection carries the element, not the group' do
      continent = Struct.new(:name, :countries)
      country = Struct.new(:id, :name)
      france = country.new('fr', 'France')
      collection = [continent.new('Europe', [france])]

      items = option_set(collection: collection, group_method: :countries, group_label_method: :name,
                         value_method: :id, text_method: :name).items

      assert_equal [france], items.map(&:object)
      assert_equal ['Europe'], items.map(&:group)
    end

    test 'the sources with no object to call a method on carry none' do
      sources = [{ options: %w[S M L] }, { options: { 'Draft' => 'draft' } },
                 { model: TestOrder, enum: :status },
                 { options: %w[S M], include_blank: true, prompt: 'Pick one' }]

      sources.each do |source|
        items = option_set(**source).items

        assert_predicate items, :any?
        assert_equal [nil], items.map(&:object).uniq, "#{source.keys.inspect} carried an object"
      end
    end
  end
end
