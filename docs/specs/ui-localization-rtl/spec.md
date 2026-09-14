---
slug: ui-localization-rtl
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: medium
size: large
target_model: standard
created: 2026-09-14
loop_budget: 4
---

## Intent

Translation moves words. Direction moves everything else: which edge a chevron sits on,
which way a drawer slides, which arrow key means "next". The kit has never been looked at
in a right-to-left document, and two scopes have already written the deferral down —
`ui-positioning-and-navigation` § Out of scope defers "RTL and logical-direction arrow key
mapping ... until a client product needs an RTL locale", and `ui-select` defers with it.
This scope is what reversing that deferral costs, measured rather than guessed.

**The measurement.** Sixteen classes across five components are direction-dependent
(§ Behavior, item 1). That is the whole mechanical change, and every one of them has a
logical replacement Tailwind 4.3.1 already compiles. It is smaller than the directive's
rough count of thirty because most of what looks physical is not: `left-1/2` with a
`-50%` translate centres a modal in either direction, `left-0 right-0` pairs are symmetric,
`origin-top` has no side, and flex `items-*` / `justify-*` already follow the writing
direction. The kit has no `origin-top-right` anywhere.

**Two facts settle the expensive-looking parts** (both verified against the bundled code,
not from memory):

- **Floating UI resolves `-start` / `-end` itself.** The importmap pins
  `@floating-ui/dom@1.6.1` through jsDelivr's `+esm` build, whose module graph closes over
  `core@1.6.0` and `utils@0.2.1`. `core@1.6.0`'s `computeCoordsFromPlacement` flips the
  alignment axis when the placement's side axis is vertical and `platform.isRTL(floating)`
  is true, and `dom`'s `isRTL` reads the floating element's computed `direction`. So a
  `bottom-start` menu aligns to the anchor's right edge in an RTL document with no code
  from us. The kit's overlays stay in their DOM position — they reach the top layer through
  `popover` and `<dialog>`, not through a portal (no `appendChild` anywhere in the overlay
  stack), so `direction` inherits normally. `data-align="start"` stays logical and needs no
  translation.
