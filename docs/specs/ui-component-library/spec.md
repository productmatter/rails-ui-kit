---
slug: ui-component-library
type: parent
status: ratified
decider: Jonathan Simmons
blast_radius: high
target_model: frontier
created: 2026-09-07
---

## Intent

`rails_ui_kit` is ProductMatter's internal studio asset: the UI layer we reach for
when a client web product needs to exist quickly and look like someone cared. It is
not a public library and it is not competing with anything. It exists so that the
studio's next Rails project starts at "compose the screens" instead of "rebuild the
modal."

Today it is seven ViewComponents built one at a time, each solving its own problems
locally. Three of them — Dropdown, Popover, Tooltip — separately import
`@floating-ui/dom` and separately reimplement positioning. None of them has a focus
trap, a scroll lock, a portal, or a place in a z-index stack, so a Dropdown opened
inside a Modal misbehaves. There is no shared exit-animation handling. Every one of
them hardcodes Tailwind palette classes instead of reading a token. That foundation
carries seven components. It does not carry forty, and the cost of the eighth is
already visible.

This parent maps the work that changes that: a shared foundation (tokens, a variant
and class-merge layer, six Stimulus primitives), a retrofit of the existing seven
onto it, and then a small number of components that earn their place.

**True north (reshaped 2026-09-13).** The kit ships the UI behaviour a Rails app would
otherwise rebuild in every project. A component either owns a Rails or Turbo concept,
or solves something genuinely hard to get right in a browser (Business rules, rule 0).
Anything that does neither is markup with classes, and the kit doesn't ship it. The
first cut of breadth mirrored shadcn/ui's catalog. Sixteen of those components were
built, then deleted against this rule, because a thin wrapper costs a class, tests,
a docs page and permanent API surface while giving a host app nothing it couldn't
write in one line.

shadcn/ui remains the source of the **token contract** (rule 2) and a reference for
component anatomy. Its catalog is not a roadmap, and parity with it is not an outcome
this work is measured by.

**Appetite.** This document is a map, readable in one sitting. It states the
architecture, the invariants every scope inherits, and the scope boundary. Every
mechanic, behavior and acceptance check lives in a child scope; the build loop
targets those, never this.

## Goal

`rails_ui_kit` reaches a state where adding a component means composing the shared
token, variant and behavior primitives — no component defines its own positioning,
focus management, scroll lock, presence handling, or color literals, and every public
component passes rule 0. Established when every scope indexed below has shipped or
been explicitly killed.

## Non-goals

- **Not a public library, and not shadcn/ui for Rails.** Feature parity with shadcn
  is not a goal, must not be written into any scope's acceptance, and is never by
  itself a reason to build a component (rule 0).
- **Not a design system or brand guideline.** The kit ships tokens and components;
  the visual language of any given client product is that product's business.
  Typography is a style-guide page in the docs app, not a component.
- **Not a charting library.** Chartkick covers it.
- **Not a data-table library.** Existing Rails table and pagination tooling covers it
  (`pagy` is already in the repo).
- **Not component ownership in v1.** The eject generator is deferred — see
  Out of scope / deferred.
- **Not a JavaScript-framework kit.** Server-rendered ViewComponents with Stimulus
  behavior. No React, no client-side rendering layer.
- **Not a rewrite of the `examples/` docs app.** It gains pages; it does not get
  rebuilt.

## Business rules

These are the invariants every child scope inherits. A scope may not weaken one; a
scope that needs to may not proceed without re-ratifying this parent.

**Admission, which precedes every rule below**

0. **A component earns its place by passing a gate.** A new public component, and any
   existing one under review, has to pass at least one of:
   - **Gate 1: it owns a Rails or Turbo concept.** Examples: `ActiveModel::Errors` and
     validators (a Field whose label marks `required` because the model's validators
     say so), `form_with` and `collection_select`, `flash`, Turbo Streams, Frames and
     the page cache, enums, i18n, routes.
   - **Gate 2: it is genuinely hard to get right in a browser.** Examples: focus
     management, anchored positioning, keyboard models, timing and exit animation,
     ARIA semantics. Tooltip and Popover pass here with no Rails content, and that's
     enough.

   A component that passes neither gate is not built. If it exists, it is deleted, and
   it is not kept as a docs recipe either. Passing a gate makes a component
   eligible, not scheduled: it is built when a client build needs it. Among eligible
   work, priority goes to how often client apps need it and what a wrong implementation
   costs (data loss, a destructive action, an accessibility failure).

