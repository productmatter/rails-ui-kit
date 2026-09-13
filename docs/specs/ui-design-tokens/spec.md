---
slug: ui-design-tokens
type: feature
status: blocked
decider: Jonathan Simmons
blast_radius: high
size: small
target_model: standard
created: 2026-09-07
stale_after: 2026-09-27
loop_budget: 5
---

## Intent

`ui-design-tokens` is the first scope of Phase A: the CSS-variable contract every
later scope — `Ui::Base`'s variant layer, the shared primitives, and eventually all
seven retrofitted components — reads color and radius from (§ Business rules of
ui-component-library, rule 1). Today those seven components hardcode Tailwind
palette classes (`bg-white dark:bg-gray-900`, `neutral-900`, `gray-800`, `red-600`);
this scope does not touch that code — it creates the tokens those components will
later be migrated onto in `ui-foundation-retrofit`. The contract has two halves that
must both hold: shadcn/ui's token *names*, verbatim, so an external shadcn theme
(tweakcn output, etc.) drops into a host Rails app unchanged, and ProductMatter's own
`oklch()` *values* as the shipped default (§ Business rules of ui-component-library,
rule 2).

## Goal

Every token named in § Business rules of ui-component-library (rule 2) is defined
under both `:root` and `.dark` in `engine.css`, mapped through `@theme` so Tailwind
v4 utilities like `bg-background`, `text-muted-foreground`, `border-border`, and
`ring-ring` compile, and is reachable by a consuming app through each of the three
paths README.md documents.

## Non-goals

- Migrating the seven existing components' markup onto these tokens — that is
  `ui-foundation-retrofit`'s scope, not this one.
- Building the `class_variants`/`tailwind_merge` variant layer (`Ui::Base`) — that is
  `ui-component-base`'s scope.
- Picking or ratifying the exact `oklch()` values for each token — this spec states
  the constraint (ProductMatter's own values, not shadcn's) and defers the values
  themselves to a human-gate check at implementation.
- Rewriting, wrapping, or extending `dark_mode_controller.js` — its `.dark`-on-`<html>`
  toggle is the fixed mechanism this scope's tokens are built to match.
- Shipping shadcn's own `@layer base { * { border-color: var(--border) } }` reset.
  That rule recolors every bare `border` utility in every host app, shadcn theme or
  not — it is a global default, not an additive token — so it isn't part of this
  scope's delivery. A deliberate non-goal, not an oversight.

## Behavior

The token stylesheet lands in `app/assets/tailwind/rails_ui_kit/engine.css` as a
`:root { ... }` block and a `.dark { ... }` block, each defining every color token
name listed under Business rules with an `oklch()` value; `radius` is defined once,
under `:root` only, as a plain length. An `@theme inline { --color-background:
var(--background); ... }` mapping block follows so Tailwind v4 generates
`bg-background`, `text-muted-foreground`, `border-border`, `ring-ring`, and their
siblings for every token — `inline`, not plain `@theme` (§ Business rules, rule 6).

A consuming app receives this stylesheet through whichever of the three paths
README.md documents it's already on — the importmap + Tailwind v4 +
`tailwindcss-rails` path via the existing `@import` chain the install generator
already wires (no generator change needed for delivery), the JS-bundler path via the
same compiled `rails_ui_kit.css`, or the Tailwind 3/Sprockets path via
`@import "rails_ui_kit/components"` — and overrides a value the same way an external
shadcn theme would: by redefining the same `--token-name` under its own
`:root`/`.dark` after the kit's import, relying on CSS cascade rather than a
generator-scaffolded override file.

`dark_mode_controller.js` already toggles the `.dark` class on
`document.documentElement`, persists the choice to `localStorage`, falls back to
`prefers-color-scheme` on first load, and syncs across tabs via the `storage` event.
This scope's `:root`/`.dark` split is written to consume exactly that toggle; nothing
on the JavaScript side changes.

## Business rules

