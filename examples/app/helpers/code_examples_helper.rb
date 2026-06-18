# frozen_string_literal: true

# Code examples for the docs site. Defined in a Ruby helper (not in ERB templates)
# so that ERB sequences in the example strings aren't processed by the ERB scanner.
module CodeExamplesHelper
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
      <turbo-frame id="modal"></turbo-frame>
      <%= link_to "Open", edit_record_path(@record), data: { turbo_frame: "modal" } %>
    RUBY
  end

  def example_modal_response
    <<~'RUBY'
      <turbo-frame id="modal">
        <%= render Ui::ModalComponent.new(position: :right) do %>
          <div class="p-6">
            <h2 class="text-lg font-semibold mb-4">Edit record</h2>
            <%= render "form", record: @record %>
          </div>
        <% end %>
      </turbo-frame>
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
end