**Must**

1. **Tokens, not literals.** Every component reads color, radius and control height
   from the CSS-variable design tokens. No component hardcodes a Tailwind palette class
   (`bg-white`, `dark:bg-gray-900`, `neutral-900`, and their kin), and no control types
   its height as a literal (`h-9`, `size-9`, and their kin): control height is the
   `--control-height*` scale `ui-control-sizing` owns. This applies to retrofitted
   components as strictly as to new ones. (Control height added 2026-09-14, Jonathan
   Simmons, once the tokens existed.)
2. **shadcn's token contract, ProductMatter's values.** The token *names* are
   shadcn/ui's, verbatim, so an external shadcn theme — including one generated by a
   tool like tweakcn — drops into a host Rails app unchanged. The default *values*
   are ProductMatter's own, expressed in `oklch()`. The token set is:
   `background`/`foreground`, `card`/`card-foreground`, `popover`/`popover-foreground`,
   `primary`/`primary-foreground`, `secondary`/`secondary-foreground`,
   `muted`/`muted-foreground`, `accent`/`accent-foreground`, `destructive`, `border`,
   `input`, `ring`, `chart-1`…`chart-5`, `sidebar` plus its seven variants, and
   `radius` (32 names). The set may also carry documented **kit extensions** —
   names outside shadcn's own vocabulary, each shipped with a default that degrades
   gracefully when an external theme doesn't define it — per `ui-design-tokens` §
   Business rules.
3. **One theme, two modes, one stylesheet.** Light and dark are the same token names
   redefined under `:root` and `.dark`. A class toggle switches modes. There is never
   a second stylesheet, a second component variant, or a second token vocabulary.
4. **Each cross-cutting behavior has exactly one implementation.** Anchored
   positioning, presence/open-state, the overlay stack, group navigation and field
   binding are shared primitives. Media-query watching is not, and was removed on
   2026-09-14: a component that swaps on a media query carries the query in its own CSS,
   where the browser applies it live. A component that needs one
   consumes it. A component may not reimplement one, and may not import
   `@floating-ui/dom` directly — only the positioning primitive may.
5. **The caller wins.** A `class:` passed by a consumer reliably overrides the
   component's own unmodified default classes. To override a modifier-scoped default
   (e.g. `has-[>svg]:px-3`), the caller passes the same modifier. That is a documented
   property of Tailwind class merging, not a defect.
6. **Accessibility is definition-of-done, not a later pass.** Every interactive
   component is keyboard-operable and exposes correct ARIA as part of the scope that
   introduces it. A scope that ships a component without keyboard operation and ARIA
   has not met its goal, regardless of what its other checks say.
7. **Nesting is not a special case.** A component behaves identically nested inside
   another overlay as it does standalone, and nested overlays dismiss in the reverse
   of the order they opened.

**Should**

8. **Adopt over build.** `class_variants` (avo-hq) is the variant layer;
   `tailwind_merge` (gjtorikian) is the class-merge layer. Both are maintained and
   Tailwind-v4-capable. Reimplementing either is a defect, not an optimization.
9. **Server-rendered first.** Structure is a ViewComponent; Stimulus carries behavior
   only. A component whose markup only exists after JavaScript runs is a smell.
10. **Batch the breakage.** Public-API breaking changes land in one minor release,
    not dribbled across several.

**May**

11. A scope may vendor a third-party component, or decline to build one, instead of
    implementing it — provided the decision and its rationale are recorded in that
    scope rather than left as a silent omission.

## Assumptions

What this work takes as given about systems it does not control, and what to do when
one contradicts the plan.

- **Two live consumers track this gem unpinned.** `productmatter/rails_foundation`
  and `bonnie-rails` both declare
  `gem "rails_ui_kit", git: "https://github.com/productmatter/rails-ui-kit.git", branch: "main"`.
  The foundation work changes the classes components render and is therefore breaking
  for both the moment it reaches `main`.
  **Precondition:** both consumers are pinned to the v0.2.0 tag or SHA *before* any
  foundation scope merges to `main`. That pinning is an action in those two
  repositories; no scope in this repo performs it, and no scope may assume it has
  happened.
  **At a contradiction** — a foundation scope ready to merge with either consumer
  still unpinned — stop and escalate to the decider. Do not merge, and do not
  invent a backwards-compatibility shim to route around it.
