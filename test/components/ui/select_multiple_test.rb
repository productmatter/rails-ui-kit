# frozen_string_literal: true

require 'test_helper'

module Ui
  # `multiple: true`: what posts, measured against Rails' own `select(..., multiple: true)`, and
  # what the listbox and the root tell ui--select. A single Select's markup is pinned unchanged by
  # SelectComponentTest; the last test here checks it renders none of this.
  class SelectMultipleTest < ViewComponent::TestCase
    TAGS = [%w[Cyber cyber], %w[Property property], %w[Liability liability]].freeze

    def view
      vc_test_controller.view_context
    end

    def render_multiple(**)
      render_inline(Ui::SelectComponent.new(name: 'post[tags]', options: TAGS, multiple: true, **))
    end

    test 'the select and its hidden field are what Rails renders for a multiple select' do
      render_multiple(selected: %w[cyber liability])
      rails = Capybara.string(view.select(:post, :tags, TAGS, { selected: %w[cyber liability] }, multiple: true))

      hidden = page.find("input[type='hidden']", visible: :all)
      rails_hidden = rails.find("input[type='hidden']", visible: :all)
      attributes = %w[name value autocomplete]
      assert_equal(attributes.map { |attribute| rails_hidden[attribute] }, attributes.map { |attribute| hidden[attribute] })

      select = page.find('select', visible: :all)
      rails_select = rails.find('select', visible: :all)
      %w[name id multiple].each { |attribute| assert_equal rails_select[attribute], select[attribute], attribute }
      assert_equal rails_select.all('option[selected]', visible: :all).map(&:value),
                   select.all('option[selected]', visible: :all).map(&:value)
    end

    test 'the hidden field comes before the select, so a chosen value is the later one' do
      render_multiple

      names = page.all('[name]', visible: :all).map(&:tag_name)
      assert_equal %w[input select], names
    end

    test 'a name that already ends in [] is left alone, and the id is derived without it' do
      render_inline(Ui::SelectComponent.new(name: 'post[tags][]', options: TAGS, multiple: true))

      assert_equal 'post[tags][]', page.find('select', visible: :all)[:name]
      assert_equal 'post_tags_', page.find('select', visible: :all)[:id]
    end

    test 'include_hidden: false renders no hidden field' do
      render_multiple(include_hidden: false)

      assert_no_selector "input[type='hidden']", visible: :all
    end

    test 'a disabled multiple select disables its hidden field too, so it posts nothing' do
      render_multiple(disabled: true)

      assert page.find("input[type='hidden']", visible: :all).disabled?
    end

    test 'a required multiple select gets no blank option, as Rails gives it none' do
      render_multiple(required: true)

      assert_equal TAGS.map(&:last), page.all('option', visible: :all).map(&:value)
      assert page.find('select', visible: :all)[:required]
    end

    test 'the listbox is multiselectable, and aria-selected starts as each option\'s chosen state' do
      render_multiple(selected: %w[property])

      assert_selector "[role='listbox'][aria-multiselectable='true']", visible: :all
      states = page.all("[role='option']", visible: :all).map { |option| option['aria-selected'] }
      assert_equal %w[false true false], states
      assert_selector "[role='option'][data-selected='true'][data-value='property']", visible: :all
    end

    test 'the root tells ui--select it is multiple, and what to show while nothing is chosen' do
      render_multiple(empty_label: 'Any commercial round')

      root = page.find("[data-slot='select']")
      assert_equal 'true', root['data-ui--select-multiple-value']
      assert_equal 'Any commercial round', root['data-ui--select-empty-label-value']
    end

    test 'search mode takes multiple too' do
      render_multiple(search: true)

      assert_selector "[role='listbox'][aria-multiselectable='true']", visible: :all
      assert_selector "input[role='combobox']", visible: :all
    end

    test 'prompt: and include_blank: are refused, and say what to use instead' do
      %i[prompt include_blank].each do |key|
        error = assert_raises(ArgumentError) { render_multiple(key => 'Any') }
        assert_includes error.message, "#{key}:"
        assert_includes error.message, 'empty_label:'
      end
    end

    test 'native: true is refused with multiple: true' do
      error = assert_raises(ArgumentError) { render_multiple(native: true) }
      assert_includes error.message, 'native: true'
    end

    test 'a single Select renders none of it' do
      render_inline(Ui::SelectComponent.new(name: 'post[tag]', options: TAGS, selected: 'cyber'))

      assert_no_selector "input[type='hidden']", visible: :all
      assert_nil page.find('select', visible: :all)[:multiple]
      assert_equal 'post[tag]', page.find('select', visible: :all)[:name]
      assert_no_selector '[aria-multiselectable]', visible: :all
      assert_nil page.find("[data-slot='select']")['data-ui--select-multiple-value']
      assert_equal(%w[false false false], page.all("[role='option']", visible: :all).map { |option| option['aria-selected'] })
    end
  end
end
