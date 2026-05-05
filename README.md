# rails-ui-kit

A Rails Engine packaging reusable UI components as paired ViewComponents and Stimulus controllers. Built for internal use across Product Matter client projects.

## Components

| Component | Stimulus identifier(s) | Description |
|---|---|---|
| `Ui::ModalComponent` | `ui--modal` | 8-position modal dialog with backdrop, form-change tracking, Turbo Frame support |
| `Ui::DropdownComponent` | `ui--dropdown` | Floating-UI-positioned dropdown with keyboard nav, 3 modes (menu/listbox/dialog) |
| `Ui::ConfirmDialogComponent` | `ui--dialog` | Native dialog with Promise-based API, themable via component options |
| `Ui::ToastComponent` | `ui--toast` | Auto-dismissing notification with type styling and timer bar |
| `Ui::ToastContainerComponent` | `ui--toast-container` | Stack container that renders toasts client-side from a `<template>` clone |

## Utility controllers

| Identifier | Description |
|---|---|
| `ui--form-change` | Dirty-form tracking; dispatches `form:changed` and `form:pristine` events |
| `ui--turbo-confirm` | Replaces `Turbo.config.forms.confirm` with the confirm dialog component |
| `ui--turbo-disable-with` | Disables form elements during Turbo submission (text/spinner/pulse styles) |
| `ui--dark-mode` | Toggles `.dark` on `<html>` with localStorage persistence and OS-preference fallback |

## Installation

Add to your Gemfile:

```ruby
gem "rails_ui_kit", git: "git@github.com:productmatter/rails-ui-kit.git"
```

Then choose your JavaScript install path.

### Importmap (zero-config)

The engine automatically appends `@floating-ui/dom` pins (and the gem's own modules) to your importmap. In your `app/javascript/application.js`:

```js
import { Application } from "@hotwired/stimulus"
import { registerControllers } from "rails-ui-kit"

const application = Application.start()
registerControllers(application)
```

### Bundler (esbuild / webpack / rollup)

```bash
npm install @floating-ui/dom
npm install rails-ui-kit
```

```js
import { Application } from "@hotwired/stimulus"
import { registerControllers } from "rails-ui-kit"

const application = Application.start()
registerControllers(application)
```

### CSS

#### Tailwind 4 (with `tailwindcss-rails`)

Tailwind 4 only scans content paths registered via `@source`. The gem ships an engine entrypoint at `app/assets/tailwind/rails_ui_kit/engine.css` which `tailwindcss-rails` 4.x auto-discovers — its `tailwindcss:engines` task (run automatically before `tailwindcss:build`/`watch`) emits `app/assets/builds/tailwind/rails_ui_kit.css` containing an absolute `@import` to the gem's engine.css.

In your application's `app/assets/tailwind/application.css`:

```css
@import "tailwindcss";
@import "../../app/assets/builds/tailwind/rails_ui_kit.css";
```

The build artifact is generated for you — don't create or commit it manually. With this in place Tailwind sees every utility referenced by the gem's `*.html.erb` templates, the Ruby class-list constants in `app/components/ui/*.rb`, and the gem's Stimulus controllers, and the modal transform-state classes from `app/assets/stylesheets/rails_ui_kit/components.css` are bundled in too.

#### Tailwind 3 / Sprockets

```css
/* Tailwind 3 / PostCSS */
@import "rails_ui_kit/components";
```

```css
/* Sprockets */
*= require rails_ui_kit/components
```

For Tailwind 3, also add the gem's templates to your `tailwind.config.js` `content` array so they are scanned:

```js
content: [
  // ...
  "./node_modules/rails-ui-kit/app/**/*.{html.erb,rb,js}"
]
```

## Usage

```erb
<%= render Ui::ModalComponent.new(position: :right, track_changes: true) do %>
  <div class="p-6">
    <h2 class="text-xl font-semibold">Settings</h2>
    <%= form_with(...) do |f| %>
      <div data-controller="ui--form-change">
        <%= f.text_field :name %>
      </div>
    <% end %>
  </div>
<% end %>

<%= render Ui::DropdownComponent.new(placement: "bottom-end") do |dropdown| %>
  <% dropdown.with_trigger do %>
    <button data-action="click->ui--dropdown#toggle">Open menu</button>
  <% end %>
  <% dropdown.with_menu do %>
    <a href="#" role="menuitem">Option 1</a>
    <a href="#" role="menuitem">Option 2</a>
  <% end %>
<% end %>

<%# Render once per layout: %>
<%= render Ui::ConfirmDialogComponent.new %>
<%= render Ui::ToastContainerComponent.new %>
<div data-controller="ui--turbo-confirm ui--turbo-disable-with"></div>
```

### Triggering toasts

The container renders toasts entirely client-side — no network round-trip.

```js
// Direct call
window.triggerToast("success", "Saved!")
window.triggerToast("error", { title: "Save failed", body: "Please try again." })

// Or decoupled via custom event
document.dispatchEvent(new CustomEvent("rails-ui-kit:toast", {
  detail: { type: "success", message: "Saved!" }
}))
```

### Triggering confirm dialogs

```js
const ok = await window.defaultConfirmDialog("Delete this item?")
const ok = await window.defaultConfirmDialog({ title: "Delete?", message: "Cannot be undone." })
```

Or via Turbo's `data-turbo-confirm` attribute (the `ui--turbo-confirm` controller intercepts it):

```erb
<%= button_to "Delete", path, method: :delete,
    data: { turbo_confirm: "Are you sure?", turbo_confirm_title: "Delete account?" } %>
```

## Confirm dialog theming

`Ui::ConfirmDialogComponent` accepts options to customize the styling without overriding the template:

```ruby
Ui::ConfirmDialogComponent.new(
  wrapper_class: "...",
  body_class: "...",
  footer_class: "...",
  title_class: "...",
  message_class: "...",
  confirm_class: "...",
  cancel_class: "...",
  icon_wrapper_class: "...",
  icon_class: "...",
  confirm_label: "Yes, delete",
  cancel_label: "Keep it"
)
```

Each option falls back to a neutral default. The defaults assume Tailwind classes; consumers using a different CSS framework should pass their own classes.

## Dark mode

Apply the controller to a wrapper with an optional toggle button target:

```erb
<div data-controller="ui--dark-mode">
  <button type="button"
          data-ui--dark-mode-target="toggle"
          data-action="click->ui--dark-mode#toggle">
    Toggle theme
  </button>
</div>
```

The controller reads `localStorage.theme`, falls back to OS preference on first visit, and syncs across tabs via the `storage` event.

## Overriding

**ViewComponents:** Define the same component class in your app (e.g. `app/components/ui/modal_component.rb`); your version takes precedence over the gem's.

**Stimulus controllers:** After calling `registerControllers(application)`, register your own controller against the same identifier:

```js
import MyModalController from "./controllers/my_modal_controller"
application.register("ui--modal", MyModalController) // overrides gem's
```

**CSS:** Override with higher-specificity selectors, or skip the gem's stylesheet entirely and write your own using the same class names.

## Dependencies

- Rails >= 7.0
- Ruby >= 3.1
- view_component >= 3.0
- stimulus-rails
- turbo-rails
- `@floating-ui/dom` >= 1.6 (peer dependency, only required if you use `Ui::DropdownComponent`)

## Development

See [PLAN.md](PLAN.md) for the original implementation plan.
