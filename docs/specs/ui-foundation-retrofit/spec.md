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
consumes and become the thing the shipped overlay components (`Ui::ModalComponent`,
`Ui::DropdownComponent`, `Ui::PopoverComponent`, `Ui::TooltipComponent`, and
`Ui::ConfirmDialogComponent`'s overlay behaviour) actually run on. Every hardcoded
palette class and every hand-rolled positioning implementation in them get replaced by
the shared layer this phase built (§ Business rules of ui-component-library, rules 1,
4, 8). This is also
where the phase's breaking change actually lands on rendered output, so it inherits
the pinning precondition and the batch-the-breakage rule as hard constraints, not
suggestions (§ Assumptions of ui-component-library; § Business rules of
ui-component-library, rule 10).

**Handed off on 2026-09-14.** The orchestrator ratified `ui-toast` and
`ui-confirm-dialog` and moved two components' migrations out of this scope. Toast and
ToastContainer moved entirely. Confirm Dialog's tokens, `Ui::Base` adoption and class
keywords moved too. Its overlay adoption, already done, stays recorded here. Both scopes
change things this one pinned: Toast's template-clone contract, and deleting all nine
Confirm Dialog class keywords. The text below covers only what remains.

Per-component migration detail — what changes in each remaining `.rb`/`.html.erb`
pair and its controller — lives in `implementation.md`, not here, to keep this
document readable in one sitting.

## Goal

Modal, Dropdown, Popover and Tooltip render with zero hardcoded Tailwind palette
classes and inherit `Ui::Base`'s variant/class-merge layer in place of string
interpolation. They and Confirm Dialog consume the presence,
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

**Tokens.** Every hardcoded palette class in Modal, Dropdown, Popover and Tooltip's
`.rb`/`.html.erb` files is replaced by a token utility class from `ui-design-tokens`.
The known offenders are Modal's `bg-white dark:bg-gray-900`, Popover's `bg-white
dark:bg-neutral-900` / `border-neutral-200 dark:border-neutral-700`, and Tooltip's
`bg-neutral-900 text-white dark:bg-white dark:text-neutral-900`. Toast's status
colours and their `success`/`warning`/`info` kit extensions (Jonathan's 2026-09-13
decision) are `ui-toast`'s. Confirm Dialog's `DEFAULTS` literals are
`ui-confirm-dialog`'s.

As shipped on 2026-09-15: Popover's and Dropdown's panels wear `bg-popover` with a `border`
coloured by the `[data-slot]` base rule; Tooltip and its arrow invert the page, `bg-foreground
text-background`, which is what the old literals did in both modes. Modal's backdrop scrim,
`backdrop:bg-black/50`, stays a literal by the orchestrator's 2026-09-15 ruling: it is the same
in both modes by design, no token names a scrim, and hiding it as an arbitrary value would
only cheat the acceptance check, which allows it by name instead.

**`Ui::Base`.** Modal, Dropdown, Popover and Tooltip inherit from it and use its
variant/class-merge API instead of string interpolation. As shipped on 2026-09-15:

- `class:` merges onto Modal's `<dialog>`, its only visible element, and onto the root
  element of Dropdown, Popover and Tooltip, where their controllers sit and
  `ui--overlay:*` events fire. Forwarded `data:`/`aria:` and `data-slot` land on the same
  element. A panel is styled through its slot: `with_panel(class:)` on Popover and Dropdown,
  merged.
- `max_width:`, `panel_classes:` and `content_classes:` are kept for one release, merged
  rather than replacing, and warn through `RailsUiKit.deprecator`. Removing them outright
  would have been silent: `Ui::Base` forwards an unknown keyword as an HTML attribute, so
  `Ui::Base` now raises on any undeclared `*_class:`/`*_classes:` keyword instead
  (`ui-component-base` § Behavior).
- Modal's `position:` is a `class_variants` axis. Dropdown's `kind:` and every `placement:`
  resolve through `Ui::Base`'s unknown-value handling, so the removed `kind: :listbox` and
  `placement: :nope` raise in development and test instead of silently rendering a default,
  and a symbol placement (`:bottom_start`) works.
- Dropdown's slot was `menu`. It is `panel`, reading beside Popover's, with `with_menu` a
  deprecated alias for one release. `content` was the first choice and is a name ViewComponent
  reserves.
- Modal's prompt values are `unsavedChangesTitle`/`unsavedChangesMessage`, the leaves of their
  `modal.unsaved_changes_*` locale keys; neither value existed in 0.2.0.

The deletion of
`ConfirmDialogComponent`'s `DEFAULTS`/`*_class` keywords that this section once
specified is reversed by the orchestrator's 2026-09-14 ruling in `ui-confirm-dialog`:
eight keywords stay, merged onto the token defaults, and `icon_class:` goes.

**Primitives.** Modal, Dropdown, Popover, Tooltip and ConfirmDialog adopt the
presence and overlay-stack primitives; Dropdown, Popover and Tooltip additionally
adopt the positioning primitive in place of their own `computePosition` calls. The
three duplicated `@floating-ui/dom` imports in `dropdown_controller.js`,
`popover_controller.js` and `tooltip_controller.js` are deleted — after this scope,
no file under `app/components/ui/` or its controllers imports `@floating-ui/dom`
directly (§ Business rules of ui-component-library, rule 4).

Dropdown, the last of the four with its own open state, moved onto `ui--overlay` in layer
mode on 2026-09-15, as Popover had. What it had hand-rolled — open state, outside click,
Escape, the open/closed animation and the `z-50` — is the overlay's, and the overlay's
`opened`/`closed`/`dismiss` events are Dropdown's. It binds its own trigger. What stays in
`dropdown_controller.js` is what no primitive does: the menu button's arrow keys on the
trigger, role adoption, activation, where focus lands on open (the overlay's `moveFocus` is
off), closing when focus leaves, and the legacy positioning-attribute forwarding. Tab closes
at once, without the exit animation, through `ui--overlay#closeNow`. A trigger press during
the exit animation reopens the menu, where the overlay's own `toggle` would stay closed. The hardcoded z-indexes
on the overlays (`z-[61]` on Modal, `z-50` on Dropdown/Popover/Tooltip) are deleted
rather than renumbered: paint order comes from the browser's top layer
(`showModal()` / `popover`), and the only stacking value the overlay primitives allow
is the single `popover`-unsupported fallback the stack module applies
(`ui-presence-and-overlay-stack` § Business rules, rule 2). There is no managed
z-index scale for a component to draw from, and this scope does not invent one.

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
`window.customConfirmDialog()`, which `dialog_controller.js` installs. `ui-confirm-dialog`
extends that second contract additively and keeps it. The toast contract this section
once pinned is `ui-toast`'s, which changes it on purpose. `turbo_disable_with`'s spinner
styling is explicitly deferred to Phase B, not touched here.

**Breaking-change management.** `productmatter/rails_foundation` and `bonnie-rails`
both track this gem unpinned on `branch: "main"`; pinning both to the v0.2.0 tag/SHA
is a blocking precondition of this scope reaching `main`, performed in those repos,
not this one (§ Assumptions of ui-component-library). `CHANGELOG.md` gets a real
v0.3.0 migration entry, not a one-liner: every rendered-class change, the renaming of
Modal's `ui--modal` `dialog` target to
`ui--overlay`'s `content` target — a breaking rename of a public data attribute, so
any host markup or CSS written against `data-ui--modal-target="dialog"` stops
matching (`ui-presence-and-overlay-stack` § Out of scope / deferred flags it for this
scope) — the z-index/stacking change for anyone who wrote CSS against the old
literals. `README.md`'s "Confirm dialog theming" section is `ui-confirm-dialog`'s to
rewrite. `README.md`'s component table is
also missing Popover and Tooltip, shipped in v0.2.0 — added here regardless of the
rest of the retrofit.

**`PLAN.md`.** Predates v0.2.0; its toast-server-endpoint concern was solved
client-side and its phase-by-phase plan is fully executed. `docs/archive/` is
Specline's own convention for graduated *specs*, not a home for arbitrary project
docs, so it isn't the right destination. `PLAN.md` is deleted — its historical
content (what shipped in v0.1.0/v0.2.0 and why) is already captured in
`CHANGELOG.md`, and this spec plus `docs/architecture.md` are the living replacement
for "how the pieces fit together."

**Test suite.** The existing Minitest files are the safety net but are not
class-invisible to this migration. The Toast and Confirm Dialog test rewrites belong to
`ui-toast` and `ui-confirm-dialog`. `modal_component_test.rb`'s assertions against
`modal-center-hidden`/`modal-right-hidden` class names survive if the transform-class
names are kept as specified above; if `implementation.md` renames them, those
assertions move with the rename. `examples/app/views/docs/` keeps one page per
component and must keep rendering after the migration; it does not gain new pages
for Popover/Tooltip navigation as part of this scope (they already have doc pages
per the file listing) but any example markup that references old class names is
updated.

## Business rules

1. No component reads a Tailwind palette literal for color; color and radius come
   only from token utility classes (§ Business rules of ui-component-library,
   rule 1). Modal's `backdrop:bg-black/50` scrim is the one named exception, ruled on
   2026-09-15 (§ Behavior, Tokens).
2. Toast's status-colour mapping moved to `ui-toast` on 2026-09-14, which inherits it
   unchanged.
3. Modal, Dropdown, Popover and Tooltip inherit `Ui::Base` and use its
   variant/class-merge API; none builds its own class-string interpolation once this
   scope ships (§ Business rules of ui-component-library, rule 8).
4. Confirm Dialog's class API moved to `ui-confirm-dialog` on 2026-09-14. That scope
   keeps eight keywords, now merged, which reverses the deletion this rule used to
   require.
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
8. The form-change/Modal and turbo-confirm/ConfirmDialog global-function/event
   contracts documented in `README.md` today keep working exactly as documented; a
   behavior change in either is a defect in this scope, not an accepted side effect.
   The toast contract is `ui-toast`'s, which changes it deliberately and documents it
   in `UPGRADING.md`.
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
  - Toast and the utility controllers are landing next. Toast's guards are now
    `ui-toast`'s to keep.

  System regression tests in the `test:system` lane guard those fixes. This scope
  keeps those tests green (rule 11) rather than rediscovering the bugs. Where a fix's
  mechanism moves into a primitive, such as Turbo-cache teardown, focus restore on
  removal, or Escape handling, the primitive must reproduce the tested behaviour.
  `ui-presence-and-overlay-stack` § Behavior records the Turbo-cache contract.

## Critical files

- `app/components/ui/{modal,dropdown,popover,tooltip}_component.*` — this scope's
  direct subject. `app/components/ui/placement.rb` holds the twelve placements the three
  anchored components share. Confirm Dialog and Toast are `ui-confirm-dialog` and `ui-toast`.
- `app/javascript/rails_ui_kit/controllers/{modal,dropdown,popover,tooltip}_controller.js`
  — the component-paired controllers; `dropdown_controller.js`,
  `popover_controller.js` and `tooltip_controller.js` lose their `@floating-ui/dom`
  positioning blocks.
- `app/javascript/rails_ui_kit/controllers/{form_change,turbo_confirm}_controller.js`
  — untouched, but their contracts with Modal and ConfirmDialog are regression-pinned
  by this scope.
- `app/assets/stylesheets/rails_ui_kit/components.css` — Modal's transform-state
  classes; kept and re-targeted, not deleted, per Behavior above.
- `README.md` — component table (add Popover, Tooltip).
- `PLAN.md` — deleted; see Behavior.
- `CHANGELOG.md` — gets the real v0.3.0 migration entry this scope requires.
- `test/components/ui/*_test.rb` — the Minitest files for the four components.
- `examples/app/views/docs/*.html.erb` — one page per component; must keep
  rendering, updated wherever it references a class or API this scope deletes.
- `implementation.md` (this scope) — the per-component migration detail this file
  intentionally defers.

## Acceptance checks

### agent-loopable

- No hardcoded Tailwind palette literal remains in Modal, Dropdown, Popover or Tooltip, except Modal's opacity-modified black scrim, which is the same in both modes by design and which no token names (§ Business rules, rule 1) — run: `! grep -rEn "(bg|text|border|ring|outline|divide|fill|stroke)-(white|black|slate|gray|zinc|neutral|stone|red|orange|amber|yellow|green|blue|indigo)-?[0-9]*" app/components/ui/modal_component.* app/components/ui/dropdown_component.* app/components/ui/popover_component.* app/components/ui/tooltip_component.* | grep -v 'backdrop:bg-black/50'`
- The three duplicated Floating UI positioning implementations are deleted — run: `! grep -l '@floating-ui/dom' app/javascript/rails_ui_kit/controllers/dropdown_controller.js app/javascript/rails_ui_kit/controllers/popover_controller.js app/javascript/rails_ui_kit/controllers/tooltip_controller.js`
- The full unit lane, including rewritten component tests, is green — run: `bundle exec rake test`
- The ConfirmDialog global functions `turbo_confirm` depends on are installed and answer (CD9) — run: `bundle exec rake test:system TEST=test/system/confirm_dialog_test.rb`
- `turbo_confirm` opens ConfirmDialog and honours its answer — run: `bundle exec rake test:system TEST=test/system/turbo_confirm_test.rb`
- A Modal with `trackChanges` asks before discarding a form `ui--form-change` marked dirty — run: `bundle exec rake test:system TEST=test/system/modal_turbo_cancel_test.rb`
- Modal's unsaved-changes prompt falls back without a confirm dialog (M4) and carries the text its value attributes name (M8) — run: `bundle exec rake test:system TEST=test/system/modal_test.rb`
- The four components' rendered structure, wiring, ARIA and non-palette classes survive the move, as pinned before it began — run: `bundle exec ruby -Itest test/components/ui/overlay_render_pin_test.rb`
- The whole browser lane, including every component-audit regression test, is green after the migration — run: `bundle exec rake test:system`

### judgeable

- Nesting a Dropdown or Popover inside a Modal produces correct stacking and reverse-order dismissal, satisfying rule 7 of § Business rules of ui-component-library.
- Every interactive component retrofitted in this scope remains keyboard-operable with correct ARIA after migration, per rule 6 of § Business rules of ui-component-library.

### human-gate

- Jonathan confirms both `productmatter/rails_foundation` and `bonnie-rails` are pinned to the v0.2.0 tag/SHA before this scope's changes reach `main` (blocking precondition, § Assumptions of ui-component-library).
- Jonathan reviews the `CHANGELOG.md` migration note and confirms it's sufficient for a consumer to self-serve the upgrade without reading a diff.
- Jonathan reviews the rendered visual diff of Modal, Dropdown, Popover and Tooltip, light and dark, against v0.2.0 and signs off that the token migration reads as intentional restyling, not breakage.

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
- Toast, ToastContainer, and Confirm Dialog's tokens, `Ui::Base` adoption and class
  keywords — handed off to `ui-toast` and `ui-confirm-dialog` on 2026-09-14.
- The eject generator, the AI-chat family, Chart, Data Table, typography-as-a-
  component, and the seven deferred-decision components — parent-level cuts/
  deferrals, untouched here (parent § Out of scope / deferred).
