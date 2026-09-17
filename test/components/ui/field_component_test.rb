# frozen_string_literal: true

require 'test_helper'

module Ui
  class FieldComponentTest < ViewComponent::TestCase
    def classes_for(slot)
      page.find("[data-slot='#{slot}']", visible: :all)['class'].split
    end

    def control
      page.find('[data-slot=input]')
    end

    def render_field(errors: nil, description: true, **options, &block)
      render_inline(Ui::FieldComponent.new(name: 'user[email]', errors: errors, **options)) do |field|
        field.with_label { 'Email' }
        field.with_control(Ui::InputComponent, type: 'email')
        field.with_description { 'We only use this for receipts.' } if description
        block&.call(field)
      end
    end

    test 'renders wrapper, label, control and description with their data-slots' do
      render_field

      assert_selector "div[data-slot='field'] > label[data-slot='label']", text: 'Email'
      assert_selector "div[data-slot='field'] > input[data-slot='input']"
      assert_selector "div[data-slot='field'] > p[data-slot='field-description']", text: 'We only use this for receipts.'
    end

    test 'derives the control id from the name the way form_with would' do
      render_field

      assert_equal 'user_email', control['id']
      assert_equal 'user[email]', control['name']
    end

    test 'label for matches the control id' do
      render_field

      assert_equal page.find('label')['for'], control['id']
    end

    test 'the label has an id derived from the control id, for aria-labelledby' do
      render_field

      assert_equal 'user_email-label', page.find('label')['id']
    end

    test 'a caller-supplied control_id drives every derived id' do
      render_field(control_id: 'signup-email', errors: ['is invalid'])

      assert_equal 'signup-email', control['id']
      assert_equal 'signup-email', page.find('label')['for']
      assert_equal 'signup-email-label', page.find('label')['id']
      assert_equal 'signup-email-description signup-email-error', control['aria-describedby']
    end

    test 'aria-describedby lists the description then the error' do
      render_field(errors: ['is invalid'])

      assert_equal 'user_email-description user_email-error', control['aria-describedby']
      assert_equal 'user_email-description', page.find("[data-slot='field-description']", visible: :all)['id']
      assert_equal 'user_email-error', page.find("[data-slot='field-error']")['id']
    end

    test 'aria-describedby names only the description when there are no errors' do
      render_field

      assert_equal 'user_email-description', control['aria-describedby']
    end

    test 'aria-describedby names only the error when there is no description' do
      render_field(description: false, errors: ['is invalid'])

      assert_equal 'user_email-error', control['aria-describedby']
    end

    test 'aria-describedby is absent when neither part is present' do
      render_field(description: false)

      assert_nil control['aria-describedby']
    end

    test 'aria-describedby is exact whatever order the caller sets the parts in' do
      render_inline(Ui::FieldComponent.new(name: 'email', errors: ['is invalid'])) do |field|
        field.with_control(Ui::InputComponent)
        field.with_description { 'Set after the control.' }
        field.with_label { 'Email' }
      end

      assert_equal 'email-description email-error', control['aria-describedby']
    end

    test 'marks the control and the wrapper invalid only when there are errors' do
      render_field(errors: ['is invalid'])

      assert_equal 'true', control['aria-invalid']
      assert_selector "[data-slot='field'][data-invalid='true']"
    end

    test 'renders no invalid state and no error text without errors' do
      render_field

      assert_nil control['aria-invalid']
      assert_no_selector "[data-slot='field'][data-invalid]"
      assert_no_selector "[data-slot='field-error']"
    end

    test 'an empty errors array is not an error state' do
      render_field(errors: [])

      assert_nil control['aria-invalid']
      assert_no_selector "[data-slot='field-error']"
    end

    test 'joins several messages into one error line' do
      render_field(errors: ["can't be blank", 'is too short'])

      assert_selector "[data-slot='field-error']", text: "can't be blank and is too short"
      assert_equal 1, page.all("[data-slot='field-error']").size
    end

    test 'accepts a single error message' do
      render_field(errors: 'is invalid')

      assert_selector "[data-slot='field-error']", text: 'is invalid'
    end

    test 'error text is drawn from the destructive token' do
      render_field(errors: ['is invalid'])

      assert_includes classes_for('field-error'), 'text-destructive'
    end

    test 'caller class on a part wins over a conflicting default' do
      render_inline(Ui::FieldComponent.new(name: 'email', errors: ['is invalid'])) do |field|
        field.with_label(class: 'text-base') { 'Email' }
        field.with_control(Ui::InputComponent, class: 'h-20')
        field.with_description(class: 'text-foreground') { 'Hint' }
      end

      assert_includes classes_for('label'), 'text-base'
      assert_not_includes classes_for('label'), 'text-sm'
      assert_includes classes_for('input'), 'h-20'
      assert_not_includes classes_for('input'), 'h-(--control-height)'
      assert_includes classes_for('field-description'), 'text-foreground'
      assert_not_includes classes_for('field-description'), 'text-muted-foreground'
    end

    test 'caller class on the wrapper wins over a conflicting default' do
      render_field(class: 'gap-6')

      assert_includes classes_for('field'), 'gap-6'
      assert_not_includes classes_for('field'), 'gap-2'
    end

    test 'a part keeps its wiring when the caller passes attributes to it' do
      render_inline(Ui::FieldComponent.new(name: 'email')) do |field|
        field.with_label(data: { testid: 'label' }) { 'Email' }
        field.with_control(Ui::InputComponent, placeholder: 'name@company.com', required: true)
        field.with_description(data: { testid: 'hint' }) { 'Hint' }
      end

      assert_selector "label#email-label[for='email'][data-testid='label']"
      assert_selector "input#email[name='email'][placeholder='name@company.com'][required]"
      assert_selector "p#email-description[data-testid='hint']"
    end

    test 'a caller attribute overrides the field wiring it collides with' do
      render_inline(Ui::FieldComponent.new(name: 'email')) do |field|
        field.with_control(Ui::InputComponent, name: 'user[email]')
      end

      assert_equal 'user[email]', control['name']
      assert_equal 'email', control['id']
    end

    test "a caller's aria-describedby on the control joins the description and error ids rather than replacing them" do
      render_inline(Ui::FieldComponent.new(name: 'user[email]', errors: ['is invalid'])) do |field|
        field.with_label { 'Email' }
        field.with_control(Ui::InputComponent, type: 'email', aria: { describedby: 'my-hint' })
        field.with_description { 'We only use this for receipts.' }
      end

      assert_equal 'user_email-description user_email-error my-hint', control['aria-describedby']
      assert_equal 'true', control['aria-invalid']
    end

    test 'a flat aria-describedby key on the control joins the field ids too' do
      render_inline(Ui::FieldComponent.new(name: 'user[email]', errors: ['is invalid'])) do |field|
        field.with_label { 'Email' }
        field.with_control(Ui::InputComponent, type: 'email', 'aria-describedby': 'my-hint')
        field.with_description { 'We only use this for receipts.' }
      end

      assert_equal 'user_email-description user_email-error my-hint', control['aria-describedby']
    end

    test 'forwards html attributes to the wrapper' do
      render_field(id: 'email-field', data: { testid: 'field' })

      assert_selector "div#email-field[data-slot='field'][data-testid='field']"
    end

    test 'renders any control component, not just an input' do
      textarea = Class.new(Ui::Base) do
        data_slot 'textarea'

        def call
          tag.textarea(**root_attributes)
        end
      end
      Ui.const_set(:TestTextareaComponent, textarea)

      render_inline(Ui::FieldComponent.new(name: 'bio', errors: ['is too long'])) do |field|
        field.with_label { 'Bio' }
        field.with_control(Ui::TestTextareaComponent, rows: 4)
      end

      assert_selector "textarea#bio[name='bio'][rows='4'][aria-invalid='true'][aria-describedby='bio-error']"
    ensure
      Ui.send(:remove_const, :TestTextareaComponent)
    end

    test 'a control block receives the wiring the field would have applied' do
      # The block form's `render` call needs a real view context, which is why this
      # goes through an inline ERB template rather than render_inline: a bare Ruby
      # block, as a caller would never write it, has no `render` in scope at all.
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::FieldComponent.new(name: "email", errors: ["is invalid"]) do |field| %>
            <% field.with_label { "Email" } %>
            <% field.with_control { |c| render(Ui::InputComponent.new(**c.attributes)) } %>
            <% field.with_description { "Hint" } %>
          <% end %>
        ERB
      end

      assert_selector "input#email[aria-invalid='true'][aria-describedby='email-description email-error']"
    end

    test 'composes from an erb template with nested parts' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::FieldComponent.new(name: "user[email]", errors: ["is invalid"], id: "erb-field") do |field| %>
            <% field.with_label { "Email" } %>
            <% field.with_control(Ui::InputComponent, type: "email", placeholder: "name@company.com") %>
            <% field.with_description do %>
              We only use this for <strong>receipts</strong>.
            <% end %>
          <% end %>
        ERB
      end

      assert_selector "#erb-field[data-invalid='true'] > label[for='user_email']", text: 'Email'
      assert_selector "#erb-field > input#user_email[type='email'][aria-invalid='true']"
      assert_equal 'user_email-description user_email-error', page.find('input')['aria-describedby']
      assert_selector '#user_email-description strong', text: 'receipts', visible: :all
      assert_selector '#user_email-error', text: 'is invalid'
      assert_equal 1, page.all("[data-slot='input']").size
    end
  end
end
