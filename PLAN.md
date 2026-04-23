# rails-ui-kit Implementation Plan

This gem packages reusable UI components as a Rails Engine, pairing ViewComponents with Stimulus controllers. Components are sourced from [rails-foundation](https://github.com/productmatter/rails-foundation) and generalized for use across client projects.

## Components

### Paired (ViewComponent + Stimulus Controller)

#### Modal (`Ui::ModalComponent` + `ui--modal`)
- Native `<dialog>` element with custom backdrop
- 8 position variants: center, full_screen, right, left, top, top_full, bottom, bottom_full
- Unsaved form change tracking (integrates with `form_change_controller`)
- Configurable backdrop close behavior
- Custom max-width support
- Position-specific keyframe animations (shipped as gem CSS)
- Auto-opens on Turbo Frame connection for dynamic loading

**Source files:**
- `app/components/ui/modal_component.rb`
- `app/components/ui/modal_component.html.erb`
- `app/javascript/controllers/modal_controller.js`
- CSS: modal keyframe animations and transform state classes

#### Dropdown (`Ui::DropdownComponent` + `ui--dropdown`)
- Floating UI for intelligent positioning with flip/shift
- Three accessibility modes: menu, listbox, dialog
- Full keyboard navigation (arrows, Home, End, Tab)
- Click-outside-to-close
- Configurable placement, offset, and width matching
- ARIA haspopup/expanded attributes

**Source files:**
- `app/components/ui/dropdown_component.rb`
- `app/components/ui/dropdown_component.html.erb`
- `app/javascript/controllers/dropdown_controller.js`

**External dependency:** `@floating-ui/dom`

#### Confirm Dialog (`Ui::ConfirmDialogComponent` + `ui--dialog`)
- Native `<dialog>` with Promise-based API
- Global `window.defaultConfirmDialog()` and `window.customConfirmDialog()` functions
- Supports string or object options (title + message)
- Works standalone or paired with `turbo_confirm_controller` to replace Turbo's default `confirm()`

**Source files:**
- `app/components/ui/confirm_dialog_component.rb`
- `app/components/ui/confirm_dialog_component.html.erb`
- `app/javascript/controllers/dialog_controller.js`

#### Toast (`Ui::ToastComponent` + `ui--toast` / `ui--toast-container`)
- Types: success, error, notice, alert, info
- Auto-dismiss with configurable timeout and timer bar
- Configurable enter/leave CSS class transitions
- Container controller manages the toast stack
- Global `window.triggerToast(type, message)` function
- Supports title + body messages

**Source files:**
- `app/components/ui/toast_component.rb`
- `app/components/ui/toast_component.html.erb`
- `app/javascript/controllers/toast_controller.js`
- `app/javascript/controllers/toast_container_controller.js`

**Note:** The toast container controller currently fetches toasts from a server endpoint (`/toasts/create`). This needs to be generalized — either the gem ships a route/controller for this, or the container controller is reworked to render toasts client-side without a server round-trip.

### Utility Controllers (Stimulus only, no ViewComponent)

#### Form Change (`ui--form-change`)
- Tracks form field modifications via input/change events
- Dispatches `form:changed` and `form:pristine` custom events
- Compares FormData snapshots to detect actual changes
- Resets on successful Turbo submission or form reset
- Companion to modal's `trackChanges` option

**Source:** `app/javascript/controllers/form_change_controller.js`

#### Turbo Confirm (`ui--turbo-confirm`)
- Replaces `Turbo.config.forms.confirm` with custom dialog
- Reads `data-turbo-confirm` and `data-turbo-confirm-title` attributes
- Falls back to browser `confirm()` if dialog controller unavailable
- Requires `Ui::ConfirmDialogComponent` to be rendered on the page

**Source:** `app/javascript/controllers/turbo_confirm_controller.js`

#### Turbo Disable With (`ui--turbo-disable-with`)
- Disables form elements during Turbo submission
- Three styles: text replacement (default), spinner, pulse
- Preserves and restores element state via WeakMap
- Screen reader announcements via ARIA live region
- Replaces Rails UJS `data-disable-with` for Turbo apps

**Source:** `app/javascript/controllers/turbo_disable_with_controller.js`

#### Dark Mode (`ui--dark-mode`)
- Toggles `.dark` class on `document.documentElement`
- Persists preference to localStorage
- Respects OS system preference on first visit
- Syncs across browser tabs via storage events
- Updates toggle button `aria-label`

**Source:** `app/javascript/controllers/dark_mode_controller.js`

---

## Gem Structure

```
rails-ui-kit/
├── rails_ui_kit.gemspec
├── Gemfile
├── lib/
│   ├── rails_ui_kit.rb                    # Gem entry point
│   └── rails_ui_kit/
│       ├── version.rb
│       └── engine.rb                      # Rails::Engine subclass
├── app/
│   ├── components/
│   │   └── ui/
│   │       ├── modal_component.rb
│   │       ├── modal_component.html.erb
│   │       ├── dropdown_component.rb
│   │       ├── dropdown_component.html.erb
│   │       ├── confirm_dialog_component.rb
│   │       ├── confirm_dialog_component.html.erb
│   │       ├── toast_component.rb
│   │       └── toast_component.html.erb
│   └── assets/
│       └── stylesheets/
│           └── rails_ui_kit/
│               └── components.css         # Modal keyframes + transform states
├── app/javascript/
│   └── rails_ui_kit/
│       ├── index.js                       # Controller registration entry point
│       └── controllers/
│           ├── modal_controller.js
│           ├── dropdown_controller.js
│           ├── dialog_controller.js
│           ├── toast_controller.js
│           ├── toast_container_controller.js
│           ├── form_change_controller.js
│           ├── turbo_confirm_controller.js
│           ├── turbo_disable_with_controller.js
│           └── dark_mode_controller.js
└── test/ or spec/
```

## Implementation Steps

### Phase 1: Gem Skeleton

1. Create the gemspec with dependencies:
   - `rails` (>= 7.0)
   - `view_component` (>= 3.0)
   - `stimulus-rails`
   - `turbo-rails`
2. Create `lib/rails_ui_kit.rb` and `lib/rails_ui_kit/version.rb`
3. Create the Rails Engine (`lib/rails_ui_kit/engine.rb`):
   - Append component paths to `ViewComponent::Engine.config.view_component.component_dirs` or use `config.autoload_paths`
   - The engine isolates under `RailsUiKit` module but components use the `Ui::` namespace (not engine-namespaced)
4. Initialize git-treeline (`gtl init`)

### Phase 2: Port Components

For each of the 4 paired components:

1. Copy the ViewComponent Ruby class and ERB template from rails-foundation
2. Remove any app-specific references (e.g., `golfshopos:toast` event name → generic event name)
3. Update Stimulus controller references to use `ui--` prefix (e.g., `data-controller="ui--modal"`)
4. Ensure component classes are within the `Ui::` module

**Generalization notes:**
- `toast_container_controller.js` references a server endpoint `/toasts/create` and a `golfshopos:toast` event — both need to be made generic. Options: (a) ship a mountable route from the engine, or (b) rework to render toasts entirely client-side using a template approach. Client-side rendering is preferred to avoid requiring a route mount.
- `confirm_dialog_component.html.erb` has hardcoded dark theme colors (gray-800) — consider making this themeable or at minimum ensuring it respects dark mode classes.
- `dropdown_controller.js` imports from `@floating-ui/dom` — document this as a peer dependency.

### Phase 3: Port Stimulus Controllers

1. Copy all 8 controllers (4 component controllers + 4 utility controllers)
2. Place under `app/javascript/rails_ui_kit/controllers/`
3. Create `app/javascript/rails_ui_kit/index.js` that exports a registration function:
   ```js
   // Consumer calls this in their application.js:
   // import { registerControllers } from "rails-ui-kit"
   // registerControllers(application)
   ```
4. Each controller registers with the `ui--` prefix

### Phase 4: CSS / Assets

1. Extract modal keyframe animations and transform state classes from rails-foundation's `application.css` into `app/assets/stylesheets/rails_ui_kit/components.css`
2. Only include CSS that the gem's components require — no app-level styles
3. Document how consumers import:
   - Tailwind/PostCSS: `@import "rails_ui_kit/components";`
   - Sprockets: `//= require rails_ui_kit/components`

### Phase 5: JavaScript Distribution

Support both importmap and bundler setups:

**Importmap:**
- The engine's initializer pins the controllers:
  ```ruby
  initializer "rails_ui_kit.importmap" do
    # pin controllers for importmap users
  end
  ```

**Bundler (esbuild/webpack):**
- `package.json` at gem root with entry point
- Consumers import and register in their JS entry point

### Phase 6: Consumer Installation & Documentation

Document the setup steps for consuming apps:

1. Add gem to Gemfile: `gem "rails_ui_kit", git: "git@github.com:productmatter/rails-ui-kit.git"`
2. Import and register Stimulus controllers
3. Import component CSS
4. Render components: `render Ui::ModalComponent.new(position: :right) { ... }`

Document overriding:
- **ViewComponent override:** Define `app/components/ui/modal_component.rb` in the consuming app — it takes precedence automatically
- **Stimulus override:** Register your own controller with the same `ui--modal` identifier after the gem's registration, or extend the gem's controller class
- **CSS override:** The gem's CSS uses standard classes; override with higher-specificity selectors or by not importing the gem's stylesheet and writing your own

### Phase 7: Testing

1. Unit tests for each ViewComponent (renders correctly, accepts options, etc.)
2. Stimulus controller tests (if feasible — consider using `@hotwired/stimulus/testing`)
3. A test/dummy Rails app inside the gem for integration testing
4. CI setup

---

## Decisions to Make During Implementation

1. **Toast server dependency:** The toast container currently fetches from a server endpoint. Decide whether to ship a mountable controller or rework to client-side rendering.
2. **Floating UI:** Decide whether to vendor `@floating-ui/dom` or treat it as a peer dependency the consuming app must provide.
3. **Confirm dialog styling:** The current component has hardcoded Tailwind classes. Decide if this is fine (consumers override the template if they want different styling) or if it should accept style configuration.
4. **Dark mode scope:** Confirm this controller is generic enough as-is or needs any app-specific logic removed.
5. **Minimum Rails/Ruby versions:** Confirm targets (suggested: Rails >= 7.0, Ruby >= 3.1).

## Explicitly Excluded

These exist in rails-foundation but are **not** included in this gem:

- `SidebarComponent` / `sidebar_controller` — too app-specific (navigation structure varies per project)
- `mobile_nav_controller` — overlaps with sidebar, app-specific
- `search_controller` — trivial (debounced submit), easy to inline
- Layout components (`ApplicationShellComponent`, `TopHeaderComponent`, `PageHeaderComponent`, etc.) — structural, not reusable UI elements
