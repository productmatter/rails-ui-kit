---
slug: ui-foundation-retrofit
type: chore
status: ratified
decider: Jonathan Simmons
blast_radius: high
size: large
target_model: standard
created: 2026-09-07
loop_budget: 8
---

## Intent

`ui-foundation-retrofit` is the last scope of Phase A: the point where the token
layer, `Ui::Base`, and the shared primitives stop being infrastructure nobody
consumes and become the thing all seven shipped components (`Ui::ModalComponent`,
`Ui::DropdownComponent`, `Ui::ConfirmDialogComponent`, `Ui::ToastComponent`,
`Ui::ToastContainerComponent`, `Ui::PopoverComponent`, `Ui::TooltipComponent`)
actually run on. Every hardcoded palette class, every hand-rolled positioning
implementation, and the one bespoke class-override escape hatch
(`ConfirmDialogComponent`'s `DEFAULTS` hash) get replaced by the shared layer this
phase built (§ Business rules of ui-component-library, rules 1, 4, 8). This is also
where the phase's breaking change actually lands on rendered output, so it inherits
the pinning precondition and the batch-the-breakage rule as hard constraints, not
suggestions (§ Assumptions of ui-component-library; § Business rules of
ui-component-library, rule 10).

Per-component migration detail — what changes in each of the seven `.rb`/`.html.erb`
pairs and their controllers — lives in `implementation.md`, not here, to keep this
document readable in one sitting.

## Goal

All seven shipped components render with zero hardcoded Tailwind palette classes,
inherit `Ui::Base`'s variant/class-merge layer in place of string interpolation and
`ConfirmDialogComponent`'s `DEFAULTS`-hash pattern, consume the presence,
overlay-stack and positioning primitives in place of their own logic, the three
duplicated `@floating-ui/dom` implementations in `dropdown_controller.js`,
`popover_controller.js` and `tooltip_controller.js` are deleted, and the full test
suite — including new regression checks for the utility-controller contracts this
scope must not break — is green.

## Non-goals

- Building the primitives, `Ui::Base`, or the token layer this scope consumes —
  those are `ui-component-base`, `ui-presence-and-overlay-stack` and
  `ui-positioning-and-navigation`'s scopes.
- New components. Phases B and C.
- Rewriting `dark_mode_controller.js`, `form_change_controller.js`,
  `turbo_confirm_controller.js` or `turbo_disable_with_controller.js`. Two of them
  are regression-pinned where they touch a component this scope changes; none of the
  four is rebuilt.
- Moving `turbo_disable_with`'s spinner styling onto tokens — deferred to Phase B.
- Performing the consumer-repo pin. `productmatter/rails_foundation` and
  `bonnie-rails` are pinned in their own repos, not here.
- Rebuilding `examples/`. It must keep rendering every component's docs page; it is
  not restructured.

## Behavior

**Tokens.** Every hardcoded palette class in the seven components' `.rb`/`.html.erb`
files is replaced by a token utility class from `ui-design-tokens`. The known
offenders are Modal's `bg-white dark:bg-gray-900`, Popover's `bg-white
dark:bg-neutral-900` / `border-neutral-200 dark:border-neutral-700`, Tooltip's
`bg-neutral-900 text-white dark:bg-white dark:text-neutral-900`, ConfirmDialog's
`gray-800`/`gray-900`/`red-600` family inside `DEFAULTS`, and Toast's `bg-white
dark:bg-gray-800` shell plus its per-type green/red/orange/blue icon and progress-bar
colors. Toast's five status types were the hard case: shadcn's own names, verbatim,
have no success/notice/info tokens, only `destructive`. Jonathan's 2026-09-13
decision (`ui-design-tokens` spec.md § Business rules, rule 5) resolves this by
extending the contract with documented kit extensions: `error`/`alert` map onto
`destructive`/`destructive-foreground` (already shipped); `success`, `notice` and
`info` map onto the `success`/`warning`/`info` kit-extension tokens (each with a
`-foreground` pair), added here since Toast is their first consumer, not before.

**`Ui::Base`.** All seven inherit from it and use its variant/class-merge API instead
of string interpolation. `ConfirmDialogComponent`'s `**overrides`/`DEFAULTS` pattern —
12 overridable class keys plus two label strings — is deleted outright; it exists
today only because there was no merge layer to lean on. It is replaced by per-part
class-merge slots (wrapper, body, footer, title, message, confirm button, cancel
button, icon wrapper, icon) driven by `Ui::Base`, so a caller's `class:` still wins
per rule 5 but the constructor's keyword surface is different: the nine `*_class`
keys are gone, `confirm_label`/`cancel_label` remain (they're content, not styling).
**This is a public API break** — see Critical files / Acceptance and `implementation.md`.

**Primitives.** Modal, Dropdown, Popover, Tooltip and ConfirmDialog adopt the
presence and overlay-stack primitives; Dropdown, Popover and Tooltip additionally
adopt the positioning primitive in place of their own `computePosition` calls. The
three duplicated `@floating-ui/dom` imports in `dropdown_controller.js`,
`popover_controller.js` and `tooltip_controller.js` are deleted — after this scope,
no file under `app/components/ui/` or its controllers imports `@floating-ui/dom`
directly (§ Business rules of ui-component-library, rule 4). The hardcoded z-indexes
on the overlays (`z-[61]` on Modal, `z-50` on Dropdown/Popover/Tooltip) are deleted
rather than renumbered: paint order comes from the browser's top layer
(`showModal()` / `popover`), and the only stacking value the overlay primitives allow
is the single `popover`-unsupported fallback the stack module applies
(`ui-presence-and-overlay-stack` § Business rules, rule 2). There is no managed
z-index scale for a component to draw from, and this scope does not invent one.

ToastContainer is not an overlay: it does not join the stack, is not focus-trapped,
and takes no part in reverse-order dismissal (`ui-presence-and-overlay-stack`
§ Out of scope / deferred). Its `z-[70]` is replaced by one static stacking value
owned and documented by this scope, defined in the kit's CSS rather than as a literal
in the component. The constraint to state honestly: **a normal-flow element cannot
paint above a top-layer `<dialog>` at any z-index** — the two are not comparable — so
no value chosen here makes a toast appear over an open Modal. The honest options are
to promote the container into the top layer itself (render it as `popover`), or to
accept that toasts are occluded while a modal is open. That is a visible product
decision, not an implementation detail — see Open questions.

Modal's hand-rolled transform-state CSS in `components.css` (8 position variants ×
hidden/visible, 16 classes) is **not** fully subsumed by the presence primitive: the
primitive is a generic `data-state="open|closed|closing"` state machine, agnostic of
what a given position's open/closed transform actually looks like. The 16 transform
classes stay — Modal still needs eight distinct hidden/visible transform pairs — but
they move from being toggled by `modal_controller.js`'s manual `classList`
choreography (`translateInClasses`/`translateOutClasses`, the `setTimeout` close
dance, the `overflow: hidden` scroll lock) to being selected by the presence
primitive's `data-state` attribute and its `animationend`/`transitionend` wait. The
JS choreography is deleted; the CSS is kept and re-targeted.

**Regression surfaces (decided already; pinned, not re-litigated).** Two of the four
utility controllers are coupled to components this scope changes and must not break:
`form_change_controller`'s `form:changed`/`form:pristine` events, which Modal's
`trackChanges` option listens for; and `turbo_confirm_controller`, which depends on
`ConfirmDialogComponent` being rendered and on `window.defaultConfirmDialog()` /
`window.customConfirmDialog()`, which `dialog_controller.js` installs.
`toast_container_controller.js`'s `window.triggerToast(type, message)` global, its
`rails-ui-kit:toast` event listener, and its per-type inline `<template>` cloning are
the third contract: cloning depends on `data-ui--toast-target="title"|"body"|"timer"`
surviving the token migration byte-for-byte, since `toast_container_controller.js`
selects on those exact strings, not on any class. `turbo_disable_with`'s spinner
styling is explicitly deferred to Phase B, not touched here.

**Breaking-change management.** `productmatter/rails_foundation` and `bonnie-rails`
both track this gem unpinned on `branch: "main"`; pinning both to the v0.2.0 tag/SHA
is a blocking precondition of this scope reaching `main`, performed in those repos,
not this one (§ Assumptions of ui-component-library). `CHANGELOG.md` gets a real
v0.3.0 migration entry, not a one-liner: every rendered-class change, the
`ConfirmDialogComponent` constructor break (old keys removed, what replaces them, a
before/after snippet), the renaming of Modal's `ui--modal` `dialog` target to
`ui--overlay`'s `content` target — a breaking rename of a public data attribute, so
any host markup or CSS written against `data-ui--modal-target="dialog"` stops
matching (`ui-presence-and-overlay-stack` § Out of scope / deferred flags it for this
scope) — the z-index/stacking change for anyone who wrote CSS against the old
literals, and a pointer to the updated README section. `README.md`'s
"Confirm dialog theming" section (lines 214–234 today) documents the exact API this
scope deletes and must be rewritten, not patched. `README.md`'s component table is
also missing Popover and Tooltip, shipped in v0.2.0 — added here regardless of the
rest of the retrofit.

**`PLAN.md`.** Predates v0.2.0; its toast-server-endpoint concern was solved
client-side and its phase-by-phase plan is fully executed. `docs/archive/` is
Specline's own convention for graduated *specs*, not a home for arbitrary project
docs, so it isn't the right destination. `PLAN.md` is deleted — its historical
content (what shipped in v0.1.0/v0.2.0 and why) is already captured in
`CHANGELOG.md`, and this spec plus `docs/architecture.md` are the living replacement
for "how the pieces fit together."

**Test suite.** The 9 existing Minitest files are the safety net but are not
class-invisible to this migration: `toast_container_component_test.rb` asserts the
literal `bg-red-100`; `confirm_dialog_component_test.rb` asserts the `confirm_class`/
`cancel_class`/`title_class`/`message_class` constructor keys directly, all four of
which are deleted by the `Ui::Base` migration. Both files need real rewrites, not
just "may need updating." `modal_component_test.rb`'s assertions against
`modal-center-hidden`/`modal-right-hidden` class names survive if the transform-class
names are kept as specified above; if `implementation.md` renames them, those
assertions move with the rename. `examples/app/views/docs/` keeps one page per
component and must keep rendering after the migration; it does not gain new pages
for Popover/Tooltip navigation as part of this scope (they already have doc pages
per the file listing) but any example markup that references old class names or the
old `ConfirmDialogComponent` keyword API is updated.

## Business rules

1. No component reads a Tailwind palette literal for color; color and radius come
   only from token utility classes (§ Business rules of ui-component-library,
   rule 1).
2. Toast's five status types map onto token names by a documented, defensible rule —
   not by picking whichever existing token looks closest. `error`/`alert` map onto
   the shadcn-contract's `destructive`/`destructive-foreground`; `success`, `notice`
   and `info` map onto the kit-extension tokens `success`, `warning` and `info`
   (each with a `-foreground` pair) that this scope adds as their first consumer,
   per Jonathan's 2026-09-13 decision (`ui-design-tokens` spec.md § Business rules,
   rule 5).
3. All seven components inherit `Ui::Base` and use its variant/class-merge API; none
   builds its own class-string interpolation once this scope ships (§ Business rules
   of ui-component-library, rule 8).
4. `ConfirmDialogComponent`'s `**overrides`/`DEFAULTS`-hash pattern is removed. Its
   replacement routes per-part class overrides through `Ui::Base`'s merge layer so a
   caller's `class:` still wins (§ Business rules of ui-component-library, rule 5),
   but the constructor's keyword surface changes — this is a documented public API
   break, not a transparent refactor.
5. Modal, Dropdown, Popover, Tooltip and ConfirmDialog stop reimplementing
   positioning, presence or overlay-stack behavior; each consumes the shared
   primitive instead. No file under `app/components/ui/` or its controllers imports
   `@floating-ui/dom` directly once this scope ships (§ Business rules of
   ui-component-library, rule 4).
6. A Dropdown or Popover opened inside a Modal follows the shared stack's top-layer
   placement and dismiss order; nested overlays close in the reverse of the order they
   opened (§ Business rules of ui-component-library, rule 7).
7. Every interactive component retrofitted here remains keyboard-operable with
   correct ARIA after migration — a component that regresses on either is a defect in
   this scope regardless of what its other checks say (§ Business rules of
   ui-component-library, rule 6).
8. The form-change/Modal, turbo-confirm/ConfirmDialog and toast
   global-function/event contracts documented in `README.md` today keep working
   exactly as documented; a behavior change in any of them is a defect in this
   scope, not an accepted side effect.
9. This scope does not merge to a state consumable from `main` until both
   `productmatter/rails_foundation` and `bonnie-rails` are confirmed pinned to the
   v0.2.0 tag/SHA (§ Assumptions of ui-component-library).
10. Breaking changes land in this one scope's release, not dribbled across several
    (§ Business rules of ui-component-library, rule 10).
11. The system regression tests that guard the component audit's fixes stay green
    through the migration, unchanged in what they assert. A retrofitted component that
    reintroduces an audit bug is a defect in this scope. Rewriting a test's selectors
    for renamed markup is allowed; weakening what it asserts is not (§ Assumptions).

## Assumptions

- `ui-component-base`, `ui-presence-and-overlay-stack` and
  `ui-positioning-and-navigation` ship first, per the parent's stated build order
  (tokens → base → primitives → retrofit). `relations.md` declares
  `depends_on: ui-positioning-and-navigation` — the last of the four sibling scopes
  to ship — because this scope deletes the three duplicated `@floating-ui/dom`
  implementations only once `ui--anchor` exists to replace them, and reaches the
  token, `Ui::Base` and presence/overlay layers transitively through it, not because
  those three dependencies are absent.
- `@floating-ui/dom` stays an importmap-pinned peer dependency; after this scope,
  only the positioning primitive imports it directly, not any component controller
  (§ Assumptions of ui-component-library; Business rule 5 above).
- Testing stack is ViewComponent `TestHelpers` for render assertions on the unit lane
  (`bundle exec rake test`), and for Stimulus behavior the Capybara browser lane
  `ui-test-harness` owns (`bundle exec rake test:system`), whose base class carries the
  `axe-core-capybara`/`axe-core-api` accessibility helper (§ Assumptions of
  ui-component-library). Where a regression contract — a global function, a custom
  event — can't be asserted through a render test alone, this scope adds a system test
  file to that lane rather than leaving it unasserted; it stands up no test plumbing of
  its own.
- The token migration's intent is visual parity, not pixel-identical output. The
  exact `oklch()` values are `ui-design-tokens`'s call, ratified at its own
  human-gate; if the shipped values read as a meaningfully different visual language
  than today's literals, that's surfaced there, not re-litigated in this scope.
- Both consumer repos are pinned to v0.2.0 before this scope's changes reach `main`.
  That action happens in those repos; this scope treats it as a precondition it
  checks for, not one it can perform.
- **The component audit's live bugs are already fixed in the old components.**
  `docs/audits/2026-09-13-component-audit.md` found them on `main`, and they were
  fixed in place rather than left for this scope:
  - `6a07152`: Modal, ConfirmDialog and `turbo_confirm`.
  - `ed7fbcb`: Dropdown and Popover.
  - `78d4c64`: Tooltip.
  - Toast and the utility controllers are landing next.

  System regression tests in the `test:system` lane guard those fixes. This scope
  keeps those tests green (rule 11) rather than rediscovering the bugs. Where a fix's
  mechanism moves into a primitive, such as Turbo-cache teardown, focus restore on
  removal, or Escape handling, the primitive must reproduce the tested behaviour.
  `ui-presence-and-overlay-stack` § Behavior records the Turbo-cache contract.

## Critical files

- `app/components/ui/*.rb`, `app/components/ui/*.html.erb` — the seven components;
  this scope's direct subject.
- `app/javascript/rails_ui_kit/controllers/{modal,dialog,dropdown,popover,tooltip,
  toast,toast_container}_controller.js` — the seven component-paired controllers;
  `dropdown_controller.js`, `popover_controller.js` and `tooltip_controller.js` lose
  their `@floating-ui/dom` positioning blocks.
- `app/javascript/rails_ui_kit/controllers/{form_change,turbo_confirm}_controller.js`
  — untouched, but their contracts with Modal and ConfirmDialog are regression-pinned
  by this scope.
- `app/assets/stylesheets/rails_ui_kit/components.css` — Modal's transform-state
  classes; kept and re-targeted, not deleted, per Behavior above.
- `README.md` — component table (add Popover, Tooltip) and "Confirm dialog theming"
  section (rewritten, not patched).
- `PLAN.md` — deleted; see Behavior.
- `CHANGELOG.md` — gets the real v0.3.0 migration entry this scope requires.
- `test/components/ui/*_test.rb` — the 9 Minitest files; `confirm_dialog_component_
  test.rb` and `toast_container_component_test.rb` need real rewrites, not just
  touch-ups.
- `examples/app/views/docs/*.html.erb` — one page per component; must keep
  rendering, updated wherever it references a class or API this scope deletes.
- `implementation.md` (this scope) — the per-component migration detail this file
  intentionally defers.

## Acceptance checks

### agent-loopable

- No hardcoded Tailwind palette literal remains in any of the seven components — run: `! grep -rEn "(bg|text|border|ring|outline|divide|fill|stroke)-(white|black|slate|gray|zinc|neutral|stone|red|orange|amber|yellow|green|blue|indigo)-?[0-9]*" app/components/ui/*.rb app/components/ui/*.html.erb`
- The three duplicated Floating UI positioning implementations are deleted — run: `! grep -l '@floating-ui/dom' app/javascript/rails_ui_kit/controllers/dropdown_controller.js app/javascript/rails_ui_kit/controllers/popover_controller.js app/javascript/rails_ui_kit/controllers/tooltip_controller.js`
- The full unit lane, including rewritten component tests, is green — run: `bundle exec rake test`
- The toast global-function/custom-event/template-clone contract is pinned by a regression test — run: `bundle exec rake test:system TEST=test/system/toast_regression_test.rb`
- The turbo-confirm/ConfirmDialog global-function contract is pinned by a regression test — run: `bundle exec rake test:system TEST=test/system/turbo_confirm_regression_test.rb`
- The form-change/Modal `trackChanges` contract is pinned by a regression test — run: `bundle exec rake test:system TEST=test/system/modal_form_change_regression_test.rb`
- The whole browser lane, including every component-audit regression test, is green after the migration — run: `bundle exec rake test:system`

### judgeable

- ConfirmDialog's replacement API still lets a caller's `class:` override win, satisfying rule 5 ("the caller wins") of § Business rules of ui-component-library.
- Nesting a Dropdown or Popover inside a Modal produces correct stacking and reverse-order dismissal, satisfying rule 7 of § Business rules of ui-component-library.
- Toast's five status-type colors trace to a documented, defensible token mapping rather than an arbitrary pick, consistent with § Business rules of ui-component-library rule 1.
- Every interactive component retrofitted in this scope remains keyboard-operable with correct ARIA after migration, per rule 6 of § Business rules of ui-component-library.

### human-gate

- Jonathan confirms both `productmatter/rails_foundation` and `bonnie-rails` are pinned to the v0.2.0 tag/SHA before this scope's changes reach `main` (blocking precondition, § Assumptions of ui-component-library).
- Jonathan reviews the `CHANGELOG.md` migration note and confirms it's sufficient for a consumer to self-serve the upgrade without reading a diff.
- Jonathan reviews the rendered visual diff of all seven components, light and dark, against v0.2.0 and signs off that the token migration reads as intentional restyling, not breakage.

## Out of scope / deferred

- New components — Phases B and C (parent § Scopes).
- Building the primitives, `Ui::Base`, or the token layer — `ui-component-base`,
  `ui-presence-and-overlay-stack`, `ui-positioning-and-navigation`.
- Rewriting `dark_mode_controller.js`, `form_change_controller.js`,
  `turbo_confirm_controller.js`, `turbo_disable_with_controller.js` — untouched
  except where a contract is regression-pinned; see Behavior and parent
  open-questions.md's default (a).
- `turbo_disable_with`'s spinner styling moving onto tokens — Phase B
  (`ui-presentational-components`).
- Pinning `productmatter/rails_foundation` and `bonnie-rails` to v0.2.0 — external
  action in those repos; recorded here as a blocking precondition only (parent §
  Out of scope / deferred).
- Rebuilding `examples/` — it must keep rendering; it is not restructured (parent §
  Non-goals).
- The eject generator, the AI-chat family, Chart, Data Table, typography-as-a-
  component, and the seven deferred-decision components — parent-level cuts/
  deferrals, untouched here (parent § Out of scope / deferred).