1. Token names are shadcn/ui's, verbatim — the full set: `background`/`foreground`,
   `card`/`card-foreground`, `popover`/`popover-foreground`, `primary`/
   `primary-foreground`, `secondary`/`secondary-foreground`, `muted`/
   `muted-foreground`, `accent`/`accent-foreground`, `destructive`, `border`,
   `input`, `ring`, `chart-1`…`chart-5`, `sidebar` plus its seven variants
   (`sidebar-foreground`, `sidebar-primary`, `sidebar-primary-foreground`,
   `sidebar-accent`, `sidebar-accent-foreground`, `sidebar-border`,
   `sidebar-ring`), and `radius` — 32 names total (§ Business rules of
   ui-component-library, rule 2). This half of the contract is closed: an
   external shadcn theme redefining any of these 32 names is always honored.
   It is not the whole contract — rule 5 states the second half.
2. Color values are ProductMatter's own, expressed in `oklch()` — never shadcn's
   default palette copied verbatim (§ Business rules of ui-component-library,
   rule 2). `radius` is a plain length (`0.5rem`), not a color, and carries no
   `oklch()` value.
3. Light and dark are the same token names redefined under `:root` and `.dark`; a
   class toggle on `<html>` is the only mode-switching mechanism — no second
   stylesheet, no `prefers-color-scheme` media query as the primary mechanism (§
   Business rules of ui-component-library, rule 3).
4. The existing `.dark`-on-`document.documentElement` toggle in
   `dark_mode_controller.js` is the class-toggle mechanism rule 3 requires; this
   scope is built to be compatible with it, not to replace it.
5. The contract's second half is documented **kit extensions**: token names
   outside shadcn's own vocabulary, each shipped with a default that degrades
   gracefully — an external theme that doesn't define the extension simply
   leaves the kit's default in place rather than breaking (decided 2026-09-13,
   Jonathan Simmons). The first extension is `--destructive-foreground` (and its
   `.dark` counterpart), consumed by `Ui::ButtonComponent`'s destructive variant:
   current shadcn dropped this token and its own button hardcodes `text-white`,
   which rule 1 of ui-component-library forbids; borrowing `primary-foreground`
   would couple destructive text to the primary color; the kit default equals
   shadcn's hardcoded white, so interop loses nothing; and an older shadcn theme
   that still defines `--destructive-foreground` is honored rather than
   overridden. `--success`, `--warning` and `--info`, each with a `-foreground`
   pair, are planned extensions — added when their first consuming component
   lands (Alert/Badge in Phase B, Toast in `ui-foundation-retrofit`), not before;
   an unused token is scope creep. `chart-1`…`chart-5` are not a home for status
   semantics — chart colors are categorical, not semantic.
