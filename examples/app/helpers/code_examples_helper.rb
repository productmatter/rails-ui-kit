# frozen_string_literal: true

# Code examples for the docs site. Defined in a Ruby helper (not in ERB templates)
# so that ERB sequences in the example strings aren't processed by the ERB scanner.
module CodeExamplesHelper
  def example_button_usage
    <<~'RUBY'
      <%= render(Ui::ButtonComponent.new) { "Save changes" } %>

      <%= render Ui::ButtonComponent.new(variant: :outline, size: :sm) do %>
        Cancel
      <% end %>

      <%# href renders an <a> instead of a <button> %>
      <%= render Ui::ButtonComponent.new(href: settings_path, variant: :link) do %>
        Settings
      <% end %>

      <%# Anything else is forwarded to the root element %>
      <%= render Ui::ButtonComponent.new(
            variant: :destructive,
            type: "submit",
            data: { turbo_confirm: "Delete this record?" }
          ) do %>
        Delete
      <% end %>

      <%# Submitting: disabled, with a spinner, until Turbo reports the response %>
      <%= render Ui::ButtonComponent.new(type: "submit",
                                         data: { turbo_disable_with: t(".saving"), turbo_disable_style: "spinner" }) do %>
        Save changes
      <% end %>

      <%# A caller class beats the default it conflicts with: rounded-full wins, rounded-md is dropped %>
      <%= render(Ui::ButtonComponent.new(class: "rounded-full w-full")) { "Follow" } %>
    RUBY
  end

  def example_input_usage
    <<~'RUBY'
      <%# In a form, through Field: named, valued, labelled and marked invalid from the record %>
      <%= render Ui::FieldComponent.new(model: @user, attribute: :email) do |field| %>
        <% field.with_control(Ui::InputComponent, type: "email", autocomplete: "email") %>
      <% end %>

      <%# On its own, name it yourself %>
      <%= render Ui::InputComponent.new(type: "search", name: "q", placeholder: "Search", aria: { label: "Search" }) %>

      <%# Invalid state is aria-invalid, not a keyword: in a form, Field sets it from the errors %>
      <%= render Ui::InputComponent.new(id: "email", name: "email", aria: { invalid: true }) %>

      <%= render Ui::InputComponent.new(id: "email", name: "email", disabled: true) %>
    RUBY
  end

  def example_label_usage
    <<~'RUBY'
      <%# In a form, Field renders the label from the record; a block replaces the text %>
      <%= render Ui::FieldComponent.new(model: @user, attribute: :email) do |field| %>
        <% field.with_label { "Work email" } %>
      <% end %>

      <%# On its own %>
      <%= render(Ui::LabelComponent.new(for: "terms")) { "Accept the terms" } %>

      <%# peer-disabled dims the label when the control it names is disabled %>
      <input id="terms" type="checkbox" class="peer" disabled>
      <%= render(Ui::LabelComponent.new(for: "terms")) { "Accept the terms" } %>
    RUBY
  end

  def example_textarea_usage
    <<~'RUBY'
      <%# In a form, through Field: the record's value becomes the content %>
      <%= render Ui::FieldComponent.new(model: @project, attribute: :summary) do |field| %>
        <% field.with_control(Ui::TextareaComponent, rows: 4) %>
      <% end %>

      <%# On its own %>
      <%= render Ui::TextareaComponent.new(id: "notes", name: "notes", placeholder: "Add a note", aria: { label: "Notes" }) %>

      <%# The block is the textarea's value — a <textarea> has no value attribute %>
      <%= render Ui::TextareaComponent.new(id: "notes", name: "notes") do %>Existing notes<% end %>
    RUBY
  end

  def example_tooltip_usage
    <<~'RUBY'
      <%= render Ui::TooltipComponent.new(text: "Save your changes", placement: "top") do |t| %>
        <% t.with_trigger do %>
          <button>Save</button>
        <% end %>
      <% end %>
    RUBY
  end

  def example_popover_usage
    <<~'RUBY'
      <%= render Ui::PopoverComponent.new(placement: "bottom", panel_classes: "w-64 p-4") do |p| %>
        <% p.with_trigger do %>
          <button>Open</button>
        <% end %>
        <% p.with_panel do %>
          <p class="font-semibold text-sm mb-2">Title</p>
          <p class="text-sm text-muted-foreground">Any HTML content here.</p>
        <% end %>
      <% end %>
    RUBY
  end

  def example_modal_trigger
    <<~'RUBY'
      <%# In your layout, once %>
      <div id="modal" data-turbo-permanent></div>

      <%# The trigger: data-turbo-stream asks for the Turbo Stream response %>
      <%= link_to "Edit", edit_project_path(@project),
            id: dom_id(@project, :edit), data: { turbo_stream: true } %>
    RUBY
  end

  def example_modal_response
    <<~'RUBY'
      <%# app/views/projects/edit.turbo_stream.erb %>
      <%= turbo_stream.update "modal" do %>
        <%= render Ui::ModalComponent.new(aria: { labelledby: "project_modal_title" }) do %>
          <%= turbo_frame_tag "project_modal_content" do %>
            <%= render "form", project: @project %>
          <% end %>
        <% end %>
      <% end %>
    RUBY
  end

  def example_dropdown_usage
    <<~'RUBY'
      <%= render Ui::DropdownComponent.new(kind: :menu) do |d| %>
        <% d.with_trigger do %>
          <button data-action="click->ui--dropdown#toggle">Actions</button>
        <% end %>
        <% d.with_menu do %>
          <div class="py-1">
            <a href="#" role="menuitem" class="flex px-3 py-2 text-sm hover:bg-accent hover:text-accent-foreground focus:bg-accent focus:text-accent-foreground">Edit</a>
            <a href="#" role="menuitem" class="flex px-3 py-2 text-sm text-destructive hover:bg-accent focus:bg-accent">Delete</a>
          </div>
        <% end %>
      <% end %>
    RUBY
  end

  def example_toast_layout
    '<%= render Ui::ToastContainerComponent.new %>'
  end

  def example_toast_stream
    <<~'RUBY'
      <%= turbo_stream.append "body" do %>
        <%= render Ui::ToastComponent.new(type: :success, message: "Record saved.") %>
      <% end %>
    RUBY
  end

  def example_toast_js
    <<~'CODE'
      window.triggerToast("success", "Record saved.")

      // With title + custom timeout (ms):
      window.triggerToast("error", { title: "Failed", body: "Please try again.", timeout: 10000 })
    CODE
  end

  def example_confirm_layout
    '<%= render Ui::ConfirmDialogComponent.new %>'
  end

  def example_confirm_icon
    <<~'CODE'
      <%= render Ui::ConfirmDialogComponent.new(icon_wrapper_class: "rounded-full bg-destructive/10 text-destructive") do |dialog| %>
        <% dialog.with_icon do %>
          <svg class="size-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
          </svg>
        <% end %>
      <% end %>
    CODE
  end

  def example_confirm_rich
    <<~'CODE'
      <%= render Ui::ConfirmDialogComponent.new(id: "archive-confirm", title: "Archive this project?",
            confirm_label: "Archive", confirm_variant: :default,
            icon_wrapper_class: "rounded-full bg-primary/10 text-primary") do |dialog| %>
        <% dialog.with_icon { render "icons/archive" } %>
        <% dialog.with_body do %>
          <p>Archiving hides it from the project list. Nothing is deleted.</p>
        <% end %>
      <% end %>

      // Then, from JavaScript:
      if (await window.customConfirmDialog("#archive-confirm")) { /* proceed */ }
    CODE
  end

  def example_confirm_js
    <<~'CODE'
      const ok = await window.defaultConfirmDialog("Delete this item?")
      if (ok) { /* proceed */ }

      // With a title, custom labels and a non-destructive confirm button:
      const ok = await window.defaultConfirmDialog({
        title: "Publish this post?", message: "Readers will see it immediately.",
        confirm_label: "Publish", confirm_variant: "default"
      })
    CODE
  end

  def example_dark_mode_usage
    <<~'RUBY'
      <%# Once, in your layout, on an element that contains the toggle %>
      <body data-controller="ui--dark-mode">
        <%# The toggle target is what gets aria-pressed and a "Switch to dark mode" name %>
        <button type="button"
                data-ui--dark-mode-target="toggle"
                data-action="click->ui--dark-mode#toggle">
          Toggle theme
        </button>
      </body>
    RUBY
  end

  def example_dark_mode_css
    <<~'CODE'
      @import "tailwindcss";
      @import "../builds/tailwind/rails_ui_kit.css";
      @custom-variant dark (&:where(.dark, .dark *));
    CODE
  end

  def example_form_change_usage
    <<~'RUBY'
      <%= form_with model: @record, data: { controller: "ui--form-change" } do |f| %>
        <%= f.text_field :name %>
        <%= f.submit %>
      <% end %>
    RUBY
  end

  def example_turbo_confirm_setup
    <<~'RUBY'
      <%= render Ui::ConfirmDialogComponent.new %>
      <div data-controller="ui--turbo-confirm"></div>
    RUBY
  end

  def example_turbo_confirm_usage
    <<~'RUBY'
      <%# Standard Turbo confirm — uses the kit dialog automatically %>
      <%= button_to "Delete", record_path(@record), method: :delete,
          data: { turbo_confirm: "Delete this record?" } %>

      <%# Every part of the confirmation, as data-turbo-confirm- plus the option key %>
      <%= button_to "Publish", publish_path(@post), method: :post,
          data: {
            turbo_confirm: "Readers will see it immediately.",
            turbo_confirm_title: "Publish this post?",
            turbo_confirm_confirm_label: "Publish",
            turbo_confirm_confirm_variant: "default"
          } %>
    RUBY
  end

  def example_disable_with_setup
    '<div data-controller="ui--turbo-disable-with"></div>'
  end

  def example_disable_with_usage
    <<~'RUBY'
      <%# Simple text replacement %>
      <%= f.submit "Save", data: { turbo_disable_with: "Saving..." } %>

      <%# Spinner style %>
      <%= f.submit "Save", data: { turbo_disable_with: "Saving", turbo_disable_style: "spinner" } %>

      <%# Pulse style (fades the button) %>
      <%= f.submit "Save", data: { turbo_disable_with: "Saving", turbo_disable_style: "pulse" } %>

      <%# Global default — add to your layout <head> %>
      <meta name="turbo-disable-with-default" content="Processing...">
    RUBY
  end

  def example_field_usage
    <<~'RUBY'
      <%# From the record: name, id, label, errors, value and required %>
      <%= render Ui::FieldComponent.new(model: @user, attribute: :email) %>

      <%# Any part can still be given; what you state wins %>
      <%= render Ui::FieldComponent.new(model: @user, attribute: :email, required: false) do |field| %>
        <% field.with_label { "Work email" } %>
        <% field.with_control(Ui::InputComponent, type: "email") %>
        <% field.with_description { "We'll never share your email." } %>
      <% end %>

      <%# A single field answered with a morph keeps the field, so the help text and error swap in place %>
      <%= turbo_stream.replace dom_id(@user, :email_field), method: :morph do %>
        <%= render Ui::FieldComponent.new(model: @user, attribute: :email, id: dom_id(@user, :email_field)) %>
      <% end %>

      <%# Without a record: the name and errors are yours to pass %>
      <%= render Ui::FieldComponent.new(name: "user[email]") do |field| %>
        <% field.with_label { "Email" } %>
        <% field.with_control(Ui::InputComponent, type: "email") %>
        <% field.with_description { "We'll never share your email." } %>
      <% end %>

      <%# errors: takes a plain array of messages -- @user.errors[:email], not the
          errors object itself, since the HTML name ("user[email]") and the model
          attribute ("email") aren't the same thing %>
      <%= render Ui::FieldComponent.new(name: "user[email]", errors: @user.errors[:email]) do |field| %>
        <% field.with_label { "Email" } %>
        <% field.with_control(Ui::InputComponent, type: "email", value: @user.email) %>
      <% end %>

      <%# A block form covers Textarea, a <select> or any custom control -- it receives
          the field's own id/name/aria wiring through c.attributes %>
      <%= render Ui::FieldComponent.new(name: "user[bio]") do |field| %>
        <% field.with_label { "Bio" } %>
        <% field.with_control { |c| render(Ui::TextareaComponent.new(**c.attributes)) { @user.bio } } %>
      <% end %>
    RUBY
  end

  def example_select_usage
    <<~'RUBY'
      <%# Reads like collection_select: a collection, a value method and a text method %>
      <%= render Ui::SelectComponent.new(name: "post[author_id]", collection: Author.order(:name),
                                        value_method: :id, text_method: :name,
                                        selected: @post.author_id, include_blank: "No author") %>

      <%# Or like select: an array of pairs, an array of strings, or a text => value hash %>
      <%= render Ui::SelectComponent.new(name: "post[state]",
                                        options: [["Draft", "draft"], ["Published", "published"]]) %>

      <%# A model enum, labelled through human_attribute_name, submitting the enum key %>
      <%= render Ui::SelectComponent.new(name: "order[status]", model: Order, enum: :status,
                                        selected: @order.status) %>

      <%# Inside a Field, which supplies id, name, aria-describedby and aria-invalid %>
      <%= render Ui::FieldComponent.new(name: "order[status]", errors: @order.errors[:status]) do |field| %>
        <% field.with_label { "Status" } %>
        <% field.with_control(Ui::SelectComponent, model: Order, enum: :status, selected: @order.status) %>
      <% end %>

      <%# Change it from your own code the way you would any form control %>
      <script>
        select.value = "shipped"
        select.dispatchEvent(new Event("change", { bubbles: true }))
      </script>
    RUBY
  end

  def example_ui_select_helper
    <<~'RUBY'
      # test/application_system_test_case.rb
      require "rails_ui_kit/test_helpers"

      class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
        driven_by :selenium, using: :headless_chrome
        include RailsUiKit::TestHelpers
      end

      # In a test. Works in both modes, and falls back to the native select where the
      # component wasn't enhanced (JavaScript off, or the platform picker on a phone).
      ui_select "Pending", from: "Status"      # the Field label
      ui_select "Pending", from: "order[status]"  # or the name the form posts
      ui_select "Pending", from: "order_status"   # or the control's id

      # Unchanged: the value still lives in a native <select>, so assert it the way you
      # always did.
      assert_equal "pending", find("#order_status", visible: :all).value
    RUBY
  end

  def example_i18n_override
    <<~YAML
      en:
        rails_ui_kit:
          confirm_dialog:
            title: "Are you sure?"
            message: "This action cannot be undone."
    YAML
  end

  def example_i18n_ruby_override
    <<~'RUBY'
      <%# Uses rails_ui_kit.confirm_dialog.* from the locale file %>
      <%= render Ui::ConfirmDialogComponent.new %>

      <%# A keyword still wins over the translation, same as any other attribute %>
      <%= render Ui::ConfirmDialogComponent.new(
            id: "delete-confirm",
            title: "Delete this post?",
            message: "This can't be undone."
          ) %>
    RUBY
  end

  # Russian: four categories, and every form carries the count.
  def example_i18n_plurals
    <<~'YAML'
      ru:
        rails_ui_kit:
          select:
            results:
              one:   "%{count} результат"
              few:   "%{count} результата"
              many:  "%{count} результатов"
              other: "%{count} результата"
    YAML
  end

  def example_choices_usage
    <<~'RUBY'
      <%# Reads like collection_check_boxes: a collection, a value method and a text method %>
      <%= render Ui::ChoicesComponent.new(name: "user[role_ids]", multiple: true,
                                          collection: Role.order(:name), value_method: :id,
                                          text_method: :name, checked: @user.role_ids) %>

      <%# Or like collection_radio_buttons: one choice, so no [] and no array %>
      <%= render Ui::ChoicesComponent.new(name: "account[plan_id]", collection: Plan.order(:price),
                                          value_method: :id, text_method: :name,
                                          checked: @account.plan_id) %>

      <%# Arrays, hashes and enums, as options_for_select reads them %>
      <%= render Ui::ChoicesComponent.new(name: "shirt[size]", options: %w[S M L]) %>
      <%= render Ui::ChoicesComponent.new(name: "order[status]", model: Order, enum: :status,
                                          checked: @order.status) %>

      <%# Inside a Field, which supplies the id, the name, the description, the error and required.
          A has_many is validated as `roles` and edited as `role_ids`, so say which errors are its %>
      <%= render Ui::FieldComponent.new(model: @user, attribute: :role_ids, required: true,
                                        errors: @user.errors[:roles]) do |field| %>
        <% field.with_label { "Roles" } %>
        <% field.with_control(Ui::ChoicesComponent, multiple: true, collection: Role.order(:name),
                              value_method: :id, text_method: :name) %>
        <% field.with_description { "People with no role can sign in but see nothing." } %>
      <% end %>

      <%# The card variant: a description line, a decorative icon, and your own columns %>
      <%= render Ui::ChoicesComponent.new(name: "account[plan_id]", variant: :card,
                                          collection: plans, value_method: :id, text_method: :name,
                                          description_method: :tagline,
                                          icon_method: ->(plan) { plan_icon(plan) },
                                          class: "sm:grid-cols-3") %>
    RUBY
  end

  def example_i18n_standalone_controllers
    <<~'RUBY'
      <button data-controller="ui--dark-mode"
              data-action="click->ui--dark-mode#toggle"
              data-ui--dark-mode-light-label-value="<%= I18n.t('rails_ui_kit.dark_mode.switch_to_light') %>"
              data-ui--dark-mode-dark-label-value="<%= I18n.t('rails_ui_kit.dark_mode.switch_to_dark') %>">
        Toggle theme
      </button>

      <%# Layout <head> — global fallback for every button without its own data-turbo-disable-with %>
      <meta name="turbo-disable-with-default" content="<%= I18n.t('rails_ui_kit.turbo_disable_with.processing') %>">
    RUBY
  end

  def example_theming_tokens
    <<~'CSS'
      @import "tailwindcss";
      @import "../builds/tailwind/rails_ui_kit.css";
      @custom-variant dark (&:where(.dark, .dark *));

      :root { --primary: oklch(0.55 0.19 145); --primary-foreground: oklch(0.98 0.02 145); --radius: 0.375rem; }
      .dark { --primary: oklch(0.72 0.15 145); --primary-foreground: oklch(0.2 0.04 145); }
    CSS
  end

  def example_theming_control_heights
    <<~'CSS'
      :root       { --control-height-sm: 1.75rem; --control-height: 2rem; --control-height-lg: 2.25rem; }
      .data-table { --control-height: 1.75rem; }
    CSS
  end

  def example_theming_class_merge
    <<~'RUBY'
      <%# rounded-full replaces the button's rounded-md; every other default stays %>
      <%= render(Ui::ButtonComponent.new(class: "rounded-full")) { "Follow" } %>

      <%# A default with a modifier is replaced only by a class with the same modifier %>
      <%= render Ui::ButtonComponent.new(class: "px-2 has-[>svg]:px-2") do %>…<% end %>
    RUBY
  end
end
