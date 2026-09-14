---
slug: ui-positioning-and-navigation
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: high
size: large
target_model: frontier
created: 2026-09-07
loop_budget: 8
---

## Intent

Four of the six cross-cutting behaviors named in `ui-component-library` § Business
rules 4. Two are load-bearing and two are small, and the spec is weighted to match.

**A — anchored positioning** is the highest-leverage thing in Phase A. Three shipped
controllers (`dropdown`, `popover`, `tooltip`) each import `@floating-ui/dom` and each
hand-roll `position()`. The three implementations have already diverged: only
`dropdown` matches trigger width, only `tooltip` handles an arrow, and only `tooltip`
*omits* the scroll/resize re-position that the other two have. That is three chances
to fix a bug and three places to forget. Roughly ten components downstream want this
same behavior, so the divergence compounds rather than plateaus.

**C — roving tabindex / group navigation** is where the classic accessibility bug
lives. A menu moves real DOM focus; a combobox listbox must keep DOM focus in the text
input and move `aria-activedescendant` instead. Conflating the two produces a widget
that looks correct and is unusable with a screen reader. The shipped
`dropdown_controller` conflates them today — it calls `.focus()` on `[role="option"]`
elements for `kind: "listbox"`, which is the wrong model. Building this once, with
both models explicit, is the only way the overlay family in Phase C is affordable.

**E — field binding** and **F — media-query watching** are small by nature. E is
server-rendered and needs no JavaScript at all. F is a `matchMedia` wrapper that
Sidebar and Drawer need in Phase C. Neither earns much space here and neither gets it.

Rails has no Radix, so there is no primitive layer to adopt. This is the one place in
the plan where building rather than adopting is the correct call — `ui-component-library`
§ Business rules 8 prefers adoption, and no maintained Rails equivalent exists.

## Goal

`Ui::` components can obtain anchored positioning, two-model group keyboard navigation,
error-state field binding and breakpoint state by declaring a shared primitive, with
`@floating-ui/dom` imported in exactly one module in the repository and every primitive
releasing every listener, observer and `autoUpdate` handle on `disconnect()`.

## Non-goals

- **Not a component.** This scope ships behavior primitives plus the three
  server-rendered `Field` components. It ships no overlay, menu, tab or select.
- **Not the retrofit.** The three duplicated `position()` implementations are *specified
  as replaceable* here — deleting them and moving the seven shipped components across is
  `ui-foundation-retrofit`'s work.
- **Not presence or the overlay stack.** `ui--anchor` computes geometry. It never shows,
  hides, portals, traps focus or writes `data-state`.
- **Not a Floating UI re-export.** The primitive exposes the placements and middleware
  the kit's components need. Consumers do not reach past it into the library.
- **Not CSS Anchor Positioning.** See Assumptions.

## Behavior

### Primitive A — `ui--anchor`

One Stimulus controller wrapping `@floating-ui/dom`. It is the only module in the
repository permitted to import that package, and because `config/importmap.rb` pins
only `pin_all_from .../controllers`, the wrapper lives *in* `controllers/` rather than
in a shared module that would need its own pin.

| Target | Required | Role |
|---|---|---|
| `anchor` | yes | The reference element position is computed against. |
| `floating` | yes | The positioned element. Receives `data-side` / `data-align`. |
| `arrow` | no | Optional arrow; when absent the `arrow` middleware is not registered. |

| Value | Type | Default | Meaning |
|---|---|---|---|
| `placement` | String | `"bottom"` | Any Floating UI placement, e.g. `bottom-start`. |
| `offset` | Number | `8` | Main-axis distance in px. |
| `padding` | Number | `8` | `shift` / `flip` viewport padding. |
| `flip` | Boolean | `true` | Register the `flip` middleware. |
| `shift` | Boolean | `true` | Register the `shift` middleware. |
| `matchWidth` | Boolean | `false` | Set floating width to the anchor's offset width. |
| `strategy` | String | `"absolute"` | `absolute` or `fixed`; `fixed` is required once the overlay stack portals content. |
| `arrowPadding` | Number | `4` | Keeps the arrow off the floating element's corners. |
| `active` | Boolean | `false` | Positioning and `autoUpdate` run only while true. |

No `classes` API. Animation is CSS keyed off `data-side`, which is exactly why the
resolved side is published as an attribute.

