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

  def example_button_group_usage
    <<~'RUBY'
      <%= render Ui::ButtonGroupComponent.new(aria: { label: "Text alignment" }) do |group| %>
        <% group.with_item_button(variant: :outline, aria: { label: "Align left" }) do %>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 6h18M3 12h12M3 18h18"/></svg>
        <% end %>
        <% group.with_item_button(variant: :outline, aria: { label: "Align center" }) do %>
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 6h18M6 12h12M3 18h18"/></svg>
        <% end %>
      <% end %>

      <%# Separator and text parts render the real Separator, in call order %>
      <%= render Ui::ButtonGroupComponent.new do |group| %>
        <% group.with_item_button(variant: :outline) { "1" } %>
        <% group.with_item_separator(orientation: :vertical) %>
        <% group.with_item_text { "of 10" } %>
        <% group.with_item_separator(orientation: :vertical) %>
        <% group.with_item_button(variant: :outline) { "10" } %>
      <% end %>

      <%# orientation: :vertical stacks the buttons and stretches them to the group's width %>
      <%= render Ui::ButtonGroupComponent.new(orientation: :vertical, class: "w-40") do |group| %>
        <% group.with_item_button(variant: :outline) { "Cut" } %>
        <% group.with_item_button(variant: :outline) { "Copy" } %>
        <% group.with_item_button(variant: :outline) { "Paste" } %>
      <% end %>
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

  def example_breadcrumb_usage
    <<~'RUBY'
      <%= render Ui::BreadcrumbComponent.new do |breadcrumb| %>
        <% breadcrumb.with_link(href: root_path) { "Home" } %>
        <% breadcrumb.with_link(href: components_path) { "Components" } %>
        <% breadcrumb.with_page { "Breadcrumb" } %>
      <% end %>

      <%# A collapsed run of ancestors -- its accessible name is "More" unless you override it %>
      <%= render Ui::BreadcrumbComponent.new do |breadcrumb| %>
        <% breadcrumb.with_link(href: root_path) { "Home" } %>
        <% breadcrumb.with_ellipsis(aria: { label: "2 hidden pages" }) %>
        <% breadcrumb.with_page { "Breadcrumb" } %>
      <% end %>
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

  def example_pagination_usage
    <<~'RUBY'
      <%= render Ui::PaginationComponent.new do |pagination| %>
        <%# Icon-only previous/next need their own accessible name %>
        <% pagination.with_link(href: page_path(1), aria: { label: "Go to previous page" }) do %>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m15 18-6-6 6-6"/></svg>
        <% end %>
        <% pagination.with_link(href: page_path(1)) { "1" } %>
        <% pagination.with_link(href: page_path(2), active: true) { "2" } %>
        <% pagination.with_ellipsis %>
        <% pagination.with_link(href: page_path(10)) { "10" } %>
        <% pagination.with_link(href: page_path(3), aria: { label: "Go to next page" }) do %>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg>
        <% end %>
      <% end %>
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

  def example_input_group_usage
    <<~'RUBY'
      <%# A leading icon is decorative here -- the placeholder already says "Search" %>
      <%= render Ui::InputGroupComponent.new do |group| %>
        <% group.with_addon(aria: { hidden: true }) do %>
          <svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
        <% end %>
        <%= render Ui::InputComponent.new(name: "q", placeholder: "Search") %>
      <% end %>

      <%# A text addon that labels the control is associated with it via aria-describedby,
          since Input Group renders the control as plain content, not a slot it owns itself %>
      <%= render Ui::InputGroupComponent.new do |group| %>
        <% group.with_addon(id: "amount-currency") { "$" } %>
        <%= render Ui::InputComponent.new(name: "amount", aria: { describedby: "amount-currency" }) %>
        <% group.with_addon(align: "inline-end", id: "amount-unit") { "USD" } %>
      <% end %>

      <%# An icon-only Button addon needs its own accessible name %>
      <%= render Ui::InputGroupComponent.new do |group| %>
        <%= render Ui::TextareaComponent.new(name: "message", placeholder: "Write a message") %>
        <% group.with_addon(align: "block-end") do %>
          <%= render Ui::ButtonComponent.new(variant: :ghost, size: :icon, aria: { label: "Attach a file" }) do %>
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 11 12 20a4 4 0 0 1-6-6l8-8"/></svg>
          <% end %>
        <% end %>
      <% end %>
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

  def example_table_usage
    <<~'RUBY'
      <%= render Ui::TableComponent.new do |table| %>
        <% table.with_caption { "Recent invoices" } %>
        <% table.with_header do |header| %>
          <% header.with_row do |row| %>
            <% row.with_head(scope: "col") { "Invoice" } %>
            <% row.with_head(scope: "col") { "Status" } %>
          <% end %>
        <% end %>
        <% table.with_body do |body| %>
          <% @invoices.each do |invoice| %>
            <% body.with_row do |row| %>
              <% row.with_head(scope: "row") { invoice.number } %>
              <% row.with_cell { invoice.status } %>
            <% end %>
          <% end %>
        <% end %>
      <% end %>
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

  def example_native_select_usage
    <<~'RUBY'
      <div class="grid gap-2">
        <%= render(Ui::LabelComponent.new(for: "role")) { "Role" } %>
        <%= render Ui::NativeSelectComponent.new(id: "role", name: "role") do %>
          <option value="member">Member</option>
          <option value="admin">Admin</option>
        <% end %>
      </div>

      <%= render Ui::NativeSelectComponent.new(name: "size", size: :sm) do %>
        <option value="s">Small</option>
        <option value="m">Medium</option>
      <% end %>

      <%# Invalid state is driven by aria-invalid, not a keyword, so field binding can set it later %>
      <%= render Ui::NativeSelectComponent.new(name: "role", aria: { invalid: true }) do %>
        <option value="">Choose a role</option>
      <% end %>
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

  def example_progress_usage
    <<~'RUBY'
      <%= render Ui::ProgressComponent.new(value: 60, label: "Uploading photo.png") %>

      <%# max: for a scale other than 0-100 %>
      <%= render Ui::ProgressComponent.new(value: 3, max: 5, label: "Step 3 of 5") %>

      <%# No value: renders at 0 -- always a real number, never indeterminate %>
      <%= render Ui::ProgressComponent.new(label: "Waiting to start") %>

      <%# A visible heading can serve as the name instead of label: %>
      <h3 id="disk-usage-heading">Disk usage</h3>
      <%= render Ui::ProgressComponent.new(value: 82, aria: { labelledby: "disk-usage-heading" }) %>

      <%# class: recolours the track; the fill stays on --primary, the token that carries the meaning %>
      <%= render Ui::ProgressComponent.new(value: 90, label: "Storage nearly full", class: "bg-destructive/20") %>
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

  def example_avatar_usage
    <<~'RUBY'
      <%# Decorative: a name is already visible next to it, so the image gets no alt %>
      <%= render Ui::AvatarComponent.new do |avatar| %>
        <% avatar.with_image(src: user.photo_url) %>
        <% avatar.with_fallback { user.initials } %>
      <% end %>

      <%# Sole identification: alt: makes the whole avatar an accessible image %>
      <%= render Ui::AvatarComponent.new(alt: user.name) do |avatar| %>
        <% avatar.with_image(src: user.photo_url) %>
        <% avatar.with_fallback { user.initials } %>
      <% end %>

      <%# No image at all -- the fallback shows on its own %>
      <%= render(Ui::AvatarComponent.new) { |avatar| avatar.with_fallback { "JD" } } %>
    RUBY
  end

  def example_empty_usage
    <<~'RUBY'
      <%= render Ui::EmptyComponent.new do |empty| %>
        <% empty.with_header do |header| %>
          <% header.with_media(variant: :icon) do %>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
          <% end %>
          <% header.with_title { "No results found" } %>
          <% header.with_description { "Try adjusting your search or filters." } %>
        <% end %>
        <% empty.with_body do %>
          <%= render(Ui::ButtonComponent.new(variant: :outline)) { "Clear filters" } %>
        <% end %>
      <% end %>
    RUBY
  end

  def example_item_usage
    <<~'RUBY'
      <%= render Ui::ItemComponent.new(variant: :outline) do |item| %>
        <% item.with_media(variant: :icon) do %>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2v20M2 12h20"/></svg>
        <% end %>
        <% item.with_title { "Push notifications" } %>
        <% item.with_description { "Get notified when someone mentions you." } %>
        <% item.with_actions do %>
          <%= render(Ui::ButtonComponent.new(variant: :outline, size: :sm)) { "Configure" } %>
        <% end %>
      <% end %>

      <%# Stacked, with a rule drawn between each -- Ui::Item::SeparatorComponent, not a caller-drawn border %>
      <%= render Ui::Item::GroupComponent.new do %>
        <%= render(Ui::ItemComponent.new) { |item| item.with_title { "Profile" } } %>
        <%= render(Ui::Item::SeparatorComponent.new) %>
        <%= render(Ui::ItemComponent.new) { |item| item.with_title { "Billing" } } %>
      <% end %>
    RUBY
  end

  def example_field_usage
    <<~'RUBY'
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