- **Tailwind 4.3.1 covers all but two of the conversions.** `ps-*`, `pe-*`, `ms-*`, `me-*`,
  `inset-s-*`, `inset-e-*`, `text-start`, `border-s`, `rounded-s-*` and `float-start` all
  compile (verified by compiling a scratch stylesheet with this repo's `tailwindcss-ruby`).
  The two gaps are `transform-origin` and `translate-x`, which have no logical form; there
  the physical utility pairs with Tailwind's `rtl:` variant, which compiles to
  `:where(:dir(rtl), [dir="rtl"], [dir="rtl"] *)`. Note `start-*` / `end-*` are deprecated
  upstream in favour of `inset-s-*` / `inset-e-*`, so the conversion uses the latter.

**What is left after that** is small and specific: two JavaScript behaviours (horizontal
arrow keys, the scroll-lock gutter), the toast's entry animation, and a way to see it —
the docs app taking a `dir`, and a browser pass that measures a mirrored layout.

**The ruling that shapes this scope** (2026-09-14, Jonathan Simmons): *convert now,
promise later.* The sixteen classes become logical and a guard test keeps them that way,
because "logical properties are just better CSS and carry no promise" — and because
"converting 11 components costs hours; converting 40 later is a project". The kit claims
no RTL support in its README or its docs, the native-RTL-reader gate stays deferred, and
the RTL-support half of this document moves to § Out of scope / deferred as a costed
plan. **This does not reverse the deferral `ui-positioning-and-navigation` and
`ui-select` recorded.** What those scopes deferred was the support *claim*; what changes
here is the CSS.

**Appetite.** A mechanical conversion whose LTR rendering is provably unchanged, and the
check that stops the next component from accruing a physical class. Nothing that a host
could read as a promise.

## Goal

No component writes a physical direction class where a logical one exists — sixteen
classes across five files — every physical class that remains is one this spec names with
its reason, a check fails the build when a new one appears, and nothing the kit renders
in a left-to-right document changes. Established when every agent-loopable check in
§ Acceptance checks passes.

## Non-goals

- **Claiming RTL support.** No README line, no docs page, no CHANGELOG bullet says the
  kit supports right-to-left. The conversion is hygiene a host never has to know about;
  the claim is a separate decision with a separate gate (§ Out of scope / deferred).
- **A second stylesheet, an RTL build, or an `[dir="rtl"]` override sheet.** One
  stylesheet, logical properties, exactly as `ui-component-library` rule 3 holds for
  light and dark.
- **Mirroring glyphs.** None of the kit's icons encode direction: a chevron points down, a
  checkmark is a checkmark, a close × and a warning triangle are symmetric. Directional
  glyphs are a problem the kit does not have and will not pre-solve.
- **Logical placement names in the anchored-positioning API.** Floating UI's sides are
  `top`/`right`/`bottom`/`left` and have no `start`/`end` form. `Ui::PopoverComponent` and
  `Ui::TooltipComponent` keep them, and their `-start`/`-end` *alignments* already flip.
- **Logical Modal positions.** `position: :left` and `:right` mean the physical side of
  the viewport, and their slide transforms are correct in both directions as written. A
  host that wants a drawer on the reading-start side picks the side it wants; a `:start`
  position would be new public API for no observed need.
- **Vertical writing modes** (`writing-mode: vertical-rl`). Japanese and Mongolian vertical
  text is a different problem, unasked for, and logical properties do not solve it alone.
- **A `dir` switch in the docs app.** That belongs to the deferred support claim. The docs
  app's own classes *are* converted and guarded, though (§ Behavior, item 7): it is not the
  kit, but a running docs app serving a mix of logical and physical classes is the
  half-converted state this scope exists to prevent.
- **Translating chrome** — `ui-localization`.

## Behavior

The kit stops writing physical classes where a logical one exists. No host-visible
behaviour changes, in either direction.

1. **The inventory: sixteen direction-dependent classes, in five files.**

   | File | Today | Becomes |
   |---|---|---|
   | `select_component.rb` (`CONTROL_CLASSES`) | `pl-3 pr-8` | `ps-3 pe-8` |
   | `select_component.rb` (`show_options_class`) | `right-0` | `inset-e-0` |
   | `select_component.html.erb` (chevron) | `right-2.5` | `inset-e-2.5` |
   | `select/listbox_component.rb` (`OPTION_CLASSES`) | `pl-2 pr-8` | `ps-2 pe-8` |
   | `select/listbox_component.html.erb` (checkmark) | `right-2` | `inset-e-2` |
   | `toast_container_component.rb` | `right-4` | `inset-e-4` |
   | `toast_component.html.erb` | `ml-3`, `ml-4` | `ms-3`, `ms-4` |
   | `toast_component.html.erb` (timer origin) | `origin-left` | `origin-left rtl:origin-right` |
   | `toast_component.html.erb` (enter/leave values) | `sm:translate-x-2` | pairs with `rtl:sm:-translate-x-2` |
   | `confirm_dialog_component.rb` | `text-left`, `sm:ml-3` | `text-start`, `sm:ms-3` |
   | `confirm_dialog_component.html.erb` | `sm:text-left`, `sm:ml-4` | `sm:text-start`, `sm:ms-4` |

2. **What stays physical, and why each is genuinely physical.** Stating this is half the
   scope's value: a later mechanical sweep must not "fix" them.
   - `Ui::ModalComponent`'s `:left` / `:right` positions (`inset-y-0 right-0 left-auto`
     and its mirror) and the `translateX(±100%)` slides in `components.css`: the caller
     named a side of the viewport.
   - `left-1/2` with `translate(-50%, …)` on the centred, top and bottom modals, and the
     `left-0 right-0` pairs on the full-width ones and the toast timer: symmetric, so
     they centre and span identically in either direction.
   - `origin-top` on the Dropdown, Popover and Select popups: no side.
   - Flex `items-*` and `justify-*`: `flex-start` / `flex-end` already follow direction.
   - `ui--anchor`'s inline `left` / `top` and the arrow's static side: Floating UI reports
     physical pixel coordinates from measured rects, which is correct in both directions.

3. **Where no logical utility exists, the physical one pairs with `rtl:`.**
   `transform-origin` and `translate-x` have no logical form in Tailwind 4.3.1; both take
   an `rtl:` companion. No other mechanism (no `[dir]` selector written by hand, no
   JavaScript reading direction to set a class).

4. **The caller still wins.** `tailwind_merge` 1.5.5 does not merge a caller's `pl-4`
   against the kit's `ps-3` — they are different properties to it — but Tailwind 4.3.1
   emits physical padding, margin and inset utilities *after* their logical counterparts,
   so the caller's class still wins on source order, in both directions (verified
   2026-09-14). `px-*` and `mx-*` do merge over `ps-*` / `pe-*`. The one exception is
   `text-start`, which Tailwind emits after `text-left`; it appears only in
   `Ui::ConfirmDialogComponent`, whose classes a caller replaces wholesale through
   `wrapper_class:` and its siblings rather than merging, so nothing regresses.

5. **A check fails on a new physical class.** The kit's component and controller sources
   carry no physical direction utility outside the allow-list item 2 names, and the
   allow-list is a list of decisions, not a ratchet of accidents.

6. **Nothing else moves.** No JavaScript reads direction, no docs page gains a `dir`
   switch, no README line appears. A host running LTR — every host today — cannot tell
   this scope happened, which is the point: it buys the option on RTL without paying for
   the promise (§ Out of scope / deferred).