**Published state.** On every computation the controller writes `data-side`
(`top|right|bottom|left`) and `data-align` (`start|center|end`) on the floating
element, derived from the *resolved* placement — after `flip`, not the requested one.
It dispatches `ui--anchor:positioned` with `{ x, y, placement, side, align }`.

**Arrow.** When an `arrow` target is present, the `arrow` middleware is registered and
the arrow's inline `left`/`top` are set from `middlewareData.arrow`, with the
static-side inset written to the side opposite the resolved side. `middlewareData.arrow`
is read defensively — the shipped `tooltip_controller` destructures it unguarded, which
throws whenever the middleware does not run.

**Lifecycle.** Setting `active` to true computes position and starts Floating UI's
`autoUpdate`. Setting it false, and `disconnect()`, both invoke the cleanup function
`autoUpdate` returns. A `ui--anchor` element removed from the DOM leaves behind no
scroll listener, no resize listener and no observer.

`ui--anchor` registers no `turbo:before-cache` handler, deliberately. It holds no open
state of its own — `disconnect()` already releases every listener and the `autoUpdate`
handle — so a page Turbo restores from cache re-positions from its own markup the next
time `active` goes true. A later reader should not add one.

**Composition.** Sibling controllers drive `ui--anchor` through a Stimulus outlet, not
by importing it. This is how `ui-presence-and-overlay-stack` and the Phase C overlays
consume positioning without reaching for `@floating-ui/dom` themselves.

**Capability parity.** The three implementations this replaces must lose nothing:
`matchWidth` and `bottom-start` from `dropdown`, `offset(8)`/`bottom` from `popover`,
and the arrow middleware plus static-side inset from `tooltip`. `autoUpdate` strictly
supersedes the `scroll`(capture)`+resize` pair that `dropdown` and `popover` register,
and closes the gap in `tooltip`, which registers neither and therefore drifts away from
its trigger on scroll today.

### Primitive C — `ui--roving-focus`

Generic group keyboard navigation for Tabs, Menubar, Dropdown and Context Menu,
Navigation Menu, Select and Combobox listboxes, and Accordion headers.

| Target | Required | Role |
|---|---|---|
| `item` | yes | The navigable items, in DOM order. |
| `input` | only in `activedescendant` mode | The element that retains real DOM focus. |

| Value | Type | Default | Meaning |
|---|---|---|---|
| `focusModel` | String | `"roving"` | `roving` or `activedescendant`. See below. |
| `orientation` | String | `"vertical"` | `vertical`, `horizontal` or `both`. |
| `loop` | Boolean | `true` | Wrap at the ends; false clamps. |
| `typeahead` | Boolean | `false` | First-letter matching. |
| `typeaheadTimeout` | Number | `500` | ms of idle before the typed buffer resets. |
| `activeId` | String | `""` | DOM id of the active item; the controller's single source of truth. |
| `skipDisabled` | Boolean | `false` | `false` leaves disabled items focusable but inert (see below); `true` skips them entirely. |
| `pageStep` | Number | `0` | Items `PageDown` / `PageUp` move. `0` leaves both keys alone. |

| Class | Applied to | Why |
|---|---|---|
| `active` | The active item | In `activedescendant` mode no item has DOM focus, so `:focus-visible` cannot style the active option. This is the only way to show it. |

**The two focus models, stated explicitly.**

- `roving` — menu style. Exactly one item carries `tabindex="0"`; every other item
  carries `tabindex="-1"`. Navigation calls `.focus()` on the new item and moves the
  `tabindex="0"`. Tab leaves the group entirely.
- `activedescendant` — listbox/combobox style. *Every* item carries `tabindex="-1"`.
  DOM focus never leaves the `input` target. Navigation sets `aria-activedescendant` on
  the input to the active item's id and moves the `active` class. Items must have ids;
  the controller assigns one where missing. A `mousedown` on an item is canceled
  (`preventDefault()`) before the browser can move DOM focus onto it, so a pointer click
  still activates the option without ever pulling focus out of the `input`.

A group declares its model. The controller never mixes them, and never calls `.focus()`
on an item in `activedescendant` mode.

