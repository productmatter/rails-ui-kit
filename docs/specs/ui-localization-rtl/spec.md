---
slug: ui-localization-rtl
type: feature
status: draft
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

**Appetite.** A mechanical conversion whose LTR rendering is provably unchanged, plus the
narrow set of behaviours that direction genuinely changes, plus the checks that stop the
next component from accruing a physical class. Not a review of how the kit *reads* in
Arabic or Hebrew — that needs a person who reads it, and that gate waits for the client
build that pulls it (§ Acceptance checks, human-gate).

## Goal

Every component renders mirrored in a document with `dir="rtl"` — padding, insets,
margins, anchored alignment, animation direction and horizontal arrow keys all follow the
writing direction — with no change to anything it renders in LTR, and a check fails the
build when a new physical direction class appears. Established when every agent-loopable
check in § Acceptance checks passes.

## Non-goals

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
- **The docs app's own chrome in RTL.** `examples/` gains a `dir` switch so components can
  be seen mirrored; its sidebar and layout are not part of the kit and are not converted.
- **Translating chrome** — `ui-localization`.

## Behavior

**Part 1 — direction-ready.** No promise to a host; the kit simply stops writing physical
classes where a logical one exists.

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

**Part 2 — RTL support.** What the kit promises a host that sets `dir="rtl"`.

6. **Anchored positioning mirrors, by Floating UI, not by us.** In an RTL document a
   `bottom-start` popup aligns to its anchor's right edge and a `bottom-end` popup to its
   left; `data-side` and `data-align` are unchanged, and `data-align` keeps meaning
   start/end rather than left/right.

7. **Horizontal arrow keys follow the direction.** `ui--roving-focus` with
   `orientation: horizontal` (or `both`) treats ArrowLeft as "next" and ArrowRight as
   "previous" when the group's computed direction is RTL, per WAI-ARIA. Vertical groups —
   every group the kit's own components create — are unaffected.

8. **The scroll lock holds the scrollbar's gutter on the side the scrollbar is on.**
   `applyLockStyles` compensates with `padding-right`; where a browser puts the viewport
   scrollbar on the left in an RTL document, that padding belongs on the left, or locking
   shifts the page sideways — the exact jump the gutter exists to prevent.

9. **A toast enters from the edge it sits on.** The container is inline-end anchored, so
   in RTL it sits at the left and its entry translate mirrors with it.

10. **The docs app can be seen mirrored.** `examples/` takes `dir` alongside the `locale`
    parameter `ui-localization` adds, and renders it on `<html>`. It is how the checks
    below run and how a person looks at it.

11. **The README says exactly what is verified.** Which behaviours mirror, that it is
    machine-verified in Chrome, and — until the human gate below happens — that no reader
    of an RTL language has reviewed it. A qualified promise, not a badge.

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
- `app/javascript/rails_ui_kit/controllers/roving_focus_controller.js` — `NEXT_KEYS` /
  `PREVIOUS_KEYS` and the key table they drive.
- `app/javascript/rails_ui_kit/overlay/overlay_stack.js` — `applyLockStyles`'s gutter.
- `app/javascript/rails_ui_kit/controllers/anchor_controller.js` — reads for
  understanding; not modified (§ Business rules, rule 5).
- `test/system/select_enhancement_test.rb` (SE2, SE3), `test/system/control_sizing_test.rb`
  (CS3, CS4), `test/system/anchor_position_test.rb` — the LTR geometry that must stay
  green unedited.
- `examples/app/controllers/application_controller.rb`,
  `examples/app/views/layouts/docs.html.erb` — the `dir` switch.

## Acceptance checks

### agent-loopable

- No physical direction utility appears in the kit's components, templates or controller class strings outside the allow-list in § Behavior, item 2, and the check is proved able to fail by planting `ml-2` on a component — run: `bundle exec rake test TEST=test/components/ui/logical_direction_test.rb`
- LTR rendering is unchanged: the existing geometry checks pass with no expectation edited — the Select box, its chevron and the popup's width match, the control-size alignment row, and anchored placement — run: `bundle exec rake test:system TEST=test/system/select_enhancement_test.rb && bundle exec rake test:system TEST=test/system/control_sizing_test.rb && bundle exec rake test:system TEST=test/system/anchor_position_test.rb`
- Under `dir="rtl"`: a Select's chevron, its show-options button and an option's checkmark sit at the left edge and its text starts at the right; a toast container sits at the top-left and a toast enters from the left; a confirm dialog's text starts at the right; every one of these mirrors its LTR measurement within a pixel — run: `bundle exec rake test:system TEST=test/system/direction_rtl_test.rb TESTOPTS="--name=/layout/"`
- Under `dir="rtl"`, a `bottom-start` dropdown aligns its right edge to its trigger's right edge and a `bottom-end` popover its left to the trigger's left, with `data-align` unchanged; the same holds when only a subtree carries `dir` — run: `bundle exec rake test:system TEST=test/system/direction_rtl_test.rb TESTOPTS="--name=/anchor/"`
- Under `dir="rtl"`, a horizontal `ui--roving-focus` group moves to the next item on ArrowLeft and the previous on ArrowRight, and a vertical group is unaffected; opening an overlay locks scroll with no horizontal shift — run: `bundle exec rake test:system TEST=test/system/direction_rtl_test.rb TESTOPTS="--name=/behaviour/"`
- The docs pages that carry a component demo pass `assert_accessible` with the document in RTL — run: `bundle exec rake test:system TEST=test/system/direction_rtl_test.rb TESTOPTS="--name=/accessible/"`
- The whole suite stays green — run: `bundle exec rubocop && bundle exec rake test && bundle exec rake test:system`

### judgeable

- Every physical class still in the kit is one § Behavior, item 2 names, with a reason
  that survives reading — not one the sweep missed. Judged against § Business rules,
  rule 1.
- The README's RTL statement claims only what the checks establish, including that no
  reader of an RTL language has reviewed the result. Judged against § Behavior, item 11.

### human-gate

- Jonathan compares each component's docs page LTR against RTL, side by side, and accepts
  the mirroring — in particular the toast's entry animation and the Select popup, which
  the measurements describe but do not show.
- **Deferred until a client build ships an RTL language:** a person who reads Arabic or
  Hebrew uses Select, Dropdown, Modal and Toast with a screen reader and says whether the
  kit reads correctly, not merely whether it is mirrored.

## Out of scope / deferred

- **Vertical writing modes** — not planned.
- **Logical Modal positions (`position: :start` / `:end`)** — not planned; a host picks a
  physical side (§ Non-goals).
- **Mirroring the `examples/` docs app's own layout** — the docs chrome is not the kit.
- **Bidirectional text isolation** (`<bdi>`, `unicode-bidi: isolate`) around content the
  host passes — a host mixing an English product name into Arabic text owns that, and the
  kit wrapping every slot would change the markup every component renders.
- **A pseudo-locale that reverses text** — the expansion pseudo-locale in
  `ui-localization` covers string discovery; a mirrored pseudo-locale adds nothing the
  `dir` switch does not.
