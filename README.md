# rails_ui_kit

The UI layer ProductMatter reaches for when a client's Rails app needs to exist quickly and look
like someone cared. It ships two kinds of thing, as ViewComponents paired with Stimulus
controllers:

- **Components that know Rails.** A Field built from a model reads its name, label, value,
  errors and required state from the record. A Select is built from an enum or a collection, and
  a group of checkboxes edits a `has_many` without losing data. A modal is opened, re-rendered
  and closed by Turbo Streams, and a confirmation answers `data-turbo-confirm`.
- **The browser behaviour that is hard to get right.** Focus trapping and return, scroll lock,
  anchored positioning, keyboard models, exit animations and ARIA semantics, built once and shared
  by every component that needs them.

That is also the rule for what gets in. A component has to do at least one of two things: own a
Rails or Turbo concept, or solve something genuinely hard in a browser. Anything that does
neither is markup with classes — you can write it in one line — so the kit doesn't ship it.

Colour, radius and control height come from CSS design tokens with shadcn/ui's names, so an app
themes the kit by redefining variables, not by overriding components.

## Components

| Component | Stimulus identifier | What it's for |
|---|---|---|
| `Ui::FieldComponent` | `ui--field` | A label, control, description and error as one accessible unit, built from `model:` and `attribute:` — name, id, label, value, errors and `required` all derived ([forms guide](docs/guides/forms.md)) |
| `Ui::SelectComponent` | `ui--select` | A real `<select>` that submits, built from a collection, an enum or options, mirrored into a WAI-ARIA combobox with keyboard support and optional search |
| `Ui::ChoicesComponent` | `ui--choices` | A radio or checkbox group over native inputs, with the names, ids and hidden field `collection_check_boxes` renders; `variant: :list` or `:card` |
| `Ui::InputComponent` | — | A native `<input>` on the tokens, sized from the shared control scale; in a form, render it through Field |
| `Ui::TextareaComponent` | — | A native `<textarea>`, styled and sized like Input |
| `Ui::LabelComponent` | — | A native `<label>`, dimmed when its control is disabled; Field renders one for you |
| `Ui::ButtonComponent` | — | Six variants × four sizes; renders `<a>` when given `href:`, and a disabled link is inert without JavaScript |
| `Ui::ModalComponent` | `ui--modal` | A modal dialog that opens when rendered, driven by Turbo Streams and Frames, with an unsaved-changes guard ([guide](docs/guides/modal-and-turbo.md)) |
| `Ui::DropdownComponent` | `ui--dropdown` | An anchored menu (`kind: :menu`, the WAI-ARIA menu button pattern) or panel (`kind: :dialog`) |
| `Ui::PopoverComponent` | `ui--popover` | A click-triggered anchored panel for rich content, closed by clicking outside or Escape |
| `Ui::TooltipComponent` | `ui--tooltip` | A text hint on hover and focus, exposed through `aria-describedby` |
| `Ui::ConfirmDialogComponent` | `ui--dialog` | A native `<dialog>` confirmation that returns a Promise, and answers every `data-turbo-confirm` |
| `Ui::ToastComponent` | `ui--toast` | An auto-dismissing notification, announced to screen readers, sendable from a Turbo Stream |
| `Ui::ToastContainerComponent` | `ui--toast-container` | The toast stack, which also renders toasts client-side from `window.triggerToast` |

## Controllers you use directly

| Identifier | What it's for |
|---|---|
| `ui--form-change` | Put it on a `<form>`: tracks unsaved changes and dispatches `ui--form-change:changed` and `ui--form-change:pristine` (the older `form:changed` / `form:pristine` still fire, and are deprecated). A modal with `track_changes: true` reads it |
| `ui--turbo-confirm` | Answers Turbo's `data-turbo-confirm` with the kit's confirm dialog. Render once per layout |
| `ui--turbo-disable-with` | Disables and relabels submit buttons marked `data-turbo-disable-with` while a form submits, with text, spinner or pulse styles. Render once per layout |
| `ui--dark-mode` | Toggles `.dark` on `<html>`, persisted and synced across tabs, with an OS-preference fallback |

## Primitives

The behaviour every overlay in the kit is built from, public so your own widgets can use it too.
The docs app's Primitives pages document each value and event.