6. The `@theme` mapping block uses the `inline` variant — `@theme inline { ... }`,
   never plain `@theme { ... }`. Plain `@theme` resolves a `--color-*` utility to
   its `:root` value at build time, which silently breaks any token redefinition
   under `.dark` (or a host app's own cascade) below `<html>`; `inline` keeps the
   utility pointing at the custom property itself, so a redefinition is honored
   wherever it lands in the cascade.

## Assumptions

- Tailwind v4 with the `engine.css`/`tailwindcss-rails` convention is the host
  pipeline (§ Assumptions of ui-component-library).
- Consuming apps may sit on any of the three paths README.md documents — importmap +
  Tailwind v4 (primary), a JS bundler consuming the compiled `rails_ui_kit.css`, or
  Tailwind 3/Sprockets via `@import "rails_ui_kit/components"` — and the token
  stylesheet must be reachable on all three, not just the primary path.
- shadcn/ui's own tokens have used `oklch()` since its Tailwind v4 migration, which is
  why adopting `oklch()` for ProductMatter's values keeps the token *format*, not
  just the names, aligned with the ecosystem this contract interops with.
- `dark_mode_controller.js` (already shipped) toggles `.dark` on
  `document.documentElement`, persists to `localStorage`, respects
  `prefers-color-scheme`, and syncs across tabs via the `storage` event; this scope
  treats that mechanism as fixed and builds the token contract to match it exactly.
- **`ui-test-harness` ships first** (`relations.md`). This scope defines no
  system-test plumbing of its own, but its `.dark`-on-`<html>` regression check (§
  Acceptance checks) runs `test/system/dark_mode_toggle_test.rb` in the browser lane
  `ui-test-harness` owns, and that lane does not exist until that scope ships — so
  the acceptance check cannot pass without it. The dependency is on the system-test
  lane existing, not on any particular test within it.
- **Corrected:** the docs app was never on the delivery path this scope assumed.
  `examples/app/assets/tailwind/application.css` imported `rails_ui_kit/components`
  (the non-Tailwind component CSS) directly and never imported `engine.css`, so the
  "existing `@import` chain already carries it" claim below held for a
  generator-scaffolded host app but not for the docs app itself. Repointed in
  `cdd9820` to `@import` `engine.css` directly, alongside `tailwindcss`; see §
  Critical files.

## Critical files

- `app/assets/tailwind/rails_ui_kit/engine.css` — the Tailwind v4 entrypoint; where
  the `:root`/`.dark` token blocks and the `@theme` mapping land.
- `app/assets/stylesheets/rails_ui_kit/components.css` — existing non-Tailwind
  component CSS (modal transform states); the token layer stays out of this file.
- `lib/generators/rails_ui_kit/install/install_generator.rb` — the install surface;
  confirmed it needs no change for token delivery since the existing `@import` chain
  already carries the compiled stylesheet the tokens live in.
- `app/javascript/rails_ui_kit/controllers/dark_mode_controller.js` — the mode-toggle
  mechanism this token layer is built to be compatible with; not modified by this
  scope.
- `README.md` — documents the three consumption paths (importmap + Tailwind v4, JS
  bundler, Tailwind 3/Sprockets).
- `examples/app/assets/tailwind/application.css` — the docs app's own Tailwind
  entrypoint; repointed in `cdd9820` to `@import` `engine.css` directly, since it
  previously imported `rails_ui_kit/components` only and never reached the token
  layer (§ Assumptions).

## Acceptance checks

### agent-loopable

- Every token name maps through `@theme` for Tailwind v4 utilities to resolve — run: `grep -c -- "--color-background: var(--background)" app/assets/tailwind/rails_ui_kit/engine.css`
- The mapping block is pinned to `@theme inline`, not plain `@theme`, so a `.dark`-scope override below `<html>` is honored (§ Business rules, rule 6) — run: `grep -q "^@theme inline {" app/assets/tailwind/rails_ui_kit/engine.css`
- The `.dark`-on-`<html>` contract `dark_mode_controller.js` depends on is pinned by a regression test — run: `bundle exec rake test:system TEST=test/system/dark_mode_toggle_test.rb`

### judgeable

- Token values in `engine.css` are ProductMatter's own `oklch()` colors, not copied from shadcn's default palette, satisfying § Business rules of ui-component-library rule 2's "ProductMatter's values" clause.
- No new file this scope adds introduces a Tailwind palette literal (`bg-white`, `neutral-900`, etc.) in place of a token, per § Business rules of ui-component-library rule 1.

### human-gate

- Jonathan reviews and approves the exact `oklch()` values chosen for light and dark mode across all 32 shadcn-contract color tokens (§ Business rules, rule 1) plus each ratified kit extension (rule 5) before this scope ships.
- Jonathan spot-checks that a real tweakcn-exported theme's `:root`/`.dark` block, pasted after the kit's import, reskins a rendered page without editing `engine.css`.

## Out of scope / deferred

- Component migration (retrofit of the seven existing components onto these
  tokens) — `ui-foundation-retrofit`.
- The `Ui::Base` variant/class-merge layer — `ui-component-base`.
- Exact `oklch()` values for each token beyond the constraint that they're
  ProductMatter's own — a human-gate check at implementation, not this spec.
- Any change to `dark_mode_controller.js` — its toggle mechanism is fixed and
  consumed as-is.