7. **The docs app converts in the same pass** (added 2026-09-14, at the decider's
   direction, after a long-running dev server served the new logical classes against a
   stylesheet built before they existed and a mixed tree was seen mid-flight). All 110
   physical classes in `examples/app/views` — 96 of them `text-left` on table headers, plus
   the layout's sidebar inset, border and main offset, and one input group's radii and
   border — become logical, and the guard in item 5 scans the docs views too.

## Business rules

These refine `ui-component-library` § Business rules, rules 1, 3 and 5.

**Must**

1. **Logical by default.** A component uses the logical utility wherever one exists. A
   physical direction class is allowed only where the thing itself is physical, and every
   such class is listed in § Behavior, item 2 with its reason. "It looked fine in English"
   is not a reason.
2. **One stylesheet.** No `[dir="rtl"]` override sheet, no RTL build, no direction variant
   of a component. Where Tailwind has no logical utility, the `rtl:` variant pairs with the
   physical one in the same class list.
3. **Direction is the document's, never the kit's.** No component writes `dir` on an
   element it does not own, and no controller infers direction from a locale name. The
   kit reads computed direction where behaviour depends on it, and nothing else.
4. **LTR rendering does not change.** Every geometry assertion in the existing browser
   lane passes unedited, before and after the conversion. A logical utility that computes
   to a different value in LTR is a mistake, not a refinement.
5. **Anchored positioning is not reimplemented for direction** (parent rule 4). Floating
   UI resolves `-start` / `-end`; the kit neither pre-flips a placement nor post-corrects
   a coordinate.

**Should**

6. **Prefer the spelling upstream is keeping.** `inset-s-*` / `inset-e-*` over the
   deprecated `start-*` / `end-*`.

**May**

7. A component may keep a physical class for a decorative element whose orientation is
   intrinsic (a chevron that always points down), recorded in § Behavior, item 2.

## Assumptions

- **The pinned Floating UI graph is `dom@1.6.1` + `core@1.6.0` + `utils@0.2.1`**, resolved
  through jsDelivr's `+esm` build as one pin (`config/importmap.rb`). Read from the served
  bundle on 2026-09-14, along with the alignment flip in `computeCoordsFromPlacement` and
  `isRTL`'s computed-`direction` read. **At a contradiction** — a host overriding the pin
  onto a version that resolves alignment differently — the mirrored-alignment check fails
  and names it; escalate rather than pre-flipping placements in `ui--anchor`.
- **Top-layer elements inherit `direction` from their DOM ancestors.** The kit does not
  portal: overlays reach the top layer through `popover` and `<dialog>` in place. A host
  that sets `dir` on a subtree therefore gets mirrored popups inside it. **At a
  contradiction** — a browser that resolves inheritance from the top-layer root — the
  anchored-alignment check under a subtree `dir` fails; escalate.
- **Where the viewport scrollbar sits in an RTL document is browser- and
  platform-dependent, and headless Chrome on macOS cannot show it.** Measured 2026-09-14
  (Chrome 152 headless): `innerWidth - clientWidth` is 0 under both `dir=ltr` and
  `dir=rtl`, because macOS uses overlay scrollbars — so the gutter is 0 and the lock
  shifts nothing either way, which makes the check pass vacuously there. It is meaningful
  on a CI runner with classic scrollbars. § Behavior, item 8 is therefore written as
  "the side the scrollbar occupies", measured at lock time, rather than derived from
  direction. **At a contradiction** — a page that jumps sideways on lock in RTL —
  the fix is the measurement, not a direction lookup.
- **Tailwind 4.3.1's logical utilities and `rtl:` variant** are what the conversion
  compiles to; verified by compiling each replacement class with this repo's
  `tailwindcss-ruby`. `start-*` / `end-*` are deprecated upstream in favour of
  `inset-s-*` / `inset-e-*`. **At a contradiction** — a Tailwind upgrade dropping one —
  the affected class fails to compile and the geometry checks catch it.
- **`tailwind_merge` 1.5.5 treats logical and physical as different properties**
  (§ Behavior, item 4), so caller-wins depends on Tailwind's emission order for
  padding, margin and inset. Verified 2026-09-14. **At a contradiction** — a Tailwind
  version that emits logical last — a caller's `pl-*` would stop overriding; escalate,
  since the answer is a merger configuration decision, not a component edit.
- **No client product needs RTL today.** This scope exists because the decider asked what
  it would take, and because the conversion is cheapest before the catalog grows. **At a
  contradiction** — a client build that ships Arabic or Hebrew — the deferred human gate
  below stops being deferred.

## Critical files

