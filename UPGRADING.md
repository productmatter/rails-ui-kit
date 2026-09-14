# Upgrading

This covers the ~40 commits between the last release and this branch. It reports findings,
not predictions: this branch was tested against a real consuming app before this was written,
and the two failures below (§1, §2) are exactly what that test found — one of them silent.

**Headline: run `bundle update`, then fix three things.** Most of the CHANGELOG's Unreleased
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

## 2. Hand-written dropdown positioning attributes moved (loud, but still works — for now)

Dropdown, Popover and Tooltip now position through a shared `ui--anchor` controller instead of
each running its own Floating UI setup. If you hand-write a Dropdown's attributes rather than
using the component, these moved:

| Old (on `ui--dropdown`) | New (on `ui--anchor`) |
|---|---|
| `data-ui--dropdown-placement-value` | `data-ui--anchor-placement-value` |
| `data-ui--dropdown-offset-value` | `data-ui--anchor-offset-value` |
| `data-ui--dropdown-match-width-value` | `data-ui--anchor-match-width-value` |

The old attributes still work — Dropdown forwards them to the `ui--anchor` equivalent and warns
in the console, naming the element — but they're deprecated, and an `ui--anchor` attribute you've
already set wins over the forwarded one. Migrate to the new names.

Popover and Tooltip don't have hand-written equivalents to migrate (they never exposed these as
public attributes), so this only affects Dropdown.

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

## Also worth knowing

**Modal markup**, only if you hand-write it instead of rendering `Ui::ModalComponent`:
- `data-ui--modal-target="dialog"` → `data-ui--overlay-target="content"`.
- The backdrop `<div>` is gone; the browser's native `::backdrop` draws it now.
- The `z-[60]`/`z-[61]` literals are gone with it.
- `data-ui--modal-position-value` is gone.
- The `modal-<position>-visible` classes are now `modal-<position>-hidden` (the CSS shows the
  hidden state and reveals on `[data-state="open"]`, rather than the reverse).
- `closeOnBackdropClick` and `closeOnEscape` actions are gone. `close()` still works.

**Popover**: `data-ui--popover-open-value` is gone (state now lives in `ui--overlay`). Escape
now closes a Popover from anywhere on the page, not only when focus is inside it — it renders in
the browser's top layer, which gives Escape to whatever's topmost.

**ConfirmDialog**: `Ui::ConfirmDialogComponent` now renders Cancel before Confirm (previously
Confirm first), with `footer_class`, `confirm_class` and `cancel_class` changed to match. If you
override any of those three, or relied on `sm:flex-row-reverse` / the old button margins, check
the layout.

**Boolean attributes — a bug fix, not a style change.** `disabled: "false"` (and the same for
`readonly`, `required`, `checked`, `selected`, `multiple`, `hidden`, `open`) used to render as
disabled, because Rails treats any non-empty string as truthy. It's now correctly treated as
false. If anything in your app passed a stringified `"false"` expecting the old (wrong)
behavior — e.g. `disabled: some_boolean_column.to_s` from a form param or serialized value — it
will now render enabled. `aria-*` and `data-*` are untouched; `aria-invalid="false"` still means
what it says.

**Deleted components**, with their one-line replacements:
- `Ui::KbdComponent` → `<kbd class="inline-flex h-5 w-fit min-w-5 items-center justify-center gap-1 rounded-sm border border-border bg-muted px-1 font-mono text-xs font-medium text-muted-foreground select-none">Esc</kbd>`
- `Ui::AspectRatioComponent` → `<div class="relative w-full aspect-square"><div class="absolute inset-0"><%= child %></div></div>` (swap `aspect-square` for `aspect-video`, `aspect-[3/4]` or `aspect-[4/3]` to match the ratio you used)

**Ruby and Tailwind — these are new floors, introduced on this branch, not old ones you already
cleared.** Minimum Ruby moves from 3.1 to 3.2 (`tailwind_merge` requires it), and Tailwind 3 /
Sprockets support is dropped — Tailwind CSS 4 via `tailwindcss-rails` is now the only supported
path. If your app is on Ruby 3.1 or Tailwind 3, `bundle update` will tell you before anything
subtler does.

## Grep checklist

Run from your app root to find what's affected:

```bash
# Deprecated Dropdown positioning attributes (§2) — still work, but migrate
grep -rn 'data-ui--dropdown-\(placement\|offset\|match-width\)-value' app/

# Hand-written Modal internals that need the §"Also worth knowing" changes
grep -rn 'data-ui--modal-target="dialog"\|data-ui--modal-position-value\|ui--modal#closeOn\|modal-.*-visible\|z-\[60\]\|z-\[61\]' app/

# Hand-written Popover internals
grep -rn 'data-ui--popover-open-value' app/

# Copy-pasted toast container markup missing the live regions (§1)
grep -rln 'data-controller="ui--toast-container"' app/ | xargs grep -L 'role="status"\|role="alert"'

# Deleted components
grep -rn 'Ui::KbdComponent\|Ui::AspectRatioComponent\|Ui::Kbd::GroupComponent' app/

# disabled/readonly/etc. passed as a literal string anywhere near these components
grep -rn 'disabled: .*\.to_s\|disabled: "false"' app/
```

Everything else in [CHANGELOG.md](CHANGELOG.md)'s Unreleased section — new components, the
accessibility and focus-handling fixes, the token retune — needs no action; it's additive or
fixes a bug you'd have hit either way.