**Keys.** `ArrowDown`/`ArrowUp` are handled when orientation is `vertical` or `both`;
`ArrowRight`/`ArrowLeft` when `horizontal` or `both`. `Home` and `End` jump to the first
and last item — the first and last *enabled* item when `skipDisabled` is `true`.
Printable single characters feed typeahead when enabled, under the same
`skipDisabled` rule. In `activedescendant` mode, an **editable** `input` target (a
combobox with a real text field) keeps `Home`, `End` and typed characters for itself —
they move the caret and type into the field, which is what an editable text input must
do — and the controller claims those keys for navigation only when the `input` target
is non-editable, i.e. a select-only combobox whose input is a read-only display field.
`PageDown` and `PageUp` move `pageStep` items at a time, and are unhandled while it is
`0`, which is every group that does not ask for them. A page counts only the items
navigation can reach, so hidden items, and disabled ones under `skipDisabled`, are not
counted. A jump stops at the first or last item rather than wrapping part-way through
it; only a jump that starts on that end item follows `loop`, exactly as an arrow key
pressed there does. The APG select-only combobox, which jumps ten, is what they are for.
`preventDefault()` is called only on keys actually handled, so an unhandled `ArrowLeft`
in a vertical menu still moves the caret in a nested input.

**Disabled items** — `[disabled]`, `[aria-disabled="true"]` or `[data-disabled]` — are
focusable but inert by default: arrows, `Home`, `End` and typeahead all reach them, and
a disabled item can hold the tab stop, but `Enter`, `Space` and clicks never activate
one, and a disabled link never navigates. This is the W3C ARIA Authoring Practices menu
pattern, not the "skipped by navigation" behavior an earlier draft of this spec
specified. The correction runs the other way from usual: the shipped
`dropdown_controller` (`032b33c`) already follows APG, because a screen reader user
discovers what a menu contains by moving through it, and skipping disabled items hides
options from exactly those users. **A primitive whose default contradicts the
component built on it guarantees divergence at retrofit** — `ui-foundation-retrofit`
would otherwise have to choose between matching Dropdown's shipped behavior and
matching this primitive's default. `skipDisabled` therefore defaults to `false`. A
group that genuinely wants disabled items unreachable — skipped by navigation,
`Home`/`End` and typeahead, and never tabbable — sets `skipDisabled: true`.

**Dynamic items.** Turbo Stream updates are the normal case, not an edge case. Stimulus
`itemTargetConnected` / `itemTargetDisconnected` re-normalise the group: after any
change exactly one enabled item is tabbable. If the active item is removed the active
position clamps to the nearest surviving enabled item. A group that ends up with zero
tabbable items is a defect — the user tabs into nothing.

The controller dispatches `ui--roving-focus:activated` with `{ item, id, index }`, and
exposes `focusFirst`, `focusLast` and `activate` as actions so pointer interaction can
keep the active item in sync with hover and click.

### Primitive E — field binding (server-rendered, no controller)

`Ui::FieldComponent` wraps a control, its label, an optional description and its
errors. It ships **no Stimulus controller** — `ui-component-library` § Business rules 9.

Given an `ActiveModel::Errors`-shaped object and an attribute name (or a plain array of
messages, so the components do not require ActiveRecord), the wrapper renders
`data-invalid` when errors are present, and the control receives `aria-invalid="true"`
and an `aria-describedby` that space-joins the description id and the error id.
`Ui::FieldLabelComponent` renders `for=` against the control id, and carries
`id="<control id>-label"` — derived the same way every other id here is, so a control
that `<label for>` cannot name, such as a `div role="combobox"`, points
`aria-labelledby` at it. `Ui::FieldErrorComponent` renders at that error id, with no
live-region role by default — the errors are present
at page load in the server-rendered case, and a `role="alert"` on every one of them
would announce the whole form on arrival. A `live:` option opts in for the Turbo Stream
single-field replacement case, where an alert is the correct behavior.

**`field_error_proc`.** Rails' default `ActionView::Base.field_error_proc` wraps errored
fields in `<div class="field_with_errors">`. That div lands *between* the field wrapper
and the control, which breaks direct-child and sibling selectors and any Tailwind
`peer` relationship the label/control pair depends on — the kit's error affordance is
already carried by `data-invalid` and `aria-invalid`, so the wrapper adds nothing and
costs layout. The kit's handling is two-sided: the install generator writes an
identity proc (`->(html_tag, _instance) { html_tag }`) into the host initializer, with
a comment explaining why and how to opt out; and `Ui::FieldComponent` styles from
`data-invalid` on the wrapper rather than from any selector a stray div could break, so
a host that keeps the default proc degrades in appearance but not in correctness. The
engine does **not** set the proc globally — silently changing how every form in a
client's application renders is not a change a UI kit gets to make unannounced.

### Primitive F — `ui--media-query`