| Identifier | What it does |
|---|---|
| `ui--overlay` | Top layer, focus trap and return (`moveFocus`, `initialFocus`, `restoreFocus`), reference-counted scroll lock, and a cancelable `ui--overlay:dismiss` event whose `detail.reason` says why |
| `ui--presence` | The open → closing → closed lifecycle, waiting for a real exit animation to finish |
| `ui--anchor` | Anchored positioning on Floating UI, publishing `data-side` and `data-align` |
| `ui--roving-focus` | Arrow keys, Home/End, `pageStep` and typeahead, with real focus or `aria-activedescendant` |

## Requirements

The kit's colour, radius and control heights come from CSS design tokens that only a Tailwind CSS 4
build can compile, so **Tailwind CSS 4 via `tailwindcss-rails` 4.x is required**. There is no
Tailwind 3, PostCSS or Sprockets path for the tokens: `rails_ui_kit/components.css` carries a
handful of modal animation classes and nothing else.

- Rails >= 7.2, Ruby >= 3.2
- Tailwind CSS 4 via tailwindcss-rails >= 4.0
- view_component >= 3.0, stimulus-rails, turbo-rails
- class_variants (the variant layer) and tailwind_merge (the class-merge layer)
- `@floating-ui/dom` >= 1.6. Dropdown, Popover, Tooltip and Select position with it, and the kit's
  JavaScript entry point always imports it. Importmap apps get it pinned by the engine; bundler
  apps install it (see [Alternative setups](#alternative-setups)).

## Quick start

The gem is private — it's not published to RubyGems or public npm. Install it from the GitHub
repository, pinned to a release tag, so an upgrade is a change you make on purpose.

1. **Add it to your Gemfile:**

   ```ruby
   gem "rails_ui_kit", git: "git@github.com:productmatter/rails-ui-kit.git", tag: "v0.3.0"
   ```

   Use `branch: "main"` instead of `tag:` only if you want unreleased work.

2. **`bundle install`**

3. **Run the install generator:**

   ```bash
   bin/rails generate rails_ui_kit:install
   ```

   This wires `app/javascript/application.js` and `app/assets/tailwind/application.css` for the
   importmap + Tailwind 4 path. It's idempotent — safe to re-run after upgrades.

4. **Paint the page from the tokens, and render the singletons once per layout** (e.g. in
   `app/views/layouts/application.html.erb`):

   ```erb
   <body class="bg-background text-foreground">
     <%= render Ui::ConfirmDialogComponent.new %>
     <%= render Ui::ToastContainerComponent.new %>
     <div data-controller="ui--turbo-confirm ui--turbo-disable-with"></div>
     <%# Where Turbo Streams open modals. data-turbo-permanent keeps an open one through a morph. %>
     <div id="modal" data-turbo-permanent></div>
     <%= yield %>
   </body>
   ```

   The kit paints no page colour of its own. Without `bg-background text-foreground` on
   `<body>`, the page keeps the browser's white under dark-mode components, and kit surfaces
   won't match the page around them.

That's it. The generator wires the registration wherever Stimulus's `application` constant
is actually in scope. On a default `rails new --javascript=importmap` app, that's
`app/javascript/controllers/application.js`, which will end up looking like:

```js
import { Application } from "@hotwired/stimulus"
import { registerControllers } from "rails-ui-kit"

const application = Application.start()
registerControllers(application)

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

export { application }
```

If your app calls `Application.start()` directly inside `app/javascript/application.js`
instead, the generator wires it there.

…and your `tailwind/application.css` will end with:

```css
@import "tailwindcss";
@import "../builds/tailwind/rails_ui_kit.css";
@custom-variant dark (&:where(.dark, .dark *));
```

The Tailwind build artifact is auto-generated by `tailwindcss-rails` 4.x via its `tailwindcss:engines` task (run before `tailwindcss:build`/`watch`). Don't create or commit it manually.

The `@custom-variant` line points Tailwind's own `dark:` utilities at the `.dark` class on
`<html>` — the same switch `ui--dark-mode` toggles and the kit's tokens follow. Without it
`dark:` follows the OS preference, so your utilities and the kit disagree about what dark
mode is. The generator writes it only when your stylesheet doesn't already define a dark
variant; if you have your own, make sure it matches `.dark`.

## Staying current

Move the `tag:` in your Gemfile to the new release, then:

```bash
bundle update rails_ui_kit
```

Bundler locks the git source to a commit SHA in `Gemfile.lock`, so apps don't silently drift on
redeploy. Commit the updated lockfile. Re-running `bin/rails generate rails_ui_kit:install` after
an upgrade is safe — it's a no-op when the wiring is already in place.

See [CHANGELOG.md](CHANGELOG.md) for what's in each version. If you hand-write any component
markup or Stimulus attributes rather than rendering the components, check
[UPGRADING.md](UPGRADING.md) too — it covers what breaks and the exact fix. (Both live in the
repository, not the packaged gem.)

## Private repo authentication

The Gemfile entry above uses SSH, which works on developer machines with an SSH key on GitHub.
CI and headless environments use HTTPS with a token:

```ruby
gem "rails_ui_kit", git: "https://github.com/productmatter/rails-ui-kit.git", tag: "v0.3.0"
```

Bundler honours `BUNDLE_GITHUB__COM=<token>:x-oauth-basic` (set in CI) to authenticate HTTPS git
sources. Use a fine-grained PAT or a deploy key with read access to the repo.

## Alternative setups

The Quick start covers the importmap + Tailwind 4 + `tailwindcss-rails` path. If your JavaScript is set up differently, follow one of the sections below — the install generator may skip files it doesn't recognise, in which case you can wire things up manually. The CSS path is the same for every setup: Tailwind 4 through `tailwindcss-rails`.

### JavaScript bundler (esbuild / webpack / rollup)

This covers JavaScript only — the CSS still comes from `tailwindcss-rails` as in the Quick start.
The package isn't published to public npm; install it from GitHub at the same tag as the gem, so
the Ruby and JavaScript halves match:

```bash
npm install @floating-ui/dom @hotwired/stimulus
npm install github:productmatter/rails-ui-kit#v0.3.0
```

Then in your JS entrypoint (e.g. `app/javascript/application.js`):

```js
import { Application } from "@hotwired/stimulus"
import { registerControllers } from "rails_ui_kit"

const application = Application.start()
registerControllers(application)
```

### Manual JS / CSS wiring (if the generator skipped)

The generator checks `app/javascript/application.js` and `app/javascript/controllers/application.js` (the default `rails new --javascript=importmap` location for Stimulus's `application`) for `Application.start()`. If neither has it — e.g. your entrypoint lives somewhere else — add the two lines yourself, wherever `application` is in scope:

```js
import { registerControllers } from "rails-ui-kit"
// after Application.start():
registerControllers(application)
```

If the generator skipped your `app/assets/tailwind/application.css`, add the import and the dark variant from the Quick start to whichever file is your Tailwind 4 entrypoint.

## Guides, and your coding agents

The kit ships its guides inside the gem, under `docs/guides/`:

- [`forms.md`](docs/guides/forms.md) — a form bound to its record: enums, `belongs_to`, a
  `has_many` edited as ids, nested attributes, the 422, the submitting state and testing.
- [`modal-and-turbo.md`](docs/guides/modal-and-turbo.md) — a modal, a modal form or any
  Turbo-driven overlay: opened by a stream, re-rendered in a frame, closed by the server.

Read the copy that matches the version your app has installed:

```bash
cat "$(bundle info --path rails_ui_kit)/docs/guides/forms.md"
```

To point your coding agents at them, opt in with:

```bash
bin/rails generate rails_ui_kit:agent_skill
```

It writes a Claude Code skill (`.claude/skills/rails-ui-kit/SKILL.md`) and one line in
`AGENTS.md` for other agents. Both point at the guides **in the installed gem** rather than
copying them, so `bundle update rails_ui_kit` updates what your agents read, with nothing to
re-run. `rails_ui_kit:install` never writes either.

## Usage

### A form

A form is `form_with` plus a Field per attribute, each bound to the record. This is a slice of the
forms guide's demo form, where every line is explained:

```erb title="examples/app/views/members/_form.html.erb"
<%= form_with model: member, class: "grid max-w-lg gap-6" do |form| %>
  <%# The record supplies the name, id, label, value, errors and required. %>
  <%= render Ui::FieldComponent.new(model: member, attribute: :name) %>

  <%# An enum: the options come from Member.statuses, their labels from human_attribute_name. %>
  <%= render Ui::FieldComponent.new(model: member, attribute: :status) do |field| %>
    <% field.with_control(Ui::SelectComponent, model: Member, enum: :status) %>
  <% end %>

  <%# belongs_to validates the association, so its error is on :team, not the :team_id this edits. %>
  <%= render Ui::FieldComponent.new(model: member, attribute: :team_id,
                                    errors: member.errors[:team_id] + member.errors[:team]) do |field| %>
    <% field.with_control(Ui::SelectComponent, collection: Team.all, value_method: :id, text_method: :name,
                          include_blank: "No team") %>
  <% end %>

  <%# has_many is validated as :roles and edited as :role_ids, so the Field is told which errors are its own. %>
  <%= render Ui::FieldComponent.new(model: member, attribute: :role_ids, required: true,
                                    errors: member.errors[:roles]) do |field| %>
    <% field.with_label { "Roles" } %>
    <% field.with_control(Ui::ChoicesComponent, multiple: true, collection: Role.all,
                          value_method: :id, text_method: :name, disabled_values: Role.locked_ids) %>
    <% field.with_description { "Owner is managed by billing and can't be changed here." } %>
  <% end %>
```

```erb title="examples/app/views/members/_form.html.erb"
  <div>
    <%= render(Ui::ButtonComponent.new(type: "submit", data: { turbo_disable_with: "Saving…",
                                                               turbo_disable_style: "spinner" })) { "Save" } %>
  </div>
```

The controller is the ordinary one, and an invalid save must answer
`render :edit, status: :unprocessable_entity` — Turbo won't render a `200` response to a form, so
the errors would never appear. The submit button disables itself and shows a spinner while the
request runs.

**A locked checkbox is not authorization.** `disabled_values:` renders a choice the user can't
change, and a checked one is carried by a hidden input so saving doesn't delete what the form
showed as checked. A hidden input can be removed or edited in the browser, and a disabled one
re-enabled: the server still decides what a user may change. Filter or merge locked values there
— the forms guide shows how.

### A modal

`Ui::ModalComponent` opens as soon as it's rendered. Put one inline in a page and it opens on every
page load, which is almost never what you want. Render it from a Turbo Stream instead, into the
layout's `<div id="modal">`:

```erb
<%# The trigger: data-turbo-stream asks for the Turbo Stream response %>
<%= link_to "Edit", edit_project_path(@project), id: dom_id(@project, :edit), data: { turbo_stream: true } %>
```

```erb title="examples/app/views/projects/edit.turbo_stream.erb"
<%= turbo_stream.update "modal" do %>
  <%= render Ui::ModalComponent.new(track_changes: true, aria: { labelledby: "project_modal_title" }) do %>
    <%= turbo_frame_tag "project_modal_content" do %>
      <%= render "projects/form", project: @project %>
    <% end %>
  <% end %>
<% end %>
```

The frame inside the modal lets a 422 or a show ↔ edit link swap the content without re-mounting
the dialog, and the server closes it on success with `turbo_stream.ui_close_modal`. Name every
modal (`aria: { labelledby: }`). `track_changes: true` asks before closing a form with unsaved
changes, which needs `data-controller="ui--form-change"` on the `<form>` itself.
[`modal-and-turbo.md`](docs/guides/modal-and-turbo.md) is the whole lifecycle, step by step.

### A dropdown menu

```erb
<%= render Ui::DropdownComponent.new(placement: "bottom-end") do |dropdown| %>
  <% dropdown.with_trigger do %>
    <button type="button" data-action="click->ui--dropdown#toggle">Open menu</button>
  <% end %>
  <% dropdown.with_menu do %>
    <a href="#" role="menuitem">Option 1</a>
    <a href="#" role="menuitem">Option 2</a>
  <% end %>
<% end %>
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

// Every part of the confirmation, in one spelling Ruby and JavaScript share:
const ok = await window.defaultConfirmDialog({
  title: "Publish this post?", message: "Readers will see it immediately.",
  confirm_label: "Publish", confirm_variant: "default"
})
```

Or via Turbo's `data-turbo-confirm` attribute (the `ui--turbo-confirm` controller intercepts it).
Each part travels as `data-turbo-confirm-` plus the option key, on the submit button, the form or
a `data-turbo-method` link:

```erb
<%= button_to "Delete", path, method: :delete,
    data: { turbo_confirm: "Are you sure?", turbo_confirm_title: "Delete account?" } %>

<%= button_to "Publish", publish_path(@post), method: :patch,
    data: { turbo_confirm: "Readers will see it immediately.", turbo_confirm_title: "Publish this post?",
            turbo_confirm_confirm_label: "Publish", turbo_confirm_confirm_variant: "default" } %>
```

A confirmation that names no variant gets the dialog's rendered default, which is destructive.
Nothing one confirmation sets leaks into the next.

## Confirm dialog theming

`Ui::ConfirmDialogComponent` renders a title, a message and two buttons. It renders **no icon**:
a glyph is content you add, in a slot. Every class option is merged onto the component's own
classes with `tailwind_merge`, so where your class and a default set the same property, yours
wins and the defaults you didn't contradict stay:

```ruby
Ui::ConfirmDialogComponent.new(
  confirm_variant: :default,   # :destructive (default), :default, :outline, :secondary, :ghost, :link
  confirm_label: "Publish",
  cancel_label: "Not yet",
  class: "...",                # merged onto the <dialog> itself
  wrapper_class: "...", body_class: "...", footer_class: "...",
  title_class: "...", message_class: "...",
  confirm_class: "...", cancel_class: "...", icon_wrapper_class: "..."
)
```

The confirm button is `Ui::ButtonComponent` at the variant you choose, and it defaults to
`:destructive`, because in a Rails app this one dialog answers every `data-turbo-confirm` and
those sit overwhelmingly on `destroy`. A confirmation that isn't destructive says so:
`confirm_variant: :default`.

An icon and rich body text are markup, so they come from a Ruby-rendered dialog — never through
JavaScript or a data attribute — and you open that dialog by id:

```erb
<%= render Ui::ConfirmDialogComponent.new(id: "archive-confirm", title: "Archive this project?",
      confirm_label: "Archive", confirm_variant: :default,
      icon_wrapper_class: "rounded-full bg-primary/10 text-primary") do |dialog| %>
  <% dialog.with_icon { render "icons/archive" } %>
  <% dialog.with_body { tag.p("Nothing is deleted, and you can restore it at any time.") } %>
<% end %>
```
```js
if (await window.customConfirmDialog("#archive-confirm")) { /* proceed */ }
```

Colour comes from the tokens (`--popover`, `--muted`, `--destructive`), so the dialog follows
your theme in light and dark without any class options at all.

## Dark mode

Apply the controller to an element that contains the toggle, and mark the button as its `toggle`
target — that's what gives it `aria-pressed` and a "Switch to dark mode" accessible name:

```erb
<div data-controller="ui--dark-mode">
  <button type="button"
          data-ui--dark-mode-target="toggle"
          data-action="click->ui--dark-mode#toggle">
    Toggle theme
  </button>
</div>
```

The controller persists the choice in `localStorage`, falls back to the OS preference on first
visit, and syncs across tabs. The docs app's Dark Mode page has the inline `<head>` script that
applies the theme before first paint.

## Testing

Checkboxes, radios, inputs and textareas are native, so Capybara's `check`, `choose` and `fill_in`
work on them unchanged. An enhanced Select isn't: its native `<select>` sits invisibly over the
combobox, so `select "Invited", from: "Status"` no longer picks what a user would. Include the
kit's helper in your system tests and use `ui_select`:

```ruby
# test/application_system_test_case.rb
require "rails_ui_kit/test_helpers"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome
  include RailsUiKit::TestHelpers
end

# In a test: from: is the Field label, the name the form posts, or the control's id.
ui_select "Invited", from: "Status"
```

It drives the combobox the way a person does, and falls back to the native select where the
component wasn't enhanced (JavaScript off, or the platform picker on a phone). The value still
lives in the native `<select>`, so assert it the way you always did.

## Overriding

One story, in three layers: **tokens** for how everything looks, **chrome strings** for what the
kit says, **class merging** for one component on one page. The docs app's **Theming** page (`/guides/theming`) shows
each of them live, with every token in light and dark.

**Tokens.** Components read colour, radius and control height from CSS variables that use
shadcn/ui's names verbatim, so a shadcn theme (a tweakcn export, for instance) drops in unchanged.
Redefine any of them and the cascade does the rest — no component override, no generator:

```css
@import "tailwindcss";
@import "../builds/tailwind/rails_ui_kit.css";

:root  { --primary: oklch(0.55 0.19 145); --radius: 0.375rem; }
.dark  { --primary: oklch(0.62 0.17 145); }
```

Import order doesn't matter: the kit ships its values in a sub-layer of Tailwind's `theme`
layer, the lowest-priority layer there is, so your `:root`/`.dark`, your `@layer base`, and
your own `@theme` all win over them wherever they sit in the file.

The full set is `background`/`foreground`, `card`, `popover`, `primary`, `secondary`, `muted`, `accent` (each with a `-foreground` pair), `destructive`, `border`, `input`, `ring`, `chart-1`…`chart-5`, `sidebar` and its variants, and `radius` — defined under `:root` and `.dark` in `app/assets/tailwind/rails_ui_kit/engine.css`. `ui--dark-mode` toggles the `.dark` class on `<html>`.

**Control heights** are tokens too. Button, Input, Select, Textarea and Choices share one `size:` scale — `:sm`, `:default`, `:lg` — and every control at a size reads its height from the same token: `--control-height-sm`, `--control-height` and `--control-height-lg`, which are 32, 36 and 40px at Tailwind's default spacing. Redefine them to make your app denser or roomier, and a row of controls at one size keeps lining up. These are kit extensions rather than shadcn names, so a shadcn theme that doesn't mention them leaves the kit's values in place. Each one is honoured wherever you set it, including on a single part of a page:

```css
:root       { --control-height-sm: 1.75rem; --control-height: 2rem; --control-height-lg: 2.25rem; }
.data-table { --control-height: 1.75rem; }
```

**Don't set a control height below 24px.** A control under 24 CSS pixels fails WCAG 2.5.8, Target Size (Minimum), so people with limited dexterity can't reliably hit it. The kit's own heights pass. It won't stop you setting a smaller one, the same way it won't stop you choosing an unreadable colour pair, so this one is on you.

**Chrome strings.** Two kinds of words, translated in two places.

*Content* — a field's label, a button's text, a select's options, a modal's title, a toast's message — is what your call site writes. You translate it the way you translate everything else, and **the kit ships no translation for it**. Field's model binding and Select's enum labels go through Rails' own `helpers.label` and `human_attribute_name` lookups, so your locale files are already what translate them.

*Chrome* is what the kit says on its own, that no call site writes: a toast's close-button accessible name, Select's "No results" and its result count, the unsaved-changes prompt. Those strings — several of them accessible names, the only thing a screen reader announces — live in `config/locales/rails_ui_kit.en.yml` under `rails_ui_kit.*`, which the engine loads automatically. The kit ships English; your own `config/locales` is loaded after every engine's, so your key wins:

```yaml
fr:
  rails_ui_kit:
    confirm_dialog:
      title: "Confirmation requise"
```

Each chrome string also takes a per-instance keyword named after the key's last segment, so one component can differ without changing the app: `Ui::ToastComponent.new(type: :info, message: "Saved", close_label: t(".dismiss"))`. The order is always *call site → your locale file → the kit's default*.

Stimulus controllers can't call `I18n.t`, so the component resolves the string in Ruby and renders it into the data attribute its controller reads — a per-instance override travels that same path. The English literal in a controller is only the fallback for hand-written markup that carries no attribute. Select's result count sends the whole plural map and the locale that rendered it, and the browser picks the form with `Intl.PluralRules`, so a language with six plural categories gets all six. The docs app's Internationalization page lists every key, its keyword and what renders it.

**Class merging.** Every component merges a `class:` you pass through `tailwind_merge`, so your utility replaces the component's conflicting default rather than racing it in stylesheet order:

```erb
<%# renders rounded-full, not rounded-md; the rest of the button's classes stay %>
<%= render(Ui::ButtonComponent.new(class: "rounded-full")) { "Follow" } %>
```

Reach for a token before a class: a class changes one instance, a token changes every component
that reads it, in both modes.

## Development

- [`docs/specs/`](docs/specs) — the product record: one spec per scope, starting with
  `ui-component-library`, whose rule 0 decides what the kit ships.
- [`AGENTS.md`](AGENTS.md) and [`CLAUDE.md`](CLAUDE.md) — how to work in this repo, for people and
  coding agents alike.
- Two test lanes. `bundle exec rake test` is browser-free: components, generators, the guides'
  drift checks. `bundle exec rake test:system` builds the docs app's CSS and drives the `examples/`
  app in headless Chrome, with axe accessibility checks. Run one file with
  `TEST=test/system/<file>_test.rb`.
- `examples/` is the docs app, and the demo every guide quotes: `cd examples && bin/dev`.
- [`RELEASING.md`](RELEASING.md) — how a release is cut and tagged.