- **`@floating-ui/dom` is a peer dependency whose importmap exposure is version skew,
  not resolution.** **Corrected:** the pins in `config/importmap.rb` work today.
  `@floating-ui/dom@1.6.1`'s ESM dist contains no relative imports at all — only the
  three bare specifiers `@floating-ui/core`, `@floating-ui/utils` and
  `@floating-ui/utils/dom`, every one of them pinned — so the module graph closes and
  resolution succeeds. What is real is that importmap requires every *transitive* bare
  specifier to be pinned by hand: four pins whose versions must stay mutually
  compatible, shipped by an engine whose own README invites host apps to override any
  pin. A host that overrides `@floating-ui/dom` alone keeps the kit's `core` and
  `utils`, producing a mismatched graph that fails at runtime in the browser. That is a
  maintenance burden, not an impossibility, and collapsing to a single bundled pin is
  the improvement under consideration in `ui-positioning-and-navigation`
  § open-questions.md — a maintainability change, not a repair. **At a
  contradiction** — a pin combination that genuinely does not resolve — escalate to the
  decider; do not patch the package.
- **Testing stack.** ViewComponent core `TestHelpers` for render assertions; Capybara
  system tests for Stimulus behavior; `axe-core-capybara` + `axe-core-api` for
  accessibility assertions. **Corrected:** this repository is Minitest — `test/test_helper.rb`
  requires `minitest/autorun` and there is no RSpec anywhere — so `axe-core-rspec`, which
  ships RSpec matchers only, is unusable here and is not the assertion stack. There is
  also no `test/system/` lane yet; standing one up is `ui-test-harness`. If a behavior a
  scope needs cannot be asserted in this
  stack, escalate rather than shipping it unasserted or asserting something weaker
  and calling it done.
- **The adopted gems stay adopted.** `class_variants` v1.1.1 and `tailwind_merge`
  v1.5.5 are assumed maintained and Tailwind-v4-compatible; both were verified at
  shaping time. If either turns out incompatible or abandoned mid-build, that is a
  contradiction to escalate — not licence to fork it or write our own.
- **Tailwind 4 with the `engine.css` convention is the host pipeline.** The kit ships
  source CSS and tokens; the host app compiles. The kit does not ship compiled CSS.
- **shadcn/ui's catalog is a moving reference, not a contract.** Upstream adding,
  renaming or removing a component never invalidates a shipped scope here and is
  never grounds to reopen one.

## Critical files

Pointers, not descriptions — the code is the source of truth for what they do.

- `app/components/ui/` — the seven shipped ViewComponents (`.rb` + `.html.erb`
  pairs). The retrofit's subject.
- `app/javascript/rails_ui_kit/controllers/` — the eleven shipped `ui--*` Stimulus
  controllers. `app/javascript/rails_ui_kit/index.js` is the registration surface any
  new primitive has to appear in.
- `app/assets/tailwind/rails_ui_kit/engine.css` — the Tailwind 4 entrypoint; where
  the token layer lands.
- `app/assets/stylesheets/rails_ui_kit/components.css` — non-Tailwind component CSS.
- `lib/generators/rails_ui_kit/install/install_generator.rb` — the install
  generator. Every new asset, token surface or registration has to be reflected here
  or host apps get a kit that half-installs.
- `rails_ui_kit.gemspec` — the dependency surface; where `class_variants` and
  `tailwind_merge` are declared.
- `test/` — the Minitest suite and `test/test_helper.rb`.
- `examples/` — the docs app; the demonstration surface each new component appears in.

## Scopes

The child scopes this parent decomposes into. Each is an ordinary spec with its own
`spec.md`, its own acceptance partition, and `part_of: ui-component-library` in its
`relations.md`. This parent ships when its scopes ship.