A `matchMedia` wrapper. One value, `query` (e.g. `"(min-width: 768px)"`); one optional
class, `matches`; writes `data-media-matches="true|false"` on its element and dispatches
`ui--media-query:change` with `{ matches, query }`. It listens via
`MediaQueryList.addEventListener("change", …)` and removes that listener on
`disconnect()`. Sidebar and Drawer consume it in Phase C. That is the whole primitive.

### Registration and test infrastructure

The three controllers register as `ui--anchor`, `ui--roving-focus` and
`ui--media-query` in `registerControllers` in `app/javascript/rails_ui_kit/index.js`,
matching the `ui--` prefix every shipped controller already uses.

Keyboard behavior cannot be asserted by rendering markup, so most of this scope's
acceptance checks are browser tests. They run in the system-test lane `ui-test-harness`
owns and ships first — the `ApplicationSystemTestCase` base class on headless Chrome
driving `examples/`, the separate `test:system` rake task that keeps the browser out of
the five-Ruby unit lane, and the `assert_accessible` helper that lives on that base
class. This scope consumes that lane: it writes test files under `test/system/` which
inherit the base class, and registers no driver, no rake task and no axe wiring of its
own (§ Business rules of ui-test-harness, rule 5; `relations.md` carries the edge).

## Business rules

Inherits every rule in `ui-component-library` § Business rules unmodified; rules 4, 6
and 9 do most of the work here. The following are scope-local and refine rule 4 for
these four primitives.

**Must**

1. **One importer.** Exactly one module in the repository imports `@floating-ui/*`.
   Any second importer is a defect regardless of what it needs.
2. **Nothing outlives its element.** Every listener, observer and `autoUpdate` handle a
   primitive registers is released in `disconnect()`. A primitive whose element is
   removed from the DOM leaves no live subscription behind.
3. **Geometry only.** `ui--anchor` computes and publishes position. It never changes
   visibility, never writes `data-state`, never moves focus and never portals — those
   belong to `ui-presence-and-overlay-stack`.
4. **Both focus models, never blended.** A roving group declares `roving` or
   `activedescendant`. In `activedescendant` mode the controller never calls `.focus()`
   on an item; in `roving` mode it never sets `aria-activedescendant`.
5. **Always exactly one tab stop.** A roving group has exactly one tabbable item at all
   times, including immediately after items are added or removed by Turbo. That item is
   enabled except in the default `skipDisabled: false` mode, where a focused disabled
   item legitimately holds the tab stop — it is reachable and inert, not absent from the
   sequence (§ Behavior, Primitive C, "Disabled items").
6. **Resolved, not requested.** `data-side` and `data-align` describe where the element
   actually landed after collision handling, never the requested placement.
7. **Behavior only.** Primitives render no markup and write no class except through a
   declared Stimulus `classes` API, which keeps rule 1 of the parent trivially true for
   them.
8. **One atomic pin.** Floating UI reaches importmap consumers as a single pin whose
   transitive graph cannot skew. See Assumptions.

**Should**

9. Primitives compose through Stimulus outlets and DOM events, not by importing one
   another.

## Assumptions

Inherits `ui-component-library` § Assumptions. Two of them were checked against the
live repository and the registry, and one did not survive.

- **The pins in `config/importmap.rb` work today.** The parent originally recorded that
  "the raw npm package's extensionless internal imports do not resolve under importmap";
  the evidence below is what corrected it, and § Assumptions of ui-component-library now
  states the real exposure. Verified against the actual artifacts: `@floating-ui/dom@1.6.1`'s
  `dist/floating-ui.dom.mjs` contains **no relative imports at all** — its only
  specifiers are the bare `@floating-ui/core`, `@floating-ui/utils` and
  `@floating-ui/utils/dom`. `@floating-ui/core@1.6.0` imports only `@floating-ui/utils`;
  both `@floating-ui/utils@0.2.1` entry points are leaves with zero imports. All four
  specifiers are pinned in `config/importmap.rb`, so the module graph closes and
  resolution succeeds. The pinned versions also satisfy dom@1.6.1's declared ranges
  (`core ^1.6.0`, `utils ^0.2.1`). **Nothing is broken today.** The real constraint is
  narrower: importmap requires every *transitive bare specifier* to be pinned — a
  maintenance burden, not an impossibility.
