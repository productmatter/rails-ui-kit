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

  def example_card_usage
    <<~'RUBY'
      <%= render Ui::CardComponent.new do |card| %>
        <% card.with_header do |header| %>
          <% header.with_title { "Billing" } %>
          <% header.with_description { "Manage your plan and payment details." } %>
          <% header.with_action do %>
            <%= render(Ui::ButtonComponent.new(variant: :outline, size: :sm)) { "Edit" } %>
          <% end %>
        <% end %>
        <% card.with_body do %>
          <p>Pro plan, billed yearly.</p>
        <% end %>
        <% card.with_footer(class: "justify-end gap-2") do %>
          <%= render(Ui::ButtonComponent.new) { "Upgrade" } %>
        <% end %>
      <% end %>

      <%# No parts: the block renders straight into the card %>
      <%= render Ui::CardComponent.new(class: "px-6") do %>
        Anything at all.
      <% end %>
    RUBY
  end

  def example_badge_usage
    <<~'RUBY'
      <%= render(Ui::BadgeComponent.new) { "New" } %>

      <%= render(Ui::BadgeComponent.new(variant: :secondary)) { "Draft" } %>

      <%# href renders an <a> instead of a <span> %>
      <%= render Ui::BadgeComponent.new(variant: :outline, href: release_path(release)) do %>
        v1.4.0
      <% end %>

      <%# A caller class beats the variant default — bg-red-500 wins, bg-primary is dropped %>
      <%= render(Ui::BadgeComponent.new(class: "bg-red-500")) { "Custom" } %>
    RUBY
  end

  def example_alert_usage
    <<~'RUBY'
      <%= render Ui::AlertComponent.new do |alert| %>
        <% alert.with_icon do %>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 8v4M12 16h.01"/></svg>
        <% end %>
        <% alert.with_title { "Update available" } %>
        <% alert.with_description { "Restart the app to install it." } %>
      <% end %>

      <%# No icon: the alert drops the icon column entirely %>
      <%= render Ui::AlertComponent.new(variant: :destructive) do |alert| %>
        <% alert.with_title { "Payment failed" } %>
        <% alert.with_description { "Update your card to keep your subscription active." } %>
      <% end %>

      <%# Injected dynamically (e.g. after a Turbo Stream update)? Add the live-region role yourself %>
      <%= render Ui::AlertComponent.new(role: "alert") do |alert| %>
        <% alert.with_title { "Saved" } %>
      <% end %>
    RUBY
  end

  def example_separator_usage
    <<~'RUBY'
      <%# Between stacked content — decorative by default %>
      <%= render(Ui::SeparatorComponent.new) %>

      <%# Between inline content, at a fixed height %>
      <div class="flex h-5 items-center gap-4">
        <span>Blog</span>
        <%= render Ui::SeparatorComponent.new(orientation: :vertical) %>
        <span>Docs</span>
      </div>

      <%# A separator that carries meaning gets its role and orientation announced %>
      <%= render(Ui::SeparatorComponent.new(decorative: false)) %>
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

  def example_skeleton_usage
    <<~'RUBY'
      <div class="flex items-center gap-4">
        <%= render Ui::SkeletonComponent.new(class: "size-12 rounded-full") %>
        <div class="grid gap-2">
          <%= render Ui::SkeletonComponent.new(class: "h-4 w-40") %>
          <%= render Ui::SkeletonComponent.new(class: "h-4 w-24") %>
        </div>
      </div>
    RUBY
  end

  def example_spinner_usage
    <<~'RUBY'
      <%= render Ui::SpinnerComponent.new %>

      <%# The block is the accessible name, not visible content %>
      <%= render(Ui::SpinnerComponent.new) { "Saving changes" } %>

      <%# Colour comes from currentColor, so text-* controls it %>
      <%= render Ui::SpinnerComponent.new(class: "text-primary") %>
    RUBY
  end

  def example_kbd_usage
    <<~'RUBY'
      <%= render(Ui::KbdComponent.new) { "Enter" } %>

      <%# A chord: several key caps in call order %>
      <%= render Ui::Kbd::GroupComponent.new do |group| %>
        <% group.with_key { "⌘" } %>
        <% group.with_key { "K" } %>
      <% end %>
    RUBY
  end

  def example_aspect_ratio_usage
    <<~'RUBY'
      <%= render Ui::AspectRatioComponent.new(ratio: :video, class: "overflow-hidden rounded-lg") do %>
        <img src="/photo.jpg" alt="" class="object-cover">
      <% end %>

      <%# A ratio outside the fixed set comes from class: %>
      <%= render Ui::AspectRatioComponent.new(class: "aspect-[21/9]") do %>…<% end %>
    RUBY
  end
end
