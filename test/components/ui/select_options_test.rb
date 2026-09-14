# frozen_string_literal: true

require 'test_helper'
require 'support/test_order'

module Ui
  # The two renderings of one option model, held equal: what the native <select> holds is
  # what the listbox offers, for every option source (ui-select § Behavior, item 11). The
  # sequence compared is value, text, disabled, selected and group, in DOM order, because a
  # listbox that disagrees with the select on any of them offers a choice that can't submit.
  class SelectOptionsTest < ViewComponent::TestCase
    Author = Struct.new(:id, :name)
    Continent = Struct.new(:name, :countries)
    Country = Struct.new(:id, :name)

    SOURCES = {
      'an array of pairs' => { options: [%w[Draft draft], %w[Published published]] },
      'an array of strings' => { options: %w[S M L] },
      'a text => value hash' => { options: { 'Draft' => 'draft', 'Published' => 'published' } },
      'a grouped hash' => { options: { 'Europe' => [%w[France fr]], 'Asia' => [%w[Japan jp]] } },
      'an enum' => { model: TestOrder, enum: :status }
    }.freeze

    def authors
      [Author.new(1, 'Ada'), Author.new(2, 'Grace'), Author.new(3, 'Linus')]
    end

    def continents
      [Continent.new('Europe', [Country.new('fr', 'France')]), Continent.new('Asia', [Country.new('jp', 'Japan')])]
    end

    def collection_source
      { collection: authors, value_method: :id, text_method: :name }
    end

    def grouped_collection_source
      { collection: continents, group_method: :countries, group_label_method: :name,
        value_method: :id, text_method: :name }
    end

    # What the browser would report about the native select's options.
    def native_sequence(**source)
      render_inline(Ui::SelectComponent.new(name: 'record[field]', **source))
      page.all('option', visible: :all).map { |option| native_entry(option) }
    end

    def native_entry(option)
      parent = option.native.parent
      { value: option['value'].to_s, text: option.text.to_s, disabled: option.native['disabled'].present?,
        selected: option.native['selected'].present?,
        group: (parent['label'] if parent.name == 'optgroup') }
    end

    def listbox_sequence(**source)
      render_inline(Ui::Select::ListboxComponent.new(id: 'record_field', **source))
      page.all('[role=option]', visible: :all).map { |option| listbox_entry(option) }
    end

    def listbox_entry(option)
      parent = option.native.parent
      { value: option['data-value'].to_s, text: option.text.strip,
        disabled: option['aria-disabled'] == 'true', selected: option['data-selected'] == 'true',
        group: (parent.at('[id]').text if parent['role'] == 'group') }
    end

    def assert_same_sequence(**source)
      native = native_sequence(**source)
      assert_predicate native, :any?, 'the select rendered no options, so there is nothing to hold equal'
      assert_equal native, listbox_sequence(**source)
    end

    SOURCES.each do |name, source|
      test "the listbox and the select hold the same options for #{name}" do
        assert_same_sequence(**source)
      end
    end

    test 'the listbox and the select hold the same options for a collection' do
      assert_same_sequence(**collection_source)
    end

    test 'the listbox and the select agree when value_method and text_method are procs' do
      assert_same_sequence(collection: authors, value_method: :id.to_proc,
                           text_method: ->(author) { author.name.upcase })
    end

    test 'the listbox and the select hold the same options for a grouped collection' do
      assert_same_sequence(**grouped_collection_source)
    end

    test 'the two agree on the selected option, the disabled ones, the blank and the prompt' do
      assert_same_sequence(**collection_source, selected: 2, disabled_values: [3], include_blank: 'No author')
      assert_same_sequence(**collection_source, prompt: true)
      assert_same_sequence(**collection_source, required: true)
    end

    test 'the listbox marks the current value with data-selected and nothing with aria-selected' do
      render_inline(Ui::Select::ListboxComponent.new(id: 'record_field', **collection_source, selected: 2))

      assert_selector "[role=option][data-value='2'][data-selected='true']", count: 1, visible: :all
      assert_selector '[role=option]', count: 3, visible: :all
      assert_equal(%w[false false false], page.all('[role=option]', visible: :all).map { |o| o['aria-selected'] })
    end

    test 'a disabled option is announced disabled rather than removed from the list' do
      render_inline(Ui::Select::ListboxComponent.new(id: 'record_field', **collection_source, disabled_values: [3]))

      assert_selector "[role=option][data-value='3'][aria-disabled='true']", visible: :all
      assert_no_selector '[role=option][disabled]', visible: :all
    end

    test 'option ids are derived from the control id, and every option is a roving-focus item' do
      render_inline(Ui::Select::ListboxComponent.new(id: 'post_author_id', **collection_source))

      assert_equal(%w[post_author_id-option-0 post_author_id-option-1 post_author_id-option-2],
                   page.all('[role=option]', visible: :all).map { |option| option['id'] })
      assert_selector "[role=option][data-ui--roving-focus-target='item']", count: 3, visible: :all
      assert_selector '[role=listbox]#post_author_id-listbox', visible: :all
    end

    test 'a group is a role=group labelled by its own label element, with no generic element in between' do
      render_inline(Ui::Select::ListboxComponent.new(id: 'city_country_id', **grouped_collection_source))

      group = page.first('[role=group]', visible: :all)
      assert_equal group['aria-labelledby'], group.first('[id]', visible: :all)['id']
      assert_equal 'Europe', group.first('[id]', visible: :all).text
      assert_selector '[role=listbox] > [role=group] > [role=option]', visible: :all
    end

    test 'an ungrouped listbox puts its options directly inside the listbox' do
      render_inline(Ui::Select::ListboxComponent.new(id: 'post_author_id', **collection_source))

      assert_selector '[role=listbox] > [role=option]', count: 3, visible: :all
      assert_no_selector '[role=group]', visible: :all
    end

    test 'the listbox is named by whatever names the combobox' do
      render_inline(Ui::Select::ListboxComponent.new(id: 'post_author_id', labelledby: 'post_author_id-label',
                                                     **collection_source))

      assert_selector "[role=listbox][aria-labelledby='post_author_id-label']", visible: :all
    end

    test 'enum labels resolve through the model, falling back to the humanised key' do
      assert_equal %w[Pending Shipped Delivered],
                   Ui::OptionSet.new(component: 'Ui::SelectComponent', model: TestOrder, enum: :status).items.map(&:text)

      I18n.with_locale(:fr) do
        assert_equal ['En attente', 'Expédiée', 'Delivered'],
                     Ui::OptionSet.new(component: 'Ui::SelectComponent', model: TestOrder, enum: :status).items.map(&:text)
      end
    end

    test 'an enum submits its key, which is what the enum setter accepts' do
      assert_equal %w[pending shipped delivered],
                   Ui::OptionSet.new(component: 'Ui::SelectComponent', model: TestOrder, enum: :status).items.map(&:value)
    end

    test 'the listbox can be built from an option set the component already normalised' do
      component = Ui::SelectComponent.new(name: 'post[author_id]', **collection_source)
      render_inline(Ui::Select::ListboxComponent.new(id: 'post_author_id', option_set: component.option_set))

      assert_equal(%w[1 2 3], page.all('[role=option]', visible: :all).map { |option| option['data-value'] })
    end
  end
end