**Phase A — Foundation (targets v0.3.0; breaking).** Build order within the phase is
harness → tokens → base → primitives → retrofit. The harness comes first because the
other four scopes' acceptance checks run inside it. Primitive build order inside the two
primitive scopes is presence (D) → overlay stack (B) → positioning (A) → group
navigation (C), then field binding (E). Media-query watching (F) was built here and
removed on 2026-09-14 (`ui-positioning-and-navigation` § Corrections).

| Scope | Owns | Depends on | Status |
|---|---|---|---|
| `ui-test-harness` | The `test/system/` browser lane: a Capybara base class on headless Chrome driving `examples/`, a `test:system` rake task separate from the five-Ruby unit lane, and `axe-core-capybara`/`axe-core-api` accessibility assertions. | — | ready-for-review |
| `ui-design-tokens` | The CSS-variable token layer: shadcn's names, ProductMatter's `oklch()` values, `:root`/`.dark` redefinition, install-generator surface. | `ui-test-harness` | ready-for-review |
| `ui-component-base` | `Ui::Base`: the `class_variants` variant layer and the `tailwind_merge` class-merge layer that makes rule 5 true. | `ui-design-tokens` | ready-for-review |
| `ui-presence-and-overlay-stack` | Primitives **D** (presence / open-state: `data-state="open\|closed\|closing"`, waiting on `animationend`/`transitionend` so exit animations run) and **B** (overlay stack: portal to a fixed root, focus trap, body scroll lock, Escape and outside-click dismiss, z-index and nesting order). | `ui-component-base`, `ui-test-harness` | ratified |
| `ui-positioning-and-navigation` | Primitives **A** (one wrapper over `@floating-ui/dom` emitting `data-side`/`data-align`, re-running on scroll and resize), **C** (roving tabindex / group nav: arrows, Home/End, optional first-letter typeahead, `aria-activedescendant` for listbox-style vs. real focus for menu-style), **E** (field binding: `Field`/`FieldLabel`/`FieldError` wiring `data-invalid` and `aria-invalid` from a Rails errors object, server-rendered). **F** (a `matchMedia` watcher) shipped here and was removed on 2026-09-14; media queries live in a component's own CSS. | `ui-presence-and-overlay-stack`, `ui-test-harness` | ratified |
| `ui-foundation-retrofit` | Moving Modal, Dropdown, Popover and Tooltip onto the token, base and primitive layers, and Confirm Dialog onto the overlay primitives, and deleting the three duplicated `@floating-ui/dom` positioning implementations. Toast, and Confirm Dialog's tokens and API, moved to `ui-toast` and `ui-confirm-dialog` on 2026-09-14. | `ui-positioning-and-navigation` | ratified |

**Alongside Phase A — Turbo patterns.** Additive and non-breaking. It builds on today's
Modal, so it doesn't wait for the retrofit, and the retrofit keeps its tests green.

| Scope | Owns | Depends on | Status |
|---|---|---|---|
| `ui-modal-turbo` | The blessed Modal + Turbo patterns and their full lifecycle, as real `examples/` demos driven by system tests; `ui--modal#closeOnSuccess` and the `turbo_stream.ui_close_modal` action; the canonical guide shipped in the gem; the opt-in `rails_ui_kit:agent_skill` generator. | `ui-test-harness` | ready-for-review |

**Phase B — Controls without a controller of their own.**

| Scope | Owns | Depends on | Status |
|---|---|---|---|
| `ui-presentational-components` | The shared convention for server-rendered components with no Stimulus controller, and the four that pass rule 0: Button, plus Input, Label and Textarea, the controls Field composes and binds to `ActiveModel::Errors`. It originally owned 20. The other 16 were built and then cut against rule 0 on 2026-09-13 (§ Out of scope). Typography stays a docs style-guide page, not a component. | `ui-component-base`, `ui-design-tokens` | ready-for-review |
| `ui-field-model-binding` | `Ui::FieldComponent.new(model:, attribute:)`, additive to the v0.3.0 `name:`/`errors:` form. It derives the name and id `form_with` emits, the model's errors, `form.label`'s text, and `required` from unconditional presence validators only, with an `aria-hidden` label marker. An invalid field's help text gives way to its error, animated through Primitive D when a morph delivers the change. The rule 0 Gate 1 example. The form builder is deferred by decision. | `ui-positioning-and-navigation`, `ui-presentational-components`, `ui-presence-and-overlay-stack`, `ui-select`, `ui-test-harness` | building |

