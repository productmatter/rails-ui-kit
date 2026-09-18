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

    test 'required renders aria-required on the control in both modes, and omits it when not required' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, required: true))
      assert_selector 'select[required]', visible: :all
      assert_selector "#post_state-combobox[aria-required='true']", visible: :all

      # ARIA has no aria-required for `button`, so search mode's goes on the combobox it does
      # allow it on: the search field, which is where the user is while choosing.
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, search: true, required: true))
      assert_selector "input#post_state-search[aria-required='true']", visible: :all
      assert_no_selector '#post_state-trigger[aria-required]', visible: :all

      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES))
      assert_no_selector '[aria-required]', visible: :all

      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, search: true))
      assert_no_selector '[aria-required]', visible: :all
    end

    test 'other data and aria attributes stay on the root, where change events bubble to' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES,
                                            data: { testid: 'state' }, aria: { roledescription: 'state picker' }))

      assert_selector "[data-slot='select'][data-testid='state'][aria-roledescription='state picker']", visible: :all
      assert_no_selector 'select[data-testid]', visible: :all
    end

    test "a caller's data-controller and data-action join the root's own wiring rather than replacing it" do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES,
                                            data: { controller: 'autosave', action: 'change->form#save' }))

      root = page.find("[data-slot='select']", visible: :all)
      assert_equal %w[ui--select ui--overlay ui--anchor ui--roving-focus autosave], root['data-controller'].split
      actions = root['data-action'].split
      assert_equal 'change->form#save', actions.last
      assert_includes actions, 'change->ui--select#render'
      assert_includes actions, 'ui--overlay:opened->ui--select#opened'
      assert_includes actions, 'ui--overlay:closed->ui--select#closed'
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
      assert_no_selector 'input', visible: :all
      assert_no_selector 'button', visible: :all
      assert_no_selector '[role=status]', visible: :all
      assert_no_selector '#post_state-trigger', visible: :all
      assert_no_selector '#post_state-search', visible: :all
    end

    test 'search mode renders a trigger button that never submits, and no combobox of its own' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, search: true))

      trigger = page.find('#post_state-trigger', visible: :all)
      assert_equal 'button', trigger.tag_name
      assert_equal 'button', trigger['type'], 'a trigger with no type would submit the form around it'
      assert_equal 'listbox', trigger['aria-haspopup']
      assert_equal 'post_state-listbox', trigger['aria-controls']
      assert_equal 'false', trigger['aria-expanded']
      assert_nil trigger['role'], 'the trigger is not the combobox: the field in the popup is'
      assert_nil trigger['aria-activedescendant']
      assert_no_selector '#post_state-combobox', visible: :all
      assert_selector "select[name='post[state]']", visible: :all
    end

    test 'search mode puts one search field first in the popup, and it never submits' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, search: true))

      field = page.find('#post_state-search', visible: :all)
      assert_equal 'input', field.tag_name
      assert_equal 'text', field['type']
      assert_equal 'combobox', field['role']
      assert_equal 'list', field['aria-autocomplete']
      assert_equal 'off', field['autocomplete']
      assert_equal 'post_state-listbox', field['aria-controls']
      assert_equal 'false', field['aria-expanded'], 'the role requires it, and a closed list is closed'
      assert_equal I18n.t('rails_ui_kit.select.search_placeholder'), field['placeholder']
      assert_nil field['name'], 'the search field would submit a second value'

      assert_equal 1, page.all('[role=combobox]', visible: :all).size,
                   'a widget with two comboboxes tells a screen reader there are two controls'
      # First in the popup, above the list it filters, with a rule under the row.
      inside = page.find('#post_state-popup', visible: :all)
      ids = inside.all('input, [role=listbox]', visible: :all).map { |element| element['id'] }
      assert_equal %w[post_state-search post_state-listbox], ids
      assert_selector '#post_state-popup .border-b.border-border input#post_state-search', visible: :all
    end

    test 'the trigger and the search field both carry the name the caller gave the control' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, search: true,
                                            aria: { label: 'State' }))

      assert_selector "#post_state-trigger[aria-label='State']", visible: :all
      assert_selector "#post_state-search[aria-label='State']", visible: :all
    end

    test 'search mode renders the empty state and the polite status region, both from i18n' do
      I18n.with_locale(:fr) do
        render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, search: true))

        assert_selector '#post_state-empty[hidden]', text: I18n.t('rails_ui_kit.select.no_results'), visible: :all
        assert_selector "#post_state-status[role=status][aria-live='polite']", visible: :all
        assert_selector "#post_state-search[placeholder='#{I18n.t('rails_ui_kit.select.search_placeholder')}']",
                        visible: :all
        # The whole plural map, and the locale that produced it: the count is only known in the
        # browser, and so is the category it falls in (ui-localization § Behavior, items 6 and 7).
        root = page.find("[data-slot='select']", visible: :all)
        assert_equal I18n.t('rails_ui_kit.select.results').symbolize_keys.to_json,
                     root['data-ui--select-results-value']
        assert_equal 'fr', root['data-ui--select-locale-value']
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

    # The clear button (ui-select § Behavior, item 10). It exists only where the native select
    # holds the prompt option Rails rendered: without one a single select cannot be emptied, since
    # deselecting everything makes the browser select the first option instead.

    def clear_button(**)
      render_inline(Ui::SelectComponent.new(clear_label: 'Clear', **))
      page.first("[data-ui--select-target='clear']", minimum: 0, visible: :all)
    end

    test 'a prompt renders a clear button; a value, a blank on its own and no placeholder render none' do
      assert_not_nil clear_button(name: 'post[state]', options: STATES, prompt: true)
      assert_not_nil clear_button(name: 'post[state]', options: STATES, prompt: 'Pick one', search: true)

      assert_nil clear_button(name: 'post[state]', options: STATES, prompt: true, selected: 'draft'),
                 'a page Rails rendered with a value has no prompt option to return to'
      assert_nil clear_button(name: 'post[state]', options: STATES, include_blank: 'None'),
                 'a blank is a listed choice, not a placeholder the control returns to'
      assert_nil clear_button(name: 'post[state]', options: STATES)
      assert_nil clear_button(name: 'post[state]', options: STATES, required: true),
                 "required's implicit blank is a blank, not a prompt"
    end

    test 'it is a hidden button of its own, a sibling of the control and before the chevron' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, prompt: true,
                                            clear_label: 'Clear'))

      button = page.find('#post_state-clear', visible: :all)
      assert_equal 'button', button.tag_name
      assert_equal 'button', button['type'], 'a button with no type would submit the form around it'
      assert button.matches_css?('[hidden]'), 'it is revealed by ui--select, like the control it sits beside'
      assert_equal 'click->ui--select#clear', button['data-action']

      # A sibling: interactive content inside a role="combobox" or a <button> is invalid markup.
      assert_selector "[data-slot='select'] > #post_state-clear", visible: :all
      assert_no_selector '#post_state-combobox #post_state-clear', visible: :all
      # After the control, so it is after it in the tab order, and before the chevron.
      ids = page.all("[data-slot='select'] > *", visible: :all).map { |element| element['id'] }
      assert_equal %w[post_state post_state-combobox post_state-clear], ids.first(3)
    end

    test 'its name is its own word and then the field name; the word comes from the call site or i18n' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, prompt: true,
                                            clear_label: 'Empty it'))
      assert_selector '#post_state-clear #post_state-clear-label.sr-only', text: 'Empty it', visible: :all
      assert_selector "#post_state-clear svg[aria-hidden='true']", visible: :all

      # ui--select puts the field's name after that word, from the label element the control is
      # named by -- so the markup carries the word alone and no half-written name.
      assert_nil page.find('#post_state-clear', visible: :all)['aria-labelledby']

      render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, prompt: true))
      assert_selector '#post_state-clear-label', text: I18n.t('rails_ui_kit.select.clear_label'), visible: :all
    end

    test 'it is a fixed 24px target whatever the control size, and the control makes room for it' do
      Ui::Select::Box::SIZES.each_key do |size|
        classes = clear_button(name: 'post[state]', options: STATES, prompt: true, size: size)['class'].split

        assert_includes classes, 'size-6', "size: #{size} moved the target off 24px (WCAG 2.5.8)"
        assert_includes classes, 'focus-visible:outline-2'
        assert_includes classes, 'focus-visible:outline-ring'
        assert_none_matches(/shadow/, classes, 'the focus ring is a flush outline, never a box-shadow')
        assert_none_matches(/^border(-|$)/, classes, 'it has no border, so its outline draws flush')
      end

      # The room is taken only while the button is showing, which is what ui--select marks.
      with_prompt = clear_control_classes(name: 'post[state]', options: STATES, prompt: true)
      assert_includes with_prompt, 'group-data-[clearable=true]/select:pe-14'
      assert_not_includes clear_control_classes(name: 'post[state]', options: STATES),
                          'group-data-[clearable=true]/select:pe-14'
    end

    test 'it hides with the same media query that hides the control it sits in' do
      touch = clear_button(name: 'post[state]', options: STATES, prompt: true)['class'].split
      assert_includes touch, 'pointer-coarse:hidden',
                      'the platform picker lists the prompt itself, so the button has nothing to add there'

      enhanced = clear_button(name: 'post[state]', options: STATES, prompt: true, native_on_touch: false)
      assert_not_includes enhanced['class'].split, 'pointer-coarse:hidden'
      # Search mode always enhances, so its button is never the one the platform picker replaces.
      searching = clear_button(name: 'post[state]', options: STATES, prompt: true, search: true)
      assert_not_includes searching['class'].split, 'pointer-coarse:hidden'
    end

    def clear_control_classes(**)
      render_inline(Ui::SelectComponent.new(clear_label: 'Clear', **))
      page.find('#post_state-combobox', visible: :all)['class'].split
    end

    def assert_none_matches(pattern, classes, message)
      assert_empty classes.grep(pattern), message
    end

    test 'exactly one option source is required' do
      assert_raises(ArgumentError) { Ui::SelectComponent.new(name: 'a') }
      assert_raises(ArgumentError) { Ui::SelectComponent.new(name: 'a', options: STATES, enum: :status, model: TestOrder) }
      assert_raises(ArgumentError) { Ui::SelectComponent.new(name: 'a', enum: :status) }
      assert_raises(ArgumentError) { Ui::SelectComponent.new(name: 'a', collection: authors, value_method: :id) }
    end
  end
end
