# Upgrading

This covers everything between v0.2.0 and v0.3.0. It reports findings,
not predictions: this branch was tested against a real consuming app before this was written,
and the two failures below (§1, §2) are exactly what that test found — one of them silent. §4 and
§5 are visible changes to the confirm dialog, not failures: nothing errors except a removed
keyword. §6 and §7 change what a toast shows for the same call.

**Headline: run `bundle update`, then fix seven things.** Most of the CHANGELOG's 0.3.0
section is new components, bug fixes, and internal refactors that need nothing from you. This
file is only the part that touches a hand-rolled app.

## 1. Toasts stop being announced (silent)

If your app renders its own toast container markup instead of `Ui::ToastContainerComponent`,
toasts still show but nothing tells a screen reader they arrived — `Ui::ToastComponent` no
longer carries `role`/`aria-live` itself; the container's two persistent live regions
(`role="status"`/`aria-live="polite"` and `role="alert"`/`aria-live="assertive"`) do the
announcing now, and a hand-rolled container doesn't have them.

This is now loud in dev: the console warns once per container, naming the fix. It was silent
before that warning was added.

**Fix:** render `Ui::ToastContainerComponent` instead of copy-pasted container markup.

## 2. Hand-written overlay markup stops working (loud)

This applies only if you write Modal, Dropdown, Popover or Tooltip markup by hand instead of
rendering the component. It also applies to markup copied from 0.2.0's output. A rendered
component needs nothing here except [the options below](#if-you-render-the-components). All four
now run on shared controllers: `ui--overlay` opens, closes and dismisses them, and `ui--anchor`
positions the three that float. 0.2.0 markup names neither. Verbatim 0.2.0 markup, run on this
release:

| Component | What 0.2.0 markup does now |
|---|---|
| Modal | Never opens. The console warns `no "ui--overlay" controller found`. |
| Dropdown | Never opens. The console warns `no "ui--overlay" controller found`. |
| Popover | Never opens. The console warns `no "ui--overlay" controller found`. |
| Tooltip | Never shows. The console errors `Action "mouseenter->ui--tooltip#show" references undefined method "show"`. |

**The fix is to render the component.** Where you can't, replace the markup with the "after"
block below. Each one is the component's own output, so every `data-*` attribute in it is
load-bearing. Long class lists are shortened to `…` where they only style; the full lists are in
`app/components/ui/*_component.rb`. In all four, the content is shown by removing its `hidden`
**attribute**. A 0.2.0 `hidden` **class** left on it keeps it `display: none` after it opens, so
delete the class.

### Modal

Before (0.2.0):

```html
<div data-controller="ui--modal"
     data-ui--modal-position-value="center"
     data-ui--modal-track-changes-value="false"
     data-ui--modal-close-on-backdrop-value="true"
     data-action="click->ui--modal#closeOnBackdropClick keydown->ui--modal#closeOnEscape">
  <div data-ui--modal-target="backdrop" class="fixed inset-0 bg-black/50 … z-[60]"
       data-action="click->ui--modal#closeOnBackdropClick"></div>
  <dialog data-ui--modal-target="dialog" class="…">…</dialog>
</div>
```

After:

```html
<div data-controller="ui--modal ui--overlay"
     data-ui--modal-track-changes-value="false"
     data-ui--modal-close-on-backdrop-value="true"
     data-ui--overlay-mode-value="modal"
     data-ui--overlay-open-value="true"
     data-ui--overlay-scroll-lock-value="true"
     data-action="ui--overlay:dismiss->ui--modal#guardDismiss:self ui--overlay:closed->ui--modal#remove:self">
  <dialog data-slot="modal" data-ui--overlay-target="content" aria-labelledby="modal-title"
          class="fixed p-0 m-0 … modal-center-hidden …">…</dialog>
</div>
```

- **`ui--overlay` is required.** Add it to `data-controller`, with `-mode-value="modal"`,
  `-open-value="true"` (the modal opens as soon as it's rendered) and `-scroll-lock-value="true"`.
- **The two actions replace `closeOnBackdropClick` and `closeOnEscape`, which are gone.** Without
  `guardDismiss`, Escape and the backdrop close the modal without honouring `close_on_backdrop`
  or asking about unsaved changes. Without `remove`, a closed modal is never taken off the page.
  `ui--modal#close` still works.
- **`data-ui--modal-target="dialog"` is now `data-ui--overlay-target="content"`.**
- **The backdrop `<div>` is gone.** The browser's native `::backdrop` draws it, and the
  `z-[60]`/`z-[61]` literals went with it.
- **`data-ui--modal-position-value` is gone.** The position is now only the
  `modal-<position>-hidden` class, which replaces 0.2.0's `modal-<position>-visible`. The CSS draws
  the hidden state and reveals it on `[data-state="open"]`.
- **The prompt is optional.** Set `data-ui--modal-unsaved-changes-title-value` and
  `-message-value` to translate the unsaved-changes prompt; without them it's English.

### Dropdown

Before (0.2.0):

```html
<div data-controller="ui--dropdown" data-ui--dropdown-kind-value="menu"
     data-ui--dropdown-placement-value="bottom-start" data-ui--dropdown-offset-value="4"
     data-ui--dropdown-match-width-value="false">
  <div data-ui--dropdown-target="trigger">
    <button type="button" data-action="click->ui--dropdown#toggle">Actions</button>
  </div>
  <div data-ui--dropdown-target="content" role="menu"
       class="hidden absolute z-50 opacity-0 scale-95 transition duration-100 ease-out origin-top">…</div>
</div>
```

After:

```html
<div data-slot="dropdown" data-controller="ui--dropdown ui--overlay ui--anchor"
     data-ui--dropdown-kind-value="menu"
     data-ui--overlay-mode-value="layer" data-ui--overlay-move-focus-value="false"
     data-ui--anchor-placement-value="bottom-start" data-ui--anchor-offset-value="4"
     data-ui--anchor-match-width-value="false" data-ui--anchor-strategy-value="fixed">
  <div data-slot="dropdown-trigger" data-ui--dropdown-target="trigger" data-ui--overlay-target="trigger" data-ui--anchor-target="anchor">
    <button type="button">Actions</button>
  </div>
  <div data-slot="dropdown-panel" role="menu" hidden
       data-ui--dropdown-target="content" data-ui--overlay-target="content" data-ui--anchor-target="floating"
       data-controller="ui--roving-focus" data-ui--roving-focus-typeahead-value="true"
       class="overflow-visible outline-none bg-popover border rounded-md shadow-lg transition duration-100 ease-out origin-top
              data-[state=closed]:opacity-0 data-[state=closed]:scale-95 data-[state=closing]:opacity-0 data-[state=closing]:scale-95">…</div>
</div>
```

- **`ui--overlay` and `ui--anchor` are both required.** Add each to `data-controller`, and give
  the trigger and panel their `ui--overlay`/`ui--anchor` targets. For
  `data-ui--dropdown-kind-value="dialog"`, leave `ui--roving-focus` off the panel, and give the
  panel `role="dialog"` and an `aria-label`.
- **The positioning attributes moved to `ui--anchor`:**

  | Old (on `ui--dropdown`) | New (on `ui--anchor`) |
  |---|---|
  | `data-ui--dropdown-placement-value` | `data-ui--anchor-placement-value` |
  | `data-ui--dropdown-offset-value` | `data-ui--anchor-offset-value` |
  | `data-ui--dropdown-match-width-value` | `data-ui--anchor-match-width-value` |

  Dropdown copies an old attribute onto its new name and warns. That only helps on an element
  that already has `ui--anchor`, and an `ui--anchor-*` value you set yourself wins. Migrate.
- **`data-ui--anchor-strategy-value="fixed"`** is needed because the panel now opens in the
  browser's top layer, positioned against the viewport.
- **The trigger binds itself.** A leftover `click->ui--dropdown#toggle` does no harm: one click
  still toggles once.
- **`data-ui--dropdown-open-value` is gone.** Open state is `data-ui--overlay-open-value`. The
  `toggle`, `open` and `close` actions remain.
- **Dropdown now emits `ui--overlay:opened`, `ui--overlay:closed` and the cancelable
  `ui--overlay:dismiss`** from its root element, like every other overlay.

### Popover

Before (0.2.0):

```html
<div data-controller="ui--popover" data-ui--popover-placement-value="bottom" data-ui--popover-offset-value="8">
  <div data-ui--popover-target="trigger" data-action="click->ui--popover#toggle">
    <button type="button">Open</button>
  </div>
  <div data-ui--popover-target="content" class="absolute z-50 hidden opacity-0 scale-95 …">…</div>
</div>
```

After:

```html
<div data-slot="popover" data-controller="ui--popover ui--overlay ui--anchor"
     data-ui--overlay-mode-value="layer"
     data-ui--anchor-placement-value="bottom" data-ui--anchor-offset-value="8" data-ui--anchor-strategy-value="fixed">
  <div data-slot="popover-trigger" data-ui--popover-target="trigger" data-ui--overlay-target="trigger" data-ui--anchor-target="anchor">
    <button type="button">Open</button>
  </div>
  <div data-slot="popover-panel" hidden
       data-ui--popover-target="content" data-ui--overlay-target="content" data-ui--anchor-target="floating"
       class="overflow-visible text-inherit outline-none bg-popover border rounded-lg shadow-lg transition duration-100 ease-out origin-top
              data-[state=closed]:opacity-0 data-[state=closed]:scale-95 data-[state=closing]:opacity-0 data-[state=closing]:scale-95">…</div>
</div>
```

- **`ui--overlay` and `ui--anchor` are both required,** with the targets shown.
- **`data-ui--popover-placement-value` and `-offset-value` are ignored without a warning.** They
  are not forwarded, so a panel still carrying them opens at `bottom`, 8px away. Use the
  `ui--anchor` names.
- **`data-ui--popover-open-value` is gone.** State lives in `ui--overlay`.
- **The trigger binds itself, to the button inside the trigger target,** so clicking the wrapper
  beside the button doesn't toggle. Remove the wrapper's `click->ui--popover#toggle`: left in
  place, one click still toggles once, but the wrapper becomes a toggle again.
- **Escape now closes a Popover from anywhere on the page,** not only when focus is inside it.
  The panel is in the browser's top layer, which gives Escape to whatever's topmost.

### Tooltip

Before (0.2.0):

```html
<div data-controller="ui--tooltip" data-ui--tooltip-placement-value="top" data-ui--tooltip-offset-value="6"
     data-action="mouseenter->ui--tooltip#show mouseleave->ui--tooltip#hide focusin->ui--tooltip#show focusout->ui--tooltip#hide">
  <div data-ui--tooltip-target="trigger"><button type="button">Save</button></div>
  <div data-ui--tooltip-target="content" class="absolute z-50 hidden opacity-0 … pointer-events-none whitespace-nowrap">Save changes</div>
</div>
```

After:

```html
<div data-slot="tooltip" data-controller="ui--tooltip ui--overlay ui--anchor"
     data-ui--overlay-mode-value="hint" data-ui--overlay-restore-focus-value="false"
     data-ui--anchor-placement-value="top" data-ui--anchor-offset-value="6" data-ui--anchor-strategy-value="fixed">
  <div data-slot="tooltip-trigger" data-ui--tooltip-target="trigger" data-ui--anchor-target="anchor"><button type="button">Save</button></div>
  <div data-slot="tooltip-content" hidden data-ui--tooltip-target="content" data-ui--overlay-target="content" data-ui--anchor-target="floating"
       class="overflow-visible px-2 py-1 text-xs font-medium rounded shadow-sm bg-foreground text-background max-w-xs text-pretty
              transition-opacity duration-100 ease-out data-[state=closed]:opacity-0 data-[state=closing]:opacity-0">
    Save changes
    <div data-slot="tooltip-arrow" data-ui--anchor-target="arrow" class="absolute h-2 w-2 rotate-45 bg-foreground"></div>
  </div>
</div>
```

- **Delete the root's `data-action`.** `show` and `hide` no longer exist, which is the error in
  the table. Tooltip binds hover and focus to the button itself.
- **`ui--overlay` and `ui--anchor` are both required,** with the targets shown. The arrow is
  optional.
- **`data-ui--tooltip-placement-value` and `-offset-value` are ignored without a warning.** Use
  the `ui--anchor` names.
- **Drop `pointer-events-none`.** The pointer must be able to move onto a tooltip without it
  vanishing (WCAG 1.4.13).

### If you render the components

- **`class:` now works on all four.** It merges through tailwind_merge onto Modal's `<dialog>`,
  and onto the root element of Dropdown, Popover and Tooltip. Forwarded `data:`/`aria:` land on
  the same element. Your `data: { action: }` and `data: { controller: }` join the component's
  own rather than replacing them.
- **Four ways to pass classes are deprecated.** Each one still works, now merged rather than
  replacing. Each warns through Rails' deprecation config (`RailsUiKit.deprecator`), and each is
  removed in 0.4.0:

  | Deprecated | Use | Note |
  |---|---|---|
  | Modal `max_width:` | `class:` | It used to replace the default width; merged, the default `sm:max-w-[42rem]` still caps it. To widen, pass `class: "sm:w-[48rem] sm:max-w-[48rem]"`. |
  | Popover `panel_classes:` | `with_panel(class:)` | |
  | Dropdown `content_classes:` | `with_panel(class:)` | |
  | Dropdown `with_menu` | `with_panel` | Same block, and it takes `class:`. |

- **Dropdown's panel now draws its own surface:** `bg-popover`, `border`, `rounded-md`,
  `shadow-lg`. It's in the top layer, where the browser would otherwise paint its default popover
  background. If your `content_classes:` or your slot's outer `<div>` drew a surface, you now have
  two borders. Drop yours, or override the panel's with `with_panel(class:)`.
- **An unrecognised `*_class:` or `*_classes:` keyword raises.** Any component raises
  `ArgumentError` in development and test, and logs and ignores the keyword in production. Before,
  it rendered as a meaningless HTML attribute.
- **A value outside a closed set raises.** Modal `position:`, Dropdown `kind:` and `placement:`
  on Dropdown, Popover and Tooltip raise `Ui::Base::UnknownVariantError` in development and test.
  In production they log a warning and fall back to the default. The removed `kind: :listbox` is
  one such value: it used to render a menu without a word. Symbols work alongside strings, so
  `placement: :bottom_start` is `"bottom-start"`. On Popover and Tooltip a symbol placement used
  to fall back to the default silently.

## 3. Colour drift if your app defines no tokens

Every component reads colour from a fixed set of CSS variables (shadcn/ui's names, Product
Matter's values) rather than hard-coded Tailwind classes. If your app never defined them, you
were getting the kit's own palette — a warm neutral ramp with one indigo accent — sitting next
to whatever your app's Tailwind config uses everywhere else. Upgrading doesn't change this, but
it's the point in an upgrade where a drift nobody fixed becomes visible again.

**Fix:** redefine the token names in your app's CSS, mapped onto your existing palette. Tailwind
v4 exposes your theme's colors as CSS variables, so if you already have a Tailwind palette this
is a re-mapping, not new color decisions:

```css
@import "tailwindcss";
@import "../builds/tailwind/rails_ui_kit.css";

:root {
  --primary: var(--color-blue-600);
  --primary-foreground: var(--color-white);
  --destructive: var(--color-red-600);
  --ring: var(--color-blue-600);
  /* ...and so on for the rest of the set your app actually touches */
}
.dark {
  --primary: var(--color-blue-400);
}
```

The full token list and how the layering works is in README's [Overriding](README.md#overriding)
section. Import order doesn't matter — the kit's values sit in a sub-layer of Tailwind's lowest
layer, so your definitions win wherever they are.

## 4. The confirm dialog no longer shows a warning icon (visible, not loud)

`Ui::ConfirmDialogComponent` no longer renders the red warning triangle. Its default is a title,
a message and the two buttons. The confirm button is still destructive red by default. A dialog
that isn't confirming something destructive can now say so with `confirm_variant: :default`, or
`data-turbo-confirm-confirm-variant="default"`.

**To get an icon back,** render it as content. This restores the 0.2.0 look:

```erb
<%= render Ui::ConfirmDialogComponent.new(icon_wrapper_class: "rounded-full bg-destructive/10 text-destructive") do |dialog| %>
  <% dialog.with_icon do %>
    <svg class="size-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
    </svg>
  <% end %>
<% end %>
```

The icon shows on every confirmation that dialog opens, from JavaScript and Turbo too. An icon
can't be passed through JavaScript.

## 5. Confirm dialog class options add to the defaults instead of replacing them (visible, one loud)

`wrapper_class:`, `body_class:`, `footer_class:`, `title_class:`, `message_class:`,
`confirm_class:`, `cancel_class:` and `icon_wrapper_class:` used to replace the component's
classes. They're now merged on top: where your class and a default set the same property, yours
wins, and the defaults you didn't contradict stay. If you passed a complete class string, the
result is usually what you had. **The one difference:** if you relied on replacing a default
wholesale, the default utilities your classes don't conflict with come back. Your
`wrapper_class: "rounded-none"` still removes the radius, but the token background and shadow you
didn't mention now render. To drop one, pass a class that sets the same property (`shadow-none`,
`bg-transparent`). `icon_class:` is removed and raises `ArgumentError`. Style your icon inside the
`icon` slot.

```bash
grep -rn 'ConfirmDialogComponent.new' app/ | grep '_class:'
grep -rn 'icon_class:' app/ | grep -i confirm
```

## 6. A toast's plain message is now its description, not its title (visible, not loud)

`Ui::ToastComponent.new(type: :success, message: "Saved")`,
`window.triggerToast("success", "Saved")` and a `rails-ui-kit:toast` event whose
`message` is a string used to render "Saved" as the toast's bold title. It is now the
description: regular weight, and in the main text colour when there's no title. Nothing
errors, and a screen reader hears the same words.

**To keep the old look,** name it a title: `message: { title: "Saved" }` or
`triggerToast("success", { title: "Saved" })`.

**Renamed, loud in development:** `body:` is `description:` and `timeout:` is
`duration:` (`duration: 0` still persists). In development and test the old keys raise,
or throw in JavaScript, naming the new one. In production they still work and log a
warning.

**In your tests,** `data-ui--toast-target="body"` is now `description`, and a
string toast's text is in `description`, not `title`.

**Also:** a `notice` toast is now the success colour with a check glyph, not amber, because `notice` is
Rails' "it worked" message in every scaffold and Devise flow; pass `type: :warning` if you want amber.
An `alert` toast is now the destructive colour, not orange. A toast with an
action stays until it's dismissed. `container_class:` now adds to the container's
classes instead of replacing them. An unknown `type:` now raises in development and test,
as an unknown variant does, instead of quietly rendering `info`. A toast sent by Turbo Stream
should use `turbo_stream.ui_toast`: the old `turbo_stream.append "body"` recipe targets an
element id, finds none, and shows nothing. And `render Ui::ToastContainerComponent.new(flash: flash)`
now turns Rails' own `notice:` and `alert:` into toasts, so you can delete a hand-written flash
partial.

```bash
grep -rn 'triggerToast\|ToastComponent.new\|rails-ui-kit:toast' app/ | grep -v 'title'
grep -rn 'body:\|timeout:' app/ | grep -i toast
grep -rn 'ui--toast-target="\(title\|body\)"' app/ test/ spec/
grep -rn 'turbo_stream.append "body"' app/
```

## 7. A toast message that is an I18n key name is no longer translated (visible, not loud)

In 0.2.0 a `message:` String that happened to be an I18n key was looked up, so
`message: "date"` rendered blank and `message: "number.currency.format.unit"` rendered `$`.
A String is now always the text it says. **If you passed key names as strings on purpose,
pass a Symbol:** `message: :"toasts.saved"` instead of `message: "toasts.saved"`. A Symbol's
translation is used as before: a String translation is the description, a Hash translation a
whole payload.

```bash
grep -rn 'ToastComponent.new' app/ | grep 'message: "[a-z_]*\.[a-z_.]*"'
```

## Also worth knowing

**`Ui::DropdownComponent(kind: :listbox)` is gone.** It had no real selection model and moved
focus onto `[role="option"]` elements, which a listbox must never do. Replace it with
`Ui::SelectComponent`, which keeps the value in a real `<select>` and follows the WAI-ARIA
combobox focus model. Dropdown's `:menu` and `:dialog` are unaffected.

**Dark mode's storage key moved to `rails_ui_kit:theme`.** The generic `theme` key collided
with hosts that store their own value there (a host storing `"system"` was forced to light).
The controller still reads the old key when the new one is unset, so a user's saved preference
survives. But if you copied the no-flash `<head>` script from the Dark Mode docs page, it reads
the key directly: update it to read `rails_ui_kit:theme` (falling back to `theme`), or users get
a flash of the wrong theme after their next toggle.

**`stylesheet_link_tag :app` is replaced on install.** tailwindcss-rails' engine convention
writes a stub into `app/assets/builds/tailwind/` that is a Tailwind *input*, not a stylesheet to
serve; `:app` links every build file, so the browser requested the stub's absolute `@import`
path and logged a 500 on every page. `rails_ui_kit:install` now rewrites `:app` to the
stylesheets it was linking, by name (`"application", "tailwind"` on a fresh 8.1 app). A
stylesheet you add later has to be added to that line by hand. `:all` has the same problem and
is not rewritten.

**Your existing Capybara `select` calls are unaffected — until you adopt `Ui::SelectComponent`.**
An enhanced Select hides its native `<select>` under a custom combobox, so `select "X", from: "Y"`
no longer picks what a user would. The kit ships a helper for that case: `require
"rails_ui_kit/test_helpers"`, include `RailsUiKit::TestHelpers`, and use `ui_select "X", from: "Y"`.
It also drives a plain `<select>`, so one call covers both.

**ConfirmDialog**: `Ui::ConfirmDialogComponent` now renders Cancel before Confirm (previously
Confirm first), with `footer_class`, `confirm_class` and `cancel_class` changed to match. If you
override any of those three, or relied on `sm:flex-row-reverse` / the old button margins, check
the layout. Both buttons are now `Ui::ButtonComponent`, so they carry its height, padding and
focus ring; the dialog's panel now fills the width of a phone screen instead of shrinking to its
text. See §4 and §5 for the icon and the class options.

**Boolean attributes — a bug fix, not a style change.** `disabled: "false"` (and the same for
`readonly`, `required`, `checked`, `selected`, `multiple`, `hidden`, `open`) used to render as
disabled, because Rails treats any non-empty string as truthy. It's now correctly treated as
false. If anything in your app passed a stringified `"false"` expecting the old (wrong)
behavior — e.g. `disabled: some_boolean_column.to_s` from a form param or serialized value — it
will now render enabled. `aria-*` and `data-*` are untouched; `aria-invalid="false"` still means
what it says.

**Ruby, Rails and Tailwind — these are new floors, introduced on this branch, not old ones you
already cleared.** Minimum Ruby moves from 3.1 to 3.2 (`tailwind_merge` requires it), minimum
Rails moves from 7.0 to 7.2 (`turbo-rails` and `view_component` already required 7.1, so 7.0
never actually worked; 7.2 is the oldest release the suite was run against, and it passed with
no changes), and Tailwind 3 / Sprockets support is dropped — Tailwind CSS 4 via
`tailwindcss-rails` is now the only supported path. If your app is on Ruby 3.1, Rails 7.0/7.1,
or Tailwind 3, `bundle update` will tell you before anything subtler does.

One thing that looks like a kit bug and isn't: **Rails 7.2 and 8.0 raise `unknown keyword:
quirks_mode` with version 3 of the `json` gem**, from inside Rails' own JSON encoder. It breaks
any Rails app on those versions, not only the kit's components, and Rails fixed it in 8.1. If you
see it, keep `json` below 3 or move to Rails 8.1. Rails 7.2 is also past its security-maintenance
window, which is reason enough to plan the move regardless.

## Grep checklist

Run from your app root to find what's affected:

```bash
# Hand-written 0.2.0 overlay markup (§2): none of it opens any more
grep -rn 'data-controller="ui--\(modal\|dropdown\|popover\|tooltip\)"' app/
grep -rn 'ui--tooltip#show\|ui--tooltip#hide' app/
grep -rn 'data-ui--\(dropdown\|popover\|tooltip\)-\(placement\|offset\|match-width\)-value' app/
grep -rn 'data-ui--modal-target="dialog"\|data-ui--modal-position-value\|ui--modal#closeOn\|modal-.*-visible\|z-\[60\]\|z-\[61\]' app/
grep -rn 'data-ui--\(popover\|dropdown\)-open-value' app/

# Deprecated class options and slot on the overlays (§2): they warn now and go in 0.4.0
grep -rn 'max_width:\|panel_classes:\|content_classes:\|with_menu' app/

# Copy-pasted toast container markup missing the live regions (§1)
grep -rln 'data-controller="ui--toast-container"' app/ | xargs grep -L 'role="status"\|role="alert"'

# Toast messages that are now descriptions, renamed toast keys, and the old stream recipe (§6)
grep -rn 'body:\|timeout:' app/ | grep -i toast
grep -rn 'ui--toast-target="\(title\|body\)"\|turbo_stream.append "body"' app/ test/ spec/

# Toast messages passed as I18n key strings (§7)
grep -rn 'ToastComponent.new' app/ | grep 'message: "[a-z_]*\.[a-z_.]*"'

# Confirm dialog class options, now merged rather than replacing (§5)
grep -rn 'ConfirmDialogComponent.new' app/ | grep '_class:'
grep -rn 'icon_class:' app/ | grep -i confirm

# disabled/readonly/etc. passed as a literal string anywhere near these components
grep -rn 'disabled: .*\.to_s\|disabled: "false"' app/
```

Everything else in [CHANGELOG.md](CHANGELOG.md)'s 0.3.0 section — new components, the
accessibility and focus-handling fixes, the token retune — needs no action; it's additive or
fixes a bug you'd have hit either way.