**Phase C — Rails-aware interactive components.** Each owns a Rails form concept and
the browser behaviour that goes with it. Select composes several primitives at once;
Choices composes none, because native radios and checkboxes already carry the
behaviour, and ships one small controller only where the browser has no native
constraint. Tooltip, Popover, Dropdown, Modal, Confirm Dialog and Toast already ship;
the retrofit moved the first four onto the primitives. Toast and Confirm Dialog are still
on `ViewComponent::Base` with palette literals. Their rework, including the retrofit's half
for them, is `ui-toast` and `ui-confirm-dialog`.

| Scope | Owns | Depends on | Status |
|---|---|---|---|
| `ui-select` | `Ui::SelectComponent`: a Rails-aware select built from a collection, array, hash or model enum, with a select-only and a searchable combobox mode (APG), the real `<select>` kept as the single source of truth so it still submits, validates, resets and works without JavaScript; Field and Turbo integration; remote search designed for a later phase; supersedes Dropdown's `kind: :listbox`. | `ui-positioning-and-navigation`, `ui-presence-and-overlay-stack`, `ui-test-harness` | ready-for-review |
| `ui-toast` | Toast's one plain-data payload (`type`, `title`, `description`, `actions`, `duration`, `icon`) rendered identically from Ruby, `turbo_stream.ui_toast` and `window.triggerToast`. Content given alone becomes the description, reversing 0.2.0. Actions render through `Ui::ButtonComponent`, with a relative-or-`http(s)` URL rule. Action toasts don't auto-dismiss by default. Every countdown pauses on hover, focus and a hidden page, with a reduced-motion bar. Keyboard reach is F8 and Escape. The type glyph is a replaceable default. Toast moves onto `Ui::Base`, tokens (`--success`/`--warning`/`--info`) and Primitive D. It sets the shared convention for JavaScript-configured components. | `ui-component-base`, `ui-design-tokens`, `ui-presentational-components`, `ui-presence-and-overlay-stack`, `ui-localization`, `ui-test-harness` | ratified |
| `ui-confirm-dialog` | Confirm Dialog as a template whose contents are the caller's. No icon by default (decided 2026-09-14), with Ruby `icon` and `body` slots. `confirm_variant:` defaults to `:destructive`. Title, message, labels and variant reach the shared dialog from Ruby, `defaultConfirmDialog` and Turbo attributes, and reset per confirmation. The buttons become `Ui::ButtonComponent`, on tokens and `Ui::Base`. The class keywords merge instead of replacing. A regression check pins 0.2.0's render, all of it except the icon. | `ui-component-base`, `ui-design-tokens`, `ui-presentational-components`, `ui-presence-and-overlay-stack`, `ui-localization`, `ui-toast`, `ui-test-harness` | ratified |
| `ui-choices` | `Ui::ChoicesComponent`: a radio (`multiple: false`) or checkbox (`multiple: true`) group built from a collection, array, hash or enum through the shared `Ui::OptionSet` (moved out from under Select), in a list or wrapped-card appearance, with `collection_radio_buttons`/`collection_check_boxes` names, ids and `include_hidden` so unchecking everything clears the attribute. A `<fieldset>` named, described and marked invalid through Field. No JavaScript except one small controller that makes a required checkbox group mean "at least one". Passes Gate 1 (the Rails submission contract) and Gate 2 (group accessibility). | `ui-select`, `ui-field-model-binding`, `ui-presentational-components`, `ui-control-sizing`, `ui-localization`, `ui-localization-rtl`, `ui-test-harness` | ready-for-review |

A future scope enters this table only after passing rule 0, pulled by a client build.
Select, Toast, Confirm Dialog and Choices are the scopes in it; nothing is queued behind them.

**Across every phase — localization.** Two scopes, not one, because they are two
promises: what the kit *says* (translatable, host-overridable, already half-built) and how
it *lays out* (mirrored, which two ratified scopes deferred until a client needs it). The
first is ratifiable on its own; the second reverses a recorded deferral and is the
decider's call. Splitting them lets the strings work land without deciding RTL.

