# frozen_string_literal: true

require 'test_helper'
require 'support/test_order'

module Ui
  # Parity, option for option, with the Rails helpers this component stands in for. The
  # comparison is the rendered <option>/<optgroup> markup, because that is what the browser
  # submits from and what a Rails developer's expectations are actually about.
  class SelectComponentTest < ViewComponent::TestCase
    Author = Struct.new(:id, :name)
    Continent = Struct.new(:name, :countries)
    Country = Struct.new(:id, :name)

    STATES = [%w[Draft draft], %w[Published published]].freeze

    def authors
      [Author.new(1, 'Ada'), Author.new(2, 'Grace'), Author.new(3, 'Linus')]
    end

    def continents
      [Continent.new('Europe', [Country.new('fr', 'France'), Country.new('de', 'Germany')]),
       Continent.new('Asia', [Country.new('jp', 'Japan')])]
    end

    def view
      vc_test_controller.view_context
    end

    # The component's own <select> contents, and the helper's, compared as markup.
    def component_options(**)
      render_inline(Ui::SelectComponent.new(**))
      squish(page.find('select', visible: :all).native.inner_html)
    end

    # Asserted non-empty, so a comparison can never pass by having nothing on either side.
    def helper_options(html)
      options = squish(Capybara.string(html).find('select', visible: :all).native.inner_html)
      assert_includes options, '<option', 'the Rails helper rendered no options to compare against'
      options
    end

    def squish(html)
      html.to_s.gsub(/\s+/, ' ').gsub('> <', '><').strip
    end

    test 'an array of pairs renders what select renders' do
      assert_equal helper_options(view.select(:post, :state, STATES)),
                   component_options(name: 'post[state]', options: STATES)
    end

    test 'an array of strings renders what select renders' do
      assert_equal helper_options(view.select(:shirt, :size, %w[S M L])),
                   component_options(name: 'shirt[size]', options: %w[S M L])
    end

    test 'a text => value hash renders what select renders' do
      choices = { 'Draft' => 'draft', 'Published' => 'published' }

      assert_equal helper_options(view.select(:post, :state, choices)),
                   component_options(name: 'post[state]', options: choices)
    end

    test 'a collection renders what collection_select renders' do
      assert_equal helper_options(view.collection_select(:post, :author_id, authors, :id, :name)),
                   component_options(name: 'post[author_id]', collection: authors, value_method: :id, text_method: :name)
    end

    test 'procs for value_method and text_method behave as they do in Rails' do
      value = :id.to_proc
      text = ->(author) { author.name.upcase }

      assert_equal helper_options(view.collection_select(:post, :author_id, authors, value, text)),
                   component_options(name: 'post[author_id]', collection: authors, value_method: value, text_method: text)
    end

    test 'a grouped collection renders what grouped_collection_select renders' do
      expected = view.grouped_collection_select(:city, :country_id, continents, :countries, :name, :id, :name)

      assert_equal helper_options(expected),
                   component_options(name: 'city[country_id]', collection: continents, group_method: :countries,
                                     group_label_method: :name, value_method: :id, text_method: :name)
    end

    test 'a grouped hash renders what grouped_options_for_select renders' do
      groups = { 'Europe' => [%w[France fr]], 'Asia' => [%w[Japan jp]] }
      expected = view.select(:trip, :country, view.grouped_options_for_select(groups))

      assert_equal helper_options(expected), component_options(name: 'trip[country]', options: groups)
    end

    test 'selected marks the same option Rails marks, comparing by string value' do
      expected = view.collection_select(:post, :author_id, authors, :id, :name, selected: 2)

      assert_equal helper_options(expected),
                   component_options(name: 'post[author_id]', collection: authors, value_method: :id,
                                     text_method: :name, selected: 2)
      render_inline(Ui::SelectComponent.new(name: 'post[author_id]', collection: authors, value_method: :id,
                                            text_method: :name, selected: '2'))
      assert_selector "option[value='2'][selected]", text: 'Grace', visible: :all
      assert_selector 'option[selected]', count: 1, visible: :all
    end

    test 'include_blank true and a string both render what Rails renders' do
      assert_equal helper_options(view.select(:post, :state, STATES, include_blank: true)),
                   component_options(name: 'post[state]', options: STATES, include_blank: true)

      assert_equal helper_options(view.select(:post, :state, STATES, include_blank: 'No state')),
                   component_options(name: 'post[state]', options: STATES, include_blank: 'No state')
    end

    test 'prompt renders only while nothing is selected, as in Rails' do
      assert_equal helper_options(view.select(:post, :state, STATES, prompt: true)),
                   component_options(name: 'post[state]', options: STATES, prompt: true)

      assert_equal helper_options(view.select(:post, :state, STATES, prompt: 'Pick one')),
                   component_options(name: 'post[state]', options: STATES, prompt: 'Pick one')

      assert_equal helper_options(view.select(:post, :state, STATES, prompt: true, selected: 'draft')),
                   component_options(name: 'post[state]', options: STATES, prompt: true, selected: 'draft')
    end

    test 'prompt: true reads Rails own translation key rather than a kit string' do
      I18n.with_locale(:fr) do
        assert_includes component_options(name: 'post[state]', options: STATES, prompt: true),
                        I18n.t('helpers.select.prompt')
      end
    end

    test 'required with no blank and no prompt adds the empty option Rails adds' do
      expected = view.select(:post, :state, STATES, {}, required: true)

      assert_equal helper_options(expected), component_options(name: 'post[state]', options: STATES, required: true)
    end

    test 'required with a prompt keeps the prompt and adds no blank, as in Rails' do
      expected = view.select(:post, :state, STATES, { prompt: true }, required: true)

      assert_equal helper_options(expected),
                   component_options(name: 'post[state]', options: STATES, prompt: true, required: true)
    end

    test 'prompt and include_blank together render in Rails order' do
      expected = view.select(:post, :state, STATES, prompt: 'Pick one', include_blank: 'None')

      assert_equal helper_options(expected),
                   component_options(name: 'post[state]', options: STATES, prompt: 'Pick one', include_blank: 'None')
    end

    test 'disabled_values disables the same options Rails disables' do
      expected = view.collection_select(:post, :author_id, authors, :id, :name, disabled: [3])

      assert_equal helper_options(expected),
                   component_options(name: 'post[author_id]', collection: authors, value_method: :id,
                                     text_method: :name, disabled_values: [3])
    end

    test 'an enum renders its keys as values, labelled through the model, in declaration order' do
      render_inline(Ui::SelectComponent.new(name: 'order[status]', model: TestOrder, enum: :status))

      options = page.all('option', visible: :all)
      assert_equal(%w[pending shipped delivered], options.map { |option| option['value'] })
      assert_equal %w[Pending Shipped Delivered], options.map(&:text)
    end

    test 'the select carries the form-control attributes and derives its id the way form_with does' do
      render_inline(Ui::SelectComponent.new(name: 'post[author_id]', options: STATES, required: true,
                                            disabled: true, form: 'other-form', autofocus: true))

      select = page.find('select', visible: :all)
      assert_equal 'post_author_id', select['id']
      assert_equal 'post[author_id]', select['name']
      assert select.matches_css?('[required][disabled][autofocus]')
      assert_equal 'other-form', select['form']
    end

    test 'a caller id wins over the derived one' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, id: 'state-picker'))

      assert_equal 'state-picker', page.find('select', visible: :all)['id']
    end

    test 'the aria that describes or names the control reaches both renderings of it' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES,
                                            aria: { describedby: 'state-error', invalid: true, label: 'State' }))

      %w[select [role=combobox]].each do |control|
        assert_selector "#{control}[aria-describedby='state-error'][aria-invalid='true'][aria-label='State']",
                        visible: :all
      end
      root = page.find("[data-slot='select']", visible: :all)
      assert_nil root['aria-describedby']
      assert_nil root['aria-invalid']
      assert_nil root['aria-label']
    end

    test 'required renders aria-required on the combobox in both modes, and omits it when not required' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, required: true))
      assert_selector 'select[required]', visible: :all
      assert_selector "[role=combobox][aria-required='true']", visible: :all

      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, search: true, required: true))
      assert_selector "input[role=combobox][aria-required='true']", visible: :all

      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES))
      assert_no_selector '[role=combobox][aria-required]', visible: :all

      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, search: true))
      assert_no_selector '[role=combobox][aria-required]', visible: :all
    end

    test 'other data and aria attributes stay on the root, where change events bubble to' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES,
                                            data: { testid: 'state' }, aria: { roledescription: 'state picker' }))

      assert_selector "[data-slot='select'][data-testid='state'][aria-roledescription='state picker']", visible: :all
      assert_no_selector 'select[data-testid]', visible: :all
    end

    test "the caller's class merges onto the control, not the wrapper" do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, class: 'h-12'))

      classes = page.find('select', visible: :all)['class'].split
      assert_includes classes, 'h-12'
      assert_not_includes classes, 'h-(--control-height)'
      assert_not_includes page.find("[data-slot='select']", visible: :all)['class'].split, 'h-12'
    end

    test 'the control keeps the kit form-control tokens and a decorative chevron' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES))

      classes = page.find('select', visible: :all)['class'].split
      assert_includes classes, 'border-input'
      assert_includes classes, 'dark:bg-muted/50'
      assert_selector "[data-slot='select'] svg[aria-hidden='true']", visible: :all
    end

    test 'select-only mode renders a div combobox, and no search-only parts' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES))

      assert_selector "div#post_state-combobox[role=combobox][tabindex='0']", visible: :all
      assert_no_selector 'input[role=combobox]', visible: :all
      assert_no_selector 'button', visible: :all
      assert_no_selector '[role=status]', visible: :all
    end

    test 'search mode renders a text field that never submits, plus the APG show-options button' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, search: true))

      combobox = page.find('#post_state-combobox', visible: :all)
      assert_equal 'input', combobox.tag_name
      assert_equal 'text', combobox['type']
      assert_equal 'list', combobox['aria-autocomplete']
      assert_equal 'off', combobox['autocomplete']
      assert_nil combobox['name'], 'the text field would submit a second value'
      assert_selector "button[type=button][tabindex='-1'][aria-label]", visible: :all
      assert_selector "select[name='post[state]']", visible: :all
    end

    test 'search mode renders the empty state and the polite status region, both from i18n' do
      I18n.with_locale(:fr) do
        render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, search: true))

        assert_selector '#post_state-empty[hidden]', text: I18n.t('rails_ui_kit.select.no_results'), visible: :all
        assert_selector "#post_state-status[role=status][aria-live='polite']", visible: :all
        assert_selector "button[aria-label='#{I18n.t('rails_ui_kit.select.show_options')}']", visible: :all
        root = page.find("[data-slot='select']", visible: :all)
        assert_equal I18n.t('rails_ui_kit.select.results.one'), root['data-ui--select-results-one-value']
        assert_equal I18n.t('rails_ui_kit.select.results.other'), root['data-ui--select-results-other-value']
      end
    end

    test 'each mode hands ui--roving-focus the values its APG example calls for' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES))
      select_only = page.find("[data-slot='select']", visible: :all)
      assert_equal 'false', select_only['data-ui--roving-focus-loop-value']
      assert_equal 'true', select_only['data-ui--roving-focus-typeahead-value']
      assert_equal '10', select_only['data-ui--roving-focus-page-step-value']

      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, search: true))
      searching = page.find("[data-slot='select']", visible: :all)
      assert_equal 'true', searching['data-ui--roving-focus-loop-value']
      assert_equal 'false', searching['data-ui--roving-focus-typeahead-value']
      assert_equal '0', searching['data-ui--roving-focus-page-step-value']
    end

    test 'exactly one option source is required' do
      assert_raises(ArgumentError) { Ui::SelectComponent.new(name: 'a') }
      assert_raises(ArgumentError) { Ui::SelectComponent.new(name: 'a', options: STATES, enum: :status, model: TestOrder) }
      assert_raises(ArgumentError) { Ui::SelectComponent.new(name: 'a', enum: :status) }
      assert_raises(ArgumentError) { Ui::SelectComponent.new(name: 'a', collection: authors, value_method: :id) }
    end
  end
end
