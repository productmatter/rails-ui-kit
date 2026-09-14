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

      <%# A caller class beats the variant default — bg-red-500 wins, bg-primary is dropped %>
      <%= render(Ui::ButtonComponent.new(class: "bg-red-500 w-full")) { "Custom" } %>
    RUBY
  end

  def example_input_usage
    <<~'RUBY'
      <div class="grid gap-2">
        <%= render(Ui::LabelComponent.new(for: "email")) { "Email" } %>
        <%= render Ui::InputComponent.new(type: "email", id: "email", name: "email", placeholder: "you@example.com") %>
      </div>

      <%# Invalid state is driven by aria-invalid, not a keyword, so field binding can set it later %>
      <%= render Ui::InputComponent.new(id: "email", name: "email", aria: { invalid: true }) %>

      <%= render Ui::InputComponent.new(id: "email", name: "email", disabled: true) %>
    RUBY
  end

  def example_label_usage
    <<~'RUBY'
      <%= render(Ui::LabelComponent.new(for: "terms")) { "Accept the terms" } %>

      <%# peer-disabled dims the label when the control it names is disabled %>
      <input id="terms" type="checkbox" class="peer" disabled>
      <%= render(Ui::LabelComponent.new(for: "terms")) { "Accept the terms" } %>
    RUBY
  end

  def example_textarea_usage
    <<~'RUBY'
      <div class="grid gap-2">
        <%= render(Ui::LabelComponent.new(for: "notes")) { "Notes" } %>
        <%= render Ui::TextareaComponent.new(id: "notes", name: "notes", placeholder: "Add a note") %>
      </div>

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
          <p class="text-sm text-neutral-500">Any HTML content here.</p>
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
            <a href="#" role="menuitem" class="flex px-3 py-2 text-sm hover:bg-neutral-100">Edit</a>
            <a href="#" role="menuitem" class="flex px-3 py-2 text-sm hover:bg-neutral-100">Delete</a>
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

  def example_confirm_js
    <<~'CODE'
      const ok = await window.defaultConfirmDialog("Delete this item?")
      if (ok) { /* proceed */ }

      // With title:
      const ok = await window.defaultConfirmDialog({ title: "Publish?", message: "This is permanent." })
    CODE
  end

  def example_dark_mode_usage
    <<~'RUBY'
      <%# Wire the controller once in your layout %>
      <div data-controller="ui--dark-mode"></div>

      <%# Or attach a toggle button directly %>
      <button data-controller="ui--dark-mode" data-action="click->ui--dark-mode#toggle">
        Toggle theme
      </button>
    RUBY
  end

  def example_dark_mode_css
    <<~'CODE'
      @import "tailwindcss";

      @variant dark (&:where(.dark, .dark *));
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

      <%# Custom title via data attribute %>
      <%= button_to "Publish", publish_path(@post), method: :post,
          data: {
            turbo_confirm: "This will make the post public.",
            turbo_confirm_title: "Publish post?"
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

  def example_media_query_usage
    <<~'RUBY'
      <div data-controller="ui--media-query"
           data-ui--media-query-query-value="(min-width: 768px)"
           data-ui--media-query-matches-class="border-primary">
        <%# Reads data-media-matches="true|false", or listens for ui--media-query:change %>
      </div>
    RUBY
  end
end