| Scope | Owns | Depends on | Status |
|---|---|---|---|
| `ui-localization` | The chrome/content boundary — the kit translates only what it says in its own voice, never what a call site writes — the per-instance override chain (call site → host locale → kit default) for all 15 chrome strings, CLDR plural categories through `Intl.PluralRules`, what the kit guarantees when translated text outgrows a fixed-height control, and the locale-switch, plural, pseudo-locale and hardcoded-string checks that keep it true. | `ui-select`, `ui-control-sizing`, `ui-presentational-components`, `ui-presence-and-overlay-stack`, `ui-test-harness` | ready-for-review |
| `ui-localization-rtl` | Direction hygiene, decided "convert now, promise later": the sixteen component classes and the docs app's physical classes become logical, what stays physical is named with its reason, and a guard fails on a new one. The RTL support claim — the two JavaScript behaviours direction changes, a `dir` switch, a browser pass, a native-reader gate — is costed there and deferred until a client build ships an RTL language. | `ui-localization`, `ui-positioning-and-navigation`, `ui-presence-and-overlay-stack`, `ui-select`, `ui-test-harness` | ready-for-review |

**Across Phases B and C — control metrics.** Additive, and invisible at every
component's defaults, so it doesn't reopen anything already verified.

| Scope | Owns | Depends on | Status |
|---|---|---|---|
| `ui-control-sizing` | Control height as three kit-extension tokens (`--control-height-sm`/`--control-height`/`--control-height-lg`), and Button's `sm`/`default`/`lg` scale extended to Input, Select and Textarea so a row of controls at one step lines up by reading one token. Button's existing sizes, including `icon`, render unchanged. | `ui-design-tokens`, `ui-presentational-components`, `ui-select`, `ui-test-harness` | ready-for-review |

## Out of scope / deferred

Each of these is a decision, not an oversight. Reopening one is a reshape of this
parent, not a scope-level call.

- **The eject generator (`rails g ui_kit:eject <component>`) — deferred to v2.**
  Distribution is decided as hybrid: the gem/Rails-engine dependency is the primary
  model (install the gem, render `Ui::ButtonComponent`, get upgrades free), and a
  future eject generator will copy a component's `.rb`, `.erb` and controller into the
  host app, where Rails autoload precedence makes the local copy win. The *model* is
  settled; the *implementation* is deferred because no external consumer needs
  component ownership yet, which makes registry and eject infrastructure speculative
  work against an unobserved need. Revisit when a real consumer needs to fork a
  component's markup.
- **The AI-chat family — cut.** Attachment, Bubble, Message, Message Scroller,
  Marker, Questionnaire. Narrow applicability to the client web products this kit
  serves, expensive to build well, and the newest and least-stable part of the
  reference catalog's own surface.
- **Chart — cut.** Use Chartkick.
- **Data Table — cut.** Use existing Rails table and pagination tooling; `pagy` is
  already in the repo.
- **Typography — not a component.** A style-guide page in the docs app plus classes.
- **Cut against rule 0 on 2026-09-13, deleted rather than kept as recipes:** Spinner,
  Separator, Skeleton, Item, Button Group, Progress, Native Select (superseded by
  `ui-select`), Empty, Alert (Toast covers notification), Badge, Avatar, Breadcrumb,
  Pagination, Table, Card and Input Group, plus Kbd and Aspect Ratio before them. None
  of these existed on `main` (0.2.0), so cutting them breaks no consumer.
- **The shadcn overlay and catalog roadmap: not planned.** Alert Dialog, Sheet, Drawer,
  Context Menu, Hover Card, Tabs, Menubar and Navigation Menu, along with Calendar,
  Date Picker, Carousel, Command, Input OTP, Resizable and Slider. The two planned
  scopes that held them, `ui-overlay-components` and `ui-deferred-component-decisions`,
  were never authored and are withdrawn. Any of them can come back as a new scope that
  passes rule 0 when a client build needs it.
- **Rails-aware reworks of cut components: not planned yet.** These are a flash banner,
  an error summary from `@record.errors`, a collection-aware empty state, an
  ActiveStorage avatar, and an enum-mapped badge. All would pass Gate 1, but none has
  a pulling need today.
- **Pinning `productmatter/rails_foundation` and `bonnie-rails` to v0.2.0 —
  out of this repo.** Recorded here as a blocking precondition of Phase A (see
  Assumptions); executed in those repositories.
