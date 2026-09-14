# frozen_string_literal: true

require 'test_helper'
require 'support/test_order'

module Ui
  # What Choices renders, held against what Rails renders for the same arguments
  # (ui-choices § Behavior, items 1–5 and § Business rules, rule 3). The comparison is the
  # submitting surface only -- type, name, value, id, checked, disabled, form and the hidden
  # field -- because the markup around each input is deliberately the kit's, not Rails'.
  class ChoicesComponentTest < ViewComponent::TestCase
    Role = Struct.new(:id, :name, :tagline)

    def roles
      [Role.new(1, 'Admin', 'Everything'), Role.new(2, 'Editor', 'Writes posts')]
    end

    def collection_source
      { collection: roles, value_method: :id, text_method: :name }
    end

    def render_choices(**attributes)
      render_inline(Ui::ChoicesComponent.new(**attributes))
    end

    # Rails itself, from a real view context: the helper the component mirrors, called with the
    # arguments a Rails developer would have written.
    def rails_entries(helper, arguments, options = {})
      markup = ApplicationController.new.view_context.public_send(helper, *arguments, options)
      entries(Nokogiri::HTML5.fragment(markup))
    end

    def entries(fragment)
      fragment.css('input').map do |input|
        %w[type name value id checked disabled form].to_h { |key| [key, input[key]] }
      end
    end

    def rendered_entries
      entries(page.native)
    end

    def entry_types
      rendered_entries.map { |entry| entry['type'] }
    end

    def hidden_values
      rendered_entries.select { |entry| entry['type'] == 'hidden' }.map { |entry| entry['value'] }
    end

    test 'CH1 a checkbox group renders the inputs and hidden field collection_check_boxes renders' do
      render_choices(name: 'user[role_ids]', multiple: true, checked: [1], disabled_values: [2], **collection_source)

      without_carriers = rendered_entries.reject { |entry| entry['type'] == 'hidden' && entry['value'].present? }

      assert_equal rails_entries(:collection_check_boxes, [:user, :role_ids, roles, :id, :name],
                                 { checked: [1], disabled: [2] }),
                   without_carriers
    end

    test 'CH2 a radio group renders the inputs and hidden field collection_radio_buttons renders' do
      render_choices(name: 'account[plan]', options: [%w[Pro pro], %w[Free free]], checked: 'pro')

      assert_equal rails_entries(:collection_radio_buttons,
                                 [:account, :plan, [%w[pro Pro], %w[free Free]], :first, :last],
                                 { checked: 'pro' }),
                   rendered_entries
    end

    test 'CH3 include_hidden: false omits the blank entry, as in Rails' do
      render_choices(name: 'user[role_ids]', multiple: true, include_hidden: false, **collection_source)

      assert_equal rails_entries(:collection_check_boxes, [:user, :role_ids, roles, :id, :name],
                                 { include_hidden: false }),
                   rendered_entries
      assert_no_selector 'input[type=hidden]', visible: :all
    end

    test 'CH4 multiple: true appends [] exactly once, and leaves a name that already has it alone' do
      render_choices(name: 'user[role_ids]', multiple: true, **collection_source)
      assert_equal ['user[role_ids][]'], rendered_entries.map { |entry| entry['name'] }.uniq

      render_choices(name: 'user[role_ids][]', multiple: true, **collection_source)
      assert_equal ['user[role_ids][]'], rendered_entries.map { |entry| entry['name'] }.uniq

      render_choices(name: 'account[plan]', options: %w[pro free])
      assert_equal ['account[plan]'], rendered_entries.map { |entry| entry['name'] }.uniq
    end

    test 'CH5 ids follow ActionView sanitized_value, and the group id is Rails own' do
      render_choices(name: 'shirt[size]', options: ['Extra Large', 'v1.0', 'a/b'])

      assert_selector 'fieldset#shirt_size', visible: :all
      ids = rendered_entries.filter_map { |entry| entry['id'] }

      assert_equal %w[shirt_size_extra_large shirt_size_v1_0 shirt_size_ab], ids
    end

    test 'CH6 an enum labels through the model and submits the key' do
      render_choices(name: 'order[status]', model: TestOrder, enum: :status, checked: 'shipped')

      values = rendered_entries.reject { |entry| entry['type'] == 'hidden' }.map { |entry| entry['value'] }
      assert_equal %w[pending shipped delivered], values
      assert_selector 'span', text: 'Pending'
      assert_selector "input[value='shipped'][checked]", visible: :all
    end

    test 'CH7 form: reaches every input and the hidden field, as in Rails' do
      render_choices(name: 'user[role_ids]', multiple: true, form: 'outside', **collection_source)

      assert_equal ['outside'], rendered_entries.map { |entry| entry['form'] }.uniq
    end

    test 'CH8 a source Choices cannot render raises, naming the component the caller wrote' do
      refused = { include_blank: true, prompt: 'Pick one', group_method: :countries, group_label_method: :name }
      refused.each do |key, value|
        error = assert_raises(ArgumentError) { render_choices(name: 'a[b]', options: %w[x], key => value) }
        assert_match(/\AUi::ChoicesComponent has no #{key}:/, error.message)
      end

      grouped = assert_raises(ArgumentError) do
        render_choices(name: 'a[b]', options: { 'Europe' => [%w[France fr]] })
      end
      assert_match(/has no group_method:/, grouped.message)

      no_object = assert_raises(ArgumentError) do
        render_choices(name: 'a[b]', options: %w[x], description_method: :tagline)
      end
      assert_match(/description_method: and icon_method: need collection:/, no_object.message)

      source = assert_raises(ArgumentError) { render_choices(name: 'a[b]') }
      assert_match(/\AUi::ChoicesComponent needs exactly one option source/, source.message)
    end

    test 'CH9 a checked, locked value is carried by exactly one hidden input, before every input' do
      render_choices(name: 'user[role_ids]', multiple: true, checked: [1, 2], disabled_values: [2],
                     **collection_source)

      carriers = rendered_entries.select { |entry| entry['type'] == 'hidden' && entry['value'].present? }
      assert_equal [{ 'type' => 'hidden', 'name' => 'user[role_ids][]', 'value' => '2', 'id' => nil,
                      'checked' => nil, 'disabled' => nil, 'form' => nil }], carriers
      assert_equal %w[hidden hidden checkbox checkbox], entry_types
    end

    test 'CH10 an unchecked locked value is carried by nothing, and a radio carrier comes first' do
      render_choices(name: 'user[role_ids]', multiple: true, disabled_values: [2], **collection_source)
      assert_equal [''], hidden_values

      render_choices(name: 'account[plan]', options: %w[pro free], checked: 'pro', disabled_values: %w[pro])
      assert_equal %w[hidden hidden radio radio], entry_types
      assert_equal ['', 'pro'], hidden_values
    end

    test 'CH11 a required checkbox group marks no checkbox, and says what the marker means' do
      render_choices(name: 'user[role_ids]', multiple: true, required: true, **collection_source)

      assert_no_selector 'input[required]', visible: :all
      assert_selector "fieldset[data-required='true'][data-controller='ui--choices']", visible: :all
      assert_selector 'fieldset[aria-describedby="user_role_ids-required"]', visible: :all
      assert_selector 'span#user_role_ids-required.sr-only', text: 'Select at least one option.', visible: :all
      assert_selector "input[type=checkbox][data-ui--choices-target='checkbox']", count: 2, visible: :all
    end

    test 'CH12 a required radio group is required on every radio, with no controller and no hint' do
      render_choices(name: 'account[plan]', options: %w[pro free], required: true)

      assert_selector 'input[type=radio][required]', count: 2, visible: :all
      assert_no_selector '[data-controller]', visible: :all
      assert_no_selector '.sr-only', visible: :all
      assert_selector 'fieldset[role=radiogroup]:not([aria-describedby])', visible: :all
    end

    test 'CH13 required_message: overrides the string for this instance only' do
      render_choices(name: 'user[role_ids]', multiple: true, required: true,
                     required_message: 'Choose a role.', **collection_source)
      assert_selector 'span#user_role_ids-required', text: 'Choose a role.', visible: :all

      I18n.with_locale(:fr) do
        render_choices(name: 'user[role_ids]', multiple: true, required: true, **collection_source)
        assert_selector 'span#user_role_ids-required', text: 'Sélectionnez au moins une option.', visible: :all
      end
    end

    test 'CH14 disabled: true disables the fieldset, which is what disables the hidden fields' do
      render_choices(name: 'user[role_ids]', multiple: true, disabled: true, checked: [1],
                     **collection_source)

      assert_selector 'fieldset[disabled]', visible: :all
      # The deviation from the collection helpers, whose hidden field stays enabled and wipes the
      # association on save: nothing carries `disabled` itself, and every input -- the blank entry
      # included -- is inside the one fieldset that disables them all. What that means for a real
      # submission is measured in the browser (choices_submission_test.rb).
      assert_no_selector 'input[disabled]', visible: :all
      assert_equal page.all('input', visible: :all).size,
                   page.all('fieldset[disabled] input', visible: :all).size
    end

    test 'CH15 each input is named by its own text and described by its own description line' do
      render_choices(name: 'user[role_ids]', multiple: true, description_method: :tagline,
                     icon_method: ->(role) { "<svg data-role='#{role.id}'></svg>".html_safe }, **collection_source)

      assert_selector "input#user_role_ids_1[aria-labelledby='user_role_ids_1-label']" \
                      "[aria-describedby='user_role_ids_1-description']", visible: :all
      assert_selector 'span#user_role_ids_1-label', text: 'Admin', visible: :all
      assert_selector 'span#user_role_ids_1-description', text: 'Everything', visible: :all
      assert_selector "[aria-hidden='true'] svg[data-role='1']", visible: :all
    end

    test 'CH16 the group is a fieldset, named by the field label id and role radiogroup for radios' do
      render_choices(name: 'account[plan]', options: %w[pro free])
      assert_selector "fieldset[role=radiogroup][aria-labelledby='account_plan-label']", visible: :all

      render_choices(name: 'user[role_ids]', multiple: true, **collection_source)
      assert_selector "fieldset:not([role])[aria-labelledby='user_role_ids-label']", visible: :all

      render_choices(name: 'account[plan]', options: %w[pro free], aria: { label: 'Plan' })
      assert_selector "fieldset[aria-label='Plan']:not([aria-labelledby])", visible: :all
    end

    test 'CH17 the caller class merges onto the group, and an unknown size or appearance raises' do
      render_choices(name: 'a[b]', options: %w[x], class: 'sm:grid-cols-3')
      assert_selector 'fieldset.sm\\:grid-cols-3', visible: :all

      assert_raises(Ui::Base::UnknownVariantError) { render_choices(name: 'a[b]', options: %w[x], size: :huge) }
      assert_raises(Ui::Base::UnknownVariantError) { render_choices(name: 'a[b]', options: %w[x], appearance: :grid) }
    end
  end
end