- `app/components/ui/select_component.rb` and `select_component.html.erb`,
  `select/listbox_component.rb` and its template, `toast_component.html.erb`,
  `toast_container_component.rb`, `confirm_dialog_component.rb` and its template — the
  five files holding the sixteen classes.
- `app/components/ui/modal_component.rb` and
  `app/assets/stylesheets/rails_ui_kit/components.css` — the physical positions and slide
  transforms that stay as they are.
- `app/javascript/rails_ui_kit/controllers/roving_focus_controller.js` (`NEXT_KEYS` /
  `PREVIOUS_KEYS`), `app/javascript/rails_ui_kit/overlay/overlay_stack.js`
  (`applyLockStyles`'s gutter), `app/javascript/rails_ui_kit/controllers/anchor_controller.js` —
  read for understanding, modified by none of this scope; they are where the deferred
  half would land.
- `test/system/select_enhancement_test.rb` (SE2, SE3), `test/system/control_sizing_test.rb`
  (CS3, CS4), `test/system/anchor_position_test.rb` — the LTR geometry that must stay
  green unedited.

## Acceptance checks

### agent-loopable

- No physical direction utility appears in the kit's components, templates or controller class strings outside the allow-list in § Behavior, item 2, and the check is proved able to fail by planting `ml-2` on a component — run: `bundle exec rake test TEST=test/components/ui/logical_direction_test.rb`
- LTR rendering is unchanged: the existing geometry checks pass with no expectation edited — the Select box, its chevron and the popup's width match, the control-size alignment row, and anchored placement — run: `bundle exec rake test:system TEST=test/system/select_enhancement_test.rb && bundle exec rake test:system TEST=test/system/control_sizing_test.rb && bundle exec rake test:system TEST=test/system/anchor_position_test.rb`
- Each converted class computes to the same CSS as the class it replaced under `dir=ltr`, and to its mirror under `dir=rtl`, read from the compiled stylesheet rather than assumed — run: `bundle exec rake test TEST=test/tailwind_logical_utilities_test.rb`
- The whole suite stays green — run: `bundle exec rubocop && bundle exec rake test && bundle exec rake test:system`

### judgeable

- Every physical class still in the kit is one § Behavior, item 2 names, with a reason
  that survives reading — not one the sweep missed. Judged against § Business rules,
  rule 1.
- No README line, docs page or comment claims RTL support (§ Non-goals). Judged against
  § Behavior, item 6.

### human-gate

- None. The conversion is invisible to a host in LTR and claims nothing in RTL, so there
  is nothing for a person to accept that a measurement does not already settle. The two
  human gates RTL would need are deferred with the claim, below.

## Out of scope / deferred

- **The RTL support claim, and everything that would back it — deferred until a client
  build ships an RTL language** (decided 2026-09-14, Jonathan Simmons). This does not
  reverse `ui-positioning-and-navigation`'s and `ui-select`'s deferrals; it is the same
  deferral, now costed. What it would take, in full, so the day it is pulled nobody
  re-derives it:
  - **Nothing for anchored positioning.** The pinned Floating UI resolves `-start` /
    `-end` from the floating element's computed direction (§ Assumptions), and the kit
    does not portal, so alignment mirrors already. `data-align` stays logical.
  - **Two JavaScript behaviours.** `ui--roving-focus` must treat ArrowLeft as "next" in a
    horizontal group whose computed direction is RTL (WAI-ARIA); vertical groups — every
    group the kit's own components create — are unaffected. And the scroll lock must hold
    the scrollbar's gutter on the side the scrollbar occupies, measured rather than
    inferred from direction, or locking shifts the page sideways.
  - **One animation.** The toast container is inline-end anchored, so in RTL it sits at
    the left and its entry translate needs an `rtl:` companion.
  - **A way to see it:** `examples/` taking a `dir` parameter beside `ui-localization`'s
    `locale`, and a browser pass measuring the mirrored layout, the mirrored anchored
    alignment, the reversed arrow keys and `assert_accessible` in RTL.
  - **Two human gates:** Jonathan comparing each component LTR against RTL, and a person
    who reads Arabic or Hebrew saying whether the kit *reads* right rather than merely
    mirrors.
  Rough size: a day, most of it the browser pass — against hours for the conversion this
  scope does now.
- **Vertical writing modes** — not planned.
- **Logical Modal positions (`position: :start` / `:end`)** — not planned; a host picks a
  physical side (§ Non-goals).
- **Bidirectional text isolation** (`<bdi>`, `unicode-bidi: isolate`) around content the
  host passes — a host mixing an English product name into Arabic text owns that, and the
  kit wrapping every slot would change the markup every component renders.
- **A pseudo-locale that reverses text** — the expansion pseudo-locale in
  `ui-localization` covers string discovery; a mirrored pseudo-locale adds nothing the
  `dir` switch does not.
