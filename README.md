# rails-ui-kit

A Rails Engine that packages reusable UI components as paired ViewComponents and Stimulus controllers. Built for internal use across Product Matter client projects.

## Components

| Component | Stimulus Controller(s) | Description |
|---|---|---|
| `Ui::ModalComponent` | `ui--modal` | 8-position modal dialog with backdrop, form change tracking, Turbo Frame support |
| `Ui::DropdownComponent` | `ui--dropdown` | Accessible dropdown with Floating UI positioning, keyboard nav, 3 modes (menu/listbox/dialog) |
| `Ui::ConfirmDialogComponent` | `ui--dialog` | Native dialog with Promise-based API and global helper functions |
| `Ui::ToastComponent` | `ui--toast`, `ui--toast-container` | Auto-dismissing notifications with type-based styling and timer bar |

## Utility Controllers

| Controller | Description |
|---|---|
| `ui--form-change` | Dirty form tracking with custom events |
| `ui--turbo-confirm` | Replaces Turbo's `confirm()` with custom dialogs |
| `ui--turbo-disable-with` | Disables form elements during Turbo submission (text/spinner/pulse) |
| `ui--dark-mode` | Dark/light theme toggle with localStorage and OS preference |

## Installation

Add to your Gemfile:

```ruby
gem "rails_ui_kit", git: "git@github.com:productmatter/rails-ui-kit.git"
```

Register Stimulus controllers in your `application.js`:

```js
import { registerControllers } from "rails-ui-kit"
registerControllers(application)
```

Import component styles:

```css
@import "rails_ui_kit/components";
```

## Usage

```erb
<%= render Ui::ModalComponent.new(position: :right, close_on_backdrop: true) do %>
  <p>Modal content here</p>
<% end %>

<%= render Ui::DropdownComponent.new(placement: "bottom-end") do |dropdown| %>
  <% dropdown.with_trigger do %>
    <button>Open menu</button>
  <% end %>
  <% dropdown.with_menu do %>
    <a href="#">Option 1</a>
  <% end %>
<% end %>

<%= render Ui::ToastComponent.new(type: :success, message: "Saved!") %>
```

## Overriding

**ViewComponents:** Define the same component class in your app (e.g., `app/components/ui/modal_component.rb`) — it takes precedence automatically.

**Stimulus controllers:** Register your own controller with the same identifier after the gem's registration, or extend the gem's controller class.

**CSS:** Override with higher-specificity selectors, or skip the gem's stylesheet and write your own.

## Dependencies

- Rails >= 7.0
- [view_component](https://github.com/ViewComponent/view_component) >= 3.0
- [stimulus-rails](https://github.com/hotwired/stimulus-rails)
- [turbo-rails](https://github.com/hotwired/turbo-rails)
- [@floating-ui/dom](https://floating-ui.com/) (peer dependency for dropdown)

## Development

See [PLAN.md](PLAN.md) for the full implementation plan and architectural decisions.