- **The live risk is version skew across four hand-maintained pins, not resolution.**
  `config/importmap.rb` is shipped by the engine and its header invites host apps to
  "override any pin." A host that overrides `@floating-ui/dom` alone keeps the kit's
  `core@1.6.0` and `utils@0.2.1`, producing a mismatched graph that fails at runtime, in
  the browser, in a client product. Collapsing to one pin removes the failure mode by
  construction: a CDN-bundled build such as
  `https://cdn.jsdelivr.net/npm/@floating-ui/dom@1.6.1/+esm` emits origin-absolute
  `/npm/…/+esm` specifiers that resolve against the CDN without any importmap entry
  (all three transitive URLs verified reachable), so `@floating-ui/core` and
  `@floating-ui/utils` are removed from `config/importmap.rb` entirely and the version
  set moves and is overridden as one unit. This is a maintainability fix, not a repair.
  **Decided 2026-09-13, Jonathan Simmons: option (a).** `config/importmap.rb` now pins
  a single `@floating-ui/dom` entry at
  `https://cdn.jsdelivr.net/npm/@floating-ui/dom@1.6.1/+esm`; the `core` and `utils`
  pins are deleted. The former open question is resolved and removed from
  `open-questions.md`.
- **The accessibility assertion stack is settled: `axe-core-capybara` plus
  `axe-core-api`.** `axe-core-rspec`, which the parent originally named, ships RSpec
  matchers only and is unusable in a Minitest repository with no RSpec. The two usable
  gems both publish at 4.13.0 and are asserted directly from Minitest through the
  `assert_accessible` helper `ui-test-harness` puts on the system-test base
  class — never in `test/test_helper.rb`, which would pull Capybara into the unit lane
  (§ Business rules of ui-test-harness, rules 1 and 4). This scope consumes that helper
  and adds no axe wiring of its own.
- **`pin_all_from` covers only `controllers/`.** A shared non-controller module under
  `app/javascript/rails_ui_kit/` would not be pinned and would 404 for importmap
  consumers. This is why the Floating UI wrapper is a controller rather than a library
  module, and it constrains any future primitive the same way.
- **CSS Anchor Positioning is not viable as the primary mechanism.** As of late 2026
  Firefox support is partial, and the missing part is precisely the fallback/flip
  behavior that `flip` and `shift` exist to provide. It is recorded as a future
  replacement to watch — a thing that could one day delete this primitive — and is a
  dependency of nothing in this scope.

## Critical files

- `app/javascript/rails_ui_kit/controllers/dropdown_controller.js`,
  `popover_controller.js`, `tooltip_controller.js` — the three duplicated `position()`
  implementations, and the parity baseline. Read before touching `ui--anchor`.
- `app/javascript/rails_ui_kit/index.js` — `registerControllers`; the registration
  surface every new primitive appears in.
- `config/importmap.rb` — the Floating UI pins and the `pin_all_from` constraint.
- `package.json` — declares `@floating-ui/dom` a peer dependency for bundler consumers.
- `lib/generators/rails_ui_kit/install/install_generator.rb` — where the
  `field_error_proc` initializer and any pin change have to be reflected.
- `test/application_system_test_case.rb`, `test/system/` — the base class and lane
  `ui-test-harness` ships; this scope's browser checks are files added under them.
- `app/components/ui/` — the shape the `Field` components follow.

## Acceptance checks

### agent-loopable

- `@floating-ui/*` is imported in exactly one module in the repository — **pending on `ui-foundation-retrofit`**: `dropdown_controller.js`, `popover_controller.js` and `tooltip_controller.js` still import it directly until that retrofit removes them, so this check is expected red, not failing, while the retrofit is in progress — run: `test "$(grep -rl '@floating-ui' app/javascript --include='*.js' | grep -v 'anchor_controller.js' | wc -l | tr -d ' ')" = "0"`
- Floating UI resolves from a single importmap pin, and no unpinned bare specifier remains in its module graph — run: `bundle exec rake test TEST=test/importmap/floating_ui_pins_test.rb`
- `ui--anchor` publishes `data-side` and `data-align` from the resolved placement, including after a collision forces a flip — run: `bundle exec rake test:system TEST=test/system/anchor_position_test.rb`
- `ui--anchor` supports an optional arrow and does not raise when no arrow target is present — run: `bundle exec rake test:system TEST=test/system/anchor_arrow_test.rb`
- Removing an active `ui--anchor` element stops all positioning work — no further `ui--anchor:positioned` events fire on scroll or resize — run: `bundle exec rake test:system TEST=test/system/anchor_cleanup_test.rb`
- In `roving` mode arrows, Home and End move real DOM focus, disabled items are focusable-but-inert by default and skippable under `skipDisabled: true`, wrapping follows `loop`, and exactly one item is tabbable — run: `bundle exec rake test:system TEST=test/system/roving_focus_menu_test.rb`
- In `activedescendant` mode DOM focus stays on the input, `aria-activedescendant` tracks the active option, and no option is ever focused — run: `bundle exec rake test:system TEST=test/system/roving_focus_listbox_test.rb`
- `PageDown` and `PageUp` move `pageStep` navigable items, clamp at the ends and are left alone while `pageStep` is `0` — run: `bundle exec rake test:system TEST=test/system/roving_focus_page_keys_test.rb`
- A roving group still has exactly one tabbable enabled item after items are added and removed by a Turbo Stream update, including removal of the active item — run: `bundle exec rake test:system TEST=test/system/roving_focus_dynamic_test.rb`
- Typeahead selects by first letter and resets its buffer after `typeaheadTimeout` — run: `bundle exec rake test:system TEST=test/system/roving_focus_typeahead_test.rb`
- `Ui::Field` renders `data-invalid`, `aria-invalid`, a space-joined `aria-describedby` from an errors object and a label id derived from the control id, and emits no `.field_with_errors` wrapper — run: `bundle exec rake test TEST=test/components/ui/field_component_test.rb`
- `ui--media-query` reflects breakpoint state and releases its `change` listener on disconnect — run: `bundle exec rake test:system TEST=test/system/media_query_test.rb`
- The primitives demo page has no accessibility violations — run: `bundle exec rake test:system TEST=test/system/primitives_a11y_test.rb`
- `registerControllers` registers `ui--anchor`, `ui--roving-focus` and `ui--media-query` — run: `bundle exec rake test TEST=test/javascript/register_controllers_test.rb`

### judgeable

- `ui--anchor` loses no capability present in the three implementations it replaces —
  `matchWidth`, arrow with static-side inset, and per-component placement and offset
  defaults all survive — judged against `ui-component-library` § Business rules 4 and 9.
- `ui--anchor` stays inside its boundary: it computes geometry and publishes attributes,
  and does not show, hide, portal, trap focus or write `data-state`, per the split
  recorded in this spec's § Out of scope / deferred.
- The two focus models are genuinely distinct in the implementation rather than one model
  with a flag, and each produces the ARIA a screen reader expects — judged against
  `ui-component-library` § Business rules 6, which makes keyboard operation and correct
  ARIA definition-of-done rather than a later pass.
- The primitives introduce no hardcoded Tailwind palette class and render no markup,
  satisfying `ui-component-library` § Business rules 1 and 7 by construction.
- The `field_error_proc` handling changes host application behavior only through the
  install generator and never from the engine, consistent with the "no silent
  backwards-compatibility shims" posture in `ui-component-library` § Assumptions.

### human-gate

- Jonathan uses the primitives demo with a keyboard and judges the feel: the typeahead
  timeout, whether flip produces visible jitter during scroll, and whether the active
  item in `activedescendant` mode reads as clearly as a real focus ring.
- Jonathan confirms that writing an identity `field_error_proc` into a host application's
  initializer is an acceptable thing for the install generator to do.

## Out of scope / deferred

- **Presence / `data-state` and the overlay stack** — owned by
  `ui-presence-and-overlay-stack`. `ui--anchor` deliberately does not know whether its
  floating element is visible.
- **Migrating the seven shipped components** — owned by `ui-foundation-retrofit`. This
  scope specifies parity and leaves `dropdown_controller.js`, `popover_controller.js`
  and `tooltip_controller.js` in place; deleting their `position()` implementations is
  the retrofit's job. The `dropdown_controller`'s incorrect listbox focus model is
  likewise recorded here and corrected there.
- **Building the Phase C components** that consume these primitives — Tabs, Menubar,
  Select, Combobox and the rest are `ui-overlay-components`.
- **CSS Anchor Positioning** — a future replacement to watch, not a dependency. Revisit
  when Firefox ships full fallback support.
- **RTL and logical-direction arrow key mapping** — deferred until a client product
  needs an RTL locale. `orientation` covers the axis; direction reversal does not.
- **Virtualized or very large listboxes** — `ui--roving-focus` walks its `item` targets.
  Windowing is a Combobox-scale problem and is not solved here.
- **Drag, resize and manual repositioning** of floating elements — no consuming
  component needs it.
