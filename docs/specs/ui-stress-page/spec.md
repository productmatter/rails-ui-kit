---
slug: ui-stress-page
type: chore
status: building
decider: Jonathan Simmons
blast_radius: medium
size: large
target_model: frontier
created: 2026-09-15
loop_budget: 8
---

## Intent

**Jonathan asked: "Do we need some sort of UI stress test?" Yes.** Every browser test on this
branch drives one component on its own docs page. Nothing drives them into each other. Nearly
every real defect this branch found was a collision:

- a Dropdown inside a Modal;
- one popover displacing another;
- the scroll lock releasing early when two overlays nested;
- an overlay that wouldn't reopen mid-animation;
- a toast unreachable over a Modal;
- a Confirm Dialog with no controller, because the docs layout supplied one that a host never
  gets.

A single-component page can't catch any of those. The last one is worse: the docs app hid it.

`ui-component-library` § Business rules, rule 7 says nesting is not a special case. Today that
is asserted pair by pair, in whichever suite happened to think of a pair. This scope turns it
into a property the whole kit is checked against, under the conditions that break things.

**Three parts, one scope:**

- **A page.** It holds the whole kit at once, in a host-shaped layout.
- **A condition matrix.** Theme, motion, viewport, direction, locale and Turbo are each a
  dimension of the same page, not a copy of it.
- **A sequence generator.** It composes overlays from a table and ends *every* sequence with
  the same invariant check. The check is a shared helper any component suite can adopt.

The invariants are the point. A list of scenarios only covers the ones someone thought of. An
invariant also holds after the ones nobody did.

**Why one scope.** The page, the matrix and the generator are only useful together. The page
without the invariants is a demo. The invariants without the page are checks with nothing to
collide. The generator without both is a list of scenarios.

**Appetite.** One hidden page and its layout, one small demo controller and an ActiveModel form
object, one shared invariant helper with a self-test, and eight test files. No component changes,
except defects the suite finds (§ Business rules, rule 9) and the morph guard in `ui--overlay` the
second ruling in `open-questions.md` adds.

## Goal

Every overlay composition the stress page allows, and every Turbo swap it can suffer, ends with
the page back in a state the kit promises. That means no scroll lock, no stray top-layer or open
element, no dishonest `aria-expanded`, focus somewhere real, a clean accessibility audit, a
silent console, every kit controller connected and no duplicate or dangling id. This holds
under six condition profiles that between them pair every condition with every other. It is
established when the eight stress files each pass run on their own, and when every invariant has
been seen to fail on a planted fault.

## Non-goals

- **Not a replacement for component suites.** Each component's promises stay asserted in its
  own files. The stress suite checks what holds *between* components, and a defect it finds
  gets pinned in the owning component's suite too (§ Business rules, rule 9).
- **Not visual or layout assertion.** Beyond the invariants, nothing is measured: no pixel
  positions, no anchored placement, no clipping, no screenshot. Geometry appears only as a
  precondition that proves a reference is real (§ Business rules, rule 5).
- **Not a second docs page.** No prose, code samples, sidebar entry or index listing.
- **Not the RTL support claim.** Direction runs as a smoke (§ Behavior, item 7). The claim stays
  deferred in `ui-localization-rtl` § Out of scope / deferred.
- **Not a fuzzer.** Sequences are generated from a fixed table, so every run is the same run.
  Randomised order or timing would make a red build unreproducible.
- **Not cross-browser.** One headless Chrome, as `ui-test-harness` § Out of scope / deferred
  decides.
- **Not a CI reshape, within budget.** The single `test-system` job runs the stress files like
  any other, and this scope measures the time it adds. Up to 15 minutes added is accepted
  (`open-questions.md`, settled 2026-09-15). Only if the measured lane goes over is the system job
  sharded by directory, and coverage is not trimmed to fit (§ Assumptions).

## Behavior

### The page

1. **Hidden, reachable by URL.** `GET /stress` renders the page. It is not in
   `DocsPages::PAGES`, so no sidebar link, index entry, docs-registry test or
   `DocsController` action reaches it. It has its own route and controller. It's a test
   fixture, and listing it would invite documentation-grade upkeep and readers who take it for
   guidance.

2. **A host's layout, not the docs layout.** The page renders in its own layout, which holds
   only three things:
   - what `rails_ui_kit:install` tells a host to render: `Ui::ConfirmDialogComponent`,
     `Ui::ToastContainerComponent` with the flash, and the
     `ui--turbo-confirm ui--turbo-disable-with` element;
   - the dark-mode setup the Dark Mode page documents for a host;
   - `lang`, a `<title>`, one `<main>`, one `<h1>`, and
     `turbo_refreshes_with method: :morph`.

   There's no sidebar and no docs chrome. The docs layout masking a missing controller is a
   defect class this suite exists to catch, so the fixture must not repeat it. A difference
   between this layout and the install generator's instructions is a failing judgeable check.

3. **Contents.** Each part is on the page for a named collision:

   | Region | What renders | Why it's here |
   |---|---|---|
   | **Form** | `form_with` over an ActiveModel object built for this page (`StressRecord`): Field + Input (required via a presence validator), Field + Textarea, Field + Select `search: false` over an enum attribute, Field + Select `search: true` over a collection, Field + Choices `multiple: false` `variant: :list`, Field + Choices `multiple: true` `variant: :card` with the required "at least one" group, and a submit Button. Invalid responds `422`. Valid responds with a toast: a Turbo Stream when Turbo is on, a flash across a redirect when it's off. | The form controls' controllers must survive a `422` re-render, a full reload and a morph. Field's error swap and Select's mirror must hold with overlays around them. |
   | **Size row** | Button at `sm`, `default`, `lg` and `icon`, and Input and Select `search: false` at `sm`, `default` and `lg`, each labelled. | Three more Select instances every swap must leave connected. `sm` targets are audited at 320 px and under pseudo-locale expansion. |
   | **Overlay cluster** (page) | A partial: Dropdown `kind: :menu` (one item that closes it, one link to another page); Dropdown `kind: :dialog` holding a Select `search: false` and a link out; a Popover beside the menu Dropdown; a Tooltip on a Button with `aria-disabled="true"`; a neutral outside region. | Auto popovers displacing each other, a hint beside a layer, and a listbox inside a layer. |
   | **Modal** | A link with `data-turbo-frame` into a `<turbo-frame>` marked `data-turbo-permanent`, as `ui-modal-turbo` § Behavior item 2 and the guide describe, loading `GET /stress/modal`. Inside: **the same overlay cluster partial**, a Field + Select `search: true`, a Button whose `data-turbo-confirm` opens the shared Confirm Dialog over the Modal, a Button that answers with `turbo_stream.ui_toast` carrying a dismiss-only action, a link to another page, and a neutral outside region. | Rule 7 as page structure: everything on the page also renders inside the Modal, and its ids must not collide. It covers the Confirm Dialog over a Modal, a toast fired while a Modal is open, and a listbox over a dialog. |
   | **Theme toggle** | The documented dark-mode toggle. | The theme condition is applied through the real controller, not a class written by the test. |

   The cluster partial takes an id prefix, so it renders twice with distinct ids. The
   duplicate-id invariant is what proves the prefixing holds.

4. **Deliberately not on the page:**
   - **A native `disabled` Button with a Tooltip.** The Tooltip page documents that such a
     control is unreachable by keyboard, so there's no promise to stress.
     `aria-disabled="true"` is the documented pattern, and it's on the page.
   - **Dropdown `kind: :listbox`.** Removed by `ui-select` § Behavior, item 36.
   - **Remote search (`search_url:`).** A later phase in `ui-select`, with an endpoint of its
     own.
   - **Modal `track_changes:` and its dirty-form veto.** It's regression-pinned by
     `ui-foundation-retrofit`, and it would put a confirmation in front of every Modal
     dismissal, multiplying the whole Modal half of the table for one contract.
   - **A Modal inside a Modal.** The kit has one Modal container. A second Modal replaces the
     first (`ui-modal-turbo` § Behavior, item 10), which is a stream sequence here, not a
     nesting.
   - **A page-level Confirm Dialog, Toast flash or standalone overlay on its own.** Standalone
     behaviour is the component suites', and this page exists for what they can't reach.
   - **The overlay cluster inside a Dropdown or Popover.** One level of layer-in-layer (a
     Select in a dialog Dropdown) exercises the popover stack, and more depth adds sequences,
     not mechanisms.
   - **Fixture locales, a Toast countdown, Theming tokens, primitives on custom elements.** Each
     is its own suite's promise and has no collision to add.

### The conditions

5. **Six dimensions, applied by the test, each proven applied.** None is a copy of the page:

   | Dimension | Values | How it's applied |
   |---|---|---|
   | Theme | light, dark | Clicking the theme toggle, after `localStorage` is cleared. |
   | Motion | full, reduced | Emulated `prefers-reduced-motion: reduce` through the driver's CDP session. |
   | Viewport | 1400 px, 320 px | Emulated device metrics through CDP. |
   | Direction | `ltr`, `rtl` | `dir="rtl"` set on `<html>` by the test. |
   | Locale | `en`, pseudo | `?locale=` with `ui-localization`'s pseudo-locale, the parameter the examples app already reads. |
   | Turbo | on, off | `?turbo=off` renders the form with `data-turbo="false"`. It is a render parameter of the one page. |

   Before a sequence runs, and again when the invariants run, the test proves each condition is
   in force: `matchMedia` matches, `innerWidth` is 320, `<html>` has `dir="rtl"` or the `.dark`
   class, or a kit chrome string carries the pseudo-locale's marker. A condition that silently
   failed to apply would turn a whole profile into a second baseline run. Teardown undoes every
   condition, because CDP emulation outlives a test in a shared browser session, and the
   baseline profile's precondition check proves that nothing leaked into it.

6. **Six profiles that pair every condition with every other.** The full product of six
   two-value dimensions is 64 profiles. One dimension flipped at a time is 7 profiles, but dark
   mode then never meets 320 px. Six rows cover every pair of values of every two dimensions
   (a strength-2 covering array, checked exhaustively at authoring time), so every two-condition
   collision happens at least once:

   | Profile | Theme | Motion | Viewport | Direction | Locale | Turbo |
   |---|---|---|---|---|---|---|
   | P0 baseline | light | full | 1400 | ltr | en | on |
   | P1 | dark | reduced | 1400 | rtl | en | off |
   | P2 | dark | full | 320 | ltr | pseudo | off |
   | P3 | dark | full | 1400 | rtl | pseudo | on |
   | P4 | light | reduced | 320 | rtl | en | on |
   | P5 | light | reduced | 320 | ltr | pseudo | off |

   The Turbo column only changes the form sequences. Elsewhere the page is identical with it
   on or off.

7. **Direction is a smoke, not a check.** Under `rtl` every invariant must hold, and nothing
   direction-specific is asserted: no mirrored placement, no reversed arrow keys, no
   scroll-lock gutter side. Those are the RTL support claim, which `ui-localization-rtl`
   deferred with a cost attached. Asserting them here would reverse that deferral through a test
   fixture. What the smoke does catch is cheap and real: an RTL page that throws, strands focus,
   leaves a lock or fails the audit. The direction is set by the test, not by a `dir` parameter
   in the examples app, because that switch is part of the same deferral.

8. **`SLOW=1` is an invocation, not a dimension.** Per `ui-test-harness` § Business rules,
   rule 7, no test reads it and CI never sets it. The stress suite must pass under it, and that
   is checked once at build on the baseline file. The baseline file holds every request shape
   the suite makes, and the other profiles repeat those shapes under different conditions, not
   different latency.

### The invariants

9. **Checked at the end of every sequence, in this order**, with each failure naming the
   sequence, the profile and the offending element:
   1. **No scroll lock left.** `<html>`'s and `<body>`'s inline style equal the snapshot taken
      on arrival, or, while an overlay the sequence declares open holds the lock, the lock is
      held. Every release since arrival put the scroll position back where the lock took it.
      The scroll position isn't compared with arrival, because a driver's click scrolls its
      target into view (corrected 2026-09-15, `status.md`).
   2. **No stray open element.** The elements matching `dialog[open]`, `:modal` or
      `:popover-open` are exactly the set the sequence declares open, usually none. Each one is
      claimed by a connected kit controller whose open state agrees.
   3. **Nothing stuck mid-transition.** No element is `data-state="closing"`, and no element
      is `data-state="open"` while `hidden` or not rendered (`ui-presence-and-overlay-stack`
      § Behavior, items 3 and 5).
   4. **Every `aria-expanded` is true exactly when its element is open.** This is the
      displaced-popover check made general: a popover the browser displaced must not leave its
      trigger claiming it's open.
   5. **Focus is somewhere real.** `document.activeElement` is connected. Unless it's
      `<body>`, it is rendered (a non-zero box and `checkVisibility()`), not inside `[inert]`, a
      closed `<dialog>` or a hidden popover, and inside the topmost open modal when there is one.
      It's `<body>` only when the sequence's last step was a document render that the sequence
      declares, or when focus returns to where it was recorded after one (`ui-toast` F8 from a
      freshly loaded page). Where the sequence declares a return target (the trigger, for a dismissal), focus
      is on that element or on the element that now holds its id.
   6. **The whole page passes `assert_accessible`**, unscoped.
   7. **A silent console.** No `console.error`, no `console.warn` (which includes every kit
      warning), no uncaught error and no unhandled rejection since the page was first loaded.
      Capture is installed before any page script runs. A check that finds capture wasn't
      installed fails, rather than reporting silence.
   8. **Every kit controller is connected.** Every element whose `data-controller` names a
      `ui--*` identifier has a live controller instance for that identifier. An element swapped
      in by Turbo whose controller never connected fails here.
   9. **No duplicate or dangling ids.** No two elements share an `id`. Every id named by `for`,
      `aria-controls`, `aria-labelledby`, `aria-describedby` or `aria-activedescendant`
      resolves to a connected element.

10. **Shared, not stress-specific.** Invariants 1 to 9 depend on nothing about the stress page.
    They ship as one helper on `ApplicationSystemTestCase`, `assert_kit_invariants`, which
    takes the declared open set and the declared focus expectation, plus a `capture_console`
    call made before the visit. Any component suite can adopt it. Adopting it in existing
    suites is not this scope (§ Out of scope / deferred). The helper also ships
    `record_arrival`, the snapshot invariant 1 compares against, because no caller can use
    invariant 1 without it. Four things stay in the stress files: when the arrival snapshot is
    taken, profile application and its proof, the sequence table and the outside-region
    coverage proof (item 12).
    Invariant 8 needs the Stimulus application reachable from the page, so the examples app
    exposes it as `window.Stimulus`, the Stimulus handbook's convention. A page without it fails
    invariant 8 loudly rather than skipping it.

### The sequences

11. **Generated from one table.** The table lists each overlay and how it opens, and each of
    its dismissals: Escape, an outside click, and its own close, with the focus target each
    one's owning spec promises. Overlay item 12 of `ui-presence-and-overlay-stack` names the
    trigger for most of them. It also lists the nesting pairs. A dismissal a component doesn't
    promise isn't generated: a Tooltip has no outside click.

    | Overlay | Opens by | Own close |
    |---|---|---|
    | Modal (M) | the frame link | its close button |
    | Confirm Dialog (C) | the `data-turbo-confirm` Button in M | Cancel (it has no outside click — see § Assumptions) |
    | Select `search: true` (S2), in M | click on the combobox | committing an option |
    | Select `search: false` (S1), in the dialog Dropdown | click on the combobox | committing an option |
    | Dropdown menu (Dm) | its trigger | activating the closing item |
    | Dropdown dialog (Dd) | its trigger | its trigger again |
    | Popover (Po) | its trigger | its trigger again |
    | Tooltip (T) | hover on the `aria-disabled` Button | the pointer leaving |

12. **An outside click lands where it claims to.** Every outside click targets the declared
    neutral region of the container the sequence means: inside the Modal but outside its child,
    or on the page. Before clicking, the test proves `elementFromPoint` at the region's centre is
    the region itself. Without that proof, at 320 px an anchored layer could cover the region and
    an "outside" click would land inside.

13. **The compositions:**
    - **Nesting pairs.** M > S2, M > Dm, M > Dd, M > Po, M > T, M > C, Dd > S1: open A, open B
      inside A, dismiss B, invariants with A declared open, dismiss A, invariants.
      - In **P0**, the full cross: every dismissal of B × every dismissal of A.
      - In **P1–P5**, the diagonal: for each of A's dismissals, B is dismissed the same way,
        or by Escape where B lacks it.

      The cross checks that no dismissal leaves state another dismissal trips on. Doing that
      once is enough. The conditions are what vary in P1–P5.
    - **The deepest chain.** M > Dd > S1, dismissed uniformly by each of the three ways,
      innermost first.
    - **Outside both.** With M > Dm open, one click outside both. It follows the browser: both
      close, innermost first, and Escape still closes one layer at a time (`open-questions.md`,
      decided 2026-09-15, option (a)).
    - **Displacement.** Po then Dm, Dm then Po, and Dm then T. The first two are the browser
      closing the earlier auto popover. The third is a hint that must *not* close the layer
      (`ui-presence-and-overlay-stack` § Behavior, item 8). Each is followed by dismissing
      whatever remains: every way in P0, and one rotating way in P1–P5.
    - **A toast across a Modal.** Open M, then fire the action toast from inside it.
      - F8 while M is open leaves focus inside M, by invariant 5, since the toast is occluded
        (`ui-toast` § Behavior, item 12).
      - Close M by each of its three ways. Then F8 reaches the toast's action, and Escape closes
        the toast with focus back where F8 recorded it.

      That proves the occluded toast stays reachable once the Modal is gone.
    - **Turbo Stream replacement while open.** S1 open in the page cluster, with its Field
      replaced. Dm open, with the page cluster replaced. Po open, with the page cluster
      replaced. M open, with the frame updated to a new Modal (`ui-modal-turbo` § Behavior,
      item 10). M > S2 open, with S2's Field replaced. Each replacement is a real server
      response rendered by Turbo's own stream renderer, started from a script. Anything on the
      page that could start it would itself be an outside click and dismiss the overlay first,
      and the sequence would no longer be the one it names.
    - **A morphing refresh while open.** M open: it's permanent, so it stays open as the same
      element, the lock is held and focus stays inside it. S1 open, and Dd > S1 open: each open
      layer survives the refresh as the same element, still open, with focus inside it
      (`open-questions.md`, decided 2026-09-15, option (a)). The guard that makes that true lives
      in `ui--overlay` and is pinned in that primitive's own suite.
    - **Back with something open.** M open, then its link out. Dd open, then its link out. S2
      open with a typed filter, then a Drive visit. Then Back. The page is restored with
      everything closed at rest, focus not pulled in, and S2's selected value kept with its
      filter cleared (`ui-select` § Behavior, item 32;
      `ui-presence-and-overlay-stack` § Behavior, item 19).
    - **The form.** An invalid submit, the `422`, then S1 in the form opened and dismissed by
      Escape. A valid submit, then its toast reached by F8 and closed by Escape. Both follow the
      profile's Turbo value.
    - **Soak, P0 only.** Every nesting pair's diagonal, one after another in one page visit,
      with the invariants after each. Every other sequence starts from a fresh visit so a
      failure is attributable. The soak exists for the defects that need many operations to
      show: a lock count that drifts, or listeners that pile up.

14. **The count, estimated rather than measured** (§ Assumptions). The table is fixed and its
    count is asserted, so a changed table shows in the diff:

    | | P0 | Each of P1–P5 |
    |---|---|---|
    | Nesting pairs | 57 (5 × 9, and 2 × 3 each for M > T and M > C, neither of which has an outside click) | 21 |
    | Deepest chain, outside both | 3 + 1 | 3 + 1 |
    | Displacement | 9 | 3 |
    | Toast across a Modal | 3 | 3 |
    | Stream, morph, Back | 5 + 3 + 3 | 5 + 3 + 3 |
    | Form | 2 | 2 |
    | Soak | 1 | 0 |
    | **Tests** | **87** | **44** |

    That's 307 sequence tests. Add the inventory file and the helper's self-test. Each sequence
    test is a visit (about 0.6 s on a heavy page with cached assets), two to four settled
    transitions (about 0.8 s, and less under reduced motion) and one invariant pass (about
    0.8 s, most of it axe). At about 2.2 s a test, P0 runs about 3.5 minutes and each other
    profile about 1.6 minutes. **The estimate is 11 to 13 minutes added to the `test-system`
    job**, which ran the whole lane in about 11 minutes on 2026-09-14. **The budget is 15
    minutes added** (`open-questions.md`, settled 2026-09-15), and the build measures against it.

15. **Eight files, each passing on its own.** The one-file-at-a-time convention (every file
    run in its own process, as every scope's status records) holds, and no file depends on
    another having run:
    - `stress_p0_test.rb` to `stress_p5_test.rb`, one per profile;
    - `stress_inventory_test.rb`;
    - `kit_invariants_test.rb`.

    The single CI job runs them all in one process, so condition teardown (item 5) is what keeps
    one profile's emulation out of the next file. Both run shapes are part of the acceptance
    checks.

16. **The inventory proves the table matches the page.** It visits the page, opens M, and
    derives from the DOM which openable triggers sit inside which openable containers. The set
    of nesting pairs must equal the table's. An overlay added to the page without a row fails
    here, which is what keeps "every nesting pair the page allows" true after the page changes.
    It also proves every condition can be applied and detected, one at a time.

## Business rules

**Must**

1. **Every sequence ends with `assert_kit_invariants`.** No sequence ends on its own last
   assertion. The declared open set and focus expectation are the only per-sequence inputs.
2. **An expected outcome comes from a spec, never from observation.** A sequence's declared open
   set and focus target cite the owning scope's § Behavior. Where no spec promises an outcome,
   the sequence isn't written: the question goes to `open-questions.md` with a recommended
   default, and nobody edits the expectation to match what the kit happened to do.
3. **The layout is a host's layout.** It holds what `rails_ui_kit:install` tells a host to
   render and what the Dark Mode page tells a host to add, and nothing the docs layout supplies
   beyond that (§ Behavior, item 2).
4. **Every condition proves it applied, and teardown proves it's gone.** A profile whose
   conditions aren't detectably in force fails before its first sequence (§ Behavior, item 5).
5. **No hollow assertion. This is the failure mode the suite exists to prevent**, so it's a
   rule, not advice:
   - **A geometry or visibility claim first proves its reference is laid out.** The reference is
     connected, has a non-zero box inside the viewport, and isn't `hidden`. A top-layer
     reference also matches `:modal` or `:popover-open`. A containment or "nothing covers it"
     claim against a zero-size or unrendered reference is vacuously true.
   - **Every wait is on the change, never a read after an async boundary.** After a fetch, a
     stream, a frame load, a morph, a visit or a transition, the test waits for something only
     the change produces: a fresh render token, an event count, a `data-state` value, or the
     disappearance of a node it tagged beforehand. It never reads an element that also existed,
     holding the previous value, before the change. This is the shape of the
     `select_form_submission_test.rb` race `ui-test-harness` recorded.
   - **An absence is asserted only after a positive settle signal.** "Nothing is open" read
     before the close began passes on a page where the close never happens.
   - **No fixed sleeps.** Waiting is Capybara's synchronisation or a polled condition with a
     timeout.
   - **Every invariant has been seen to fail.** `kit_invariants_test.rb` plants each fault on a
     bare page and asserts the helper reports it by name: a leftover `overflow: hidden`, a stray
     open popover, an element stuck `closing`, a lying `aria-expanded`, focus on a removed node,
     an axe violation, a `console.error` before load, an element naming an unregistered `ui--*`
     controller, a duplicate id and a dangling `aria-controls`.
6. **Deterministic.** Fixed table, fixed profiles, no random input, no retries. Minitest's
   order randomisation within a file is allowed because every sequence test starts from a fresh
   visit.
7. **No `skip`, and no red commit.** A sequence that fails is a defect to fix or an open
   question to raise, and it isn't committed failing or skipped. Commits stay green.
8. **The page stays a fixture.** It carries no prose, code samples or sidebar entry, and nothing
   in `docs/` links to it.
9. **A defect the suite finds is fixed where it lives, and pinned there.** Per `CLAUDE.md`,
   it's fixed on this branch in the owning component or primitive. It gets a focused regression
   test in that component's own suite, so the stress suite is never the only guard on it, and
   it's recorded in `status.md`. A fix that changes what a component promises is a question for
   the decider, not a fix.
10. **Adding the stress page adds no warning to `specline_check`** and no failure to any
    existing test file.

**Should**

11. **Adopt the harness.** The driver, `assert_accessible`, the CDP session `SLOW=1` already
    uses, and the existing probe patterns (`modal_turbo_probes.rb`'s tagging and counters) are
    reused. Console capture currently exists twice (`toast_helpers.rb`, `dropdown_test.rb`), and
    the shared helper becomes the one those can move to later.
12. **Measure before cutting.** If the measured time exceeds the estimate in § Behavior,
    item 14, the numbers go to the decider. P0's cross is not quietly reduced to the diagonal.

**May**

13. A component suite may adopt `assert_kit_invariants` after its own sequences. That's
    encouraged, but not required by this scope.

## Assumptions

- **The runtime estimate is arithmetic, not a measurement.** No stress test exists yet. The
  per-step figures come from the lane's 2026-09-14 run (51 files, about 11 minutes) and the
  weight of the page. **At a contradiction**, where the stress files measure over 15 minutes
  added together, record the numbers in `status.md` and shard the CI system job by directory
  (`ui-test-harness`'s deferred item, pulled by this). P0's cross is not taken to the diagonal
  to fit. That was decided in advance on 2026-09-15 (`open-questions.md`), so it isn't a
  question for the decider when it happens.
- **Headless Chrome honours 320 px and emulated reduced motion through CDP.** The harness
  already emulates `forced-colors` the same way (`emulate_forced_colors`). A 320 px viewport
  through `Emulation.setDeviceMetricsOverride` is unverified here. **At a contradiction**, where
  `innerWidth` isn't 320, try a window resize before anything else. If Chrome clamps both, raise
  it with the decider rather than calling a wider viewport 320.
- **`dir` set on `<html>` by script survives Turbo Drive visits and morphs.** Turbo 8 replaces
  `<body>` and merges `<head>`, and is read as leaving `<html>`'s `dir` alone. Unverified. **At a
  contradiction**, re-apply after each render and keep the precondition proof, because the
  proof is what catches it either way.
- **`Page.addScriptToEvaluateOnNewDocument` installs console capture before any page script,
  and it survives Turbo Drive visits** (Drive keeps the window). **At a contradiction**, use the
  driver's BiDi or browser-log channel. Don't fall back to installing capture after the visit,
  which would miss every error thrown during load.
- **Each overlay's dismissal set is read from its component suite, not assumed.** Whether
  Confirm Dialog dismisses on a backdrop click was the known unknown: `ui-confirm-dialog` pins
  "the backdrop behaving as today" without saying what that is. **Measured, 2026-09-15: it
  doesn't.** Its own full-viewport wrapper takes every click, so the dialog element -- what a
  backdrop dismissal listens for -- never receives one. The M > C pair is 3 × 2 and the counts in
  § Behavior, item 14 are 87, not 90. That was a table edit, as this said, not a question.
- **"Focus restored as if it had closed" (`ui-presence-and-overlay-stack` § Behavior, item 18)
  lands on the replacement when a stream replaced the trigger.** `ui-modal-turbo` § Business
  rules, rule 8 states this for the Modal. Item 18 forbids focus stranded on `<body>`, and a
  removed trigger leaves no other target. The stress sequences read it that way for Select,
  Dropdown and Popover. **At a contradiction**, where an owning scope reads item 18 differently,
  it's an open question for the decider, not a changed expectation.
- **The three builds in flight land as their ratified specs describe.** `ui-toast` (the
  occluded action toast, F8 and Escape), `ui-confirm-dialog` (the dialog carrying its own
  `ui--dialog`, `data-turbo-confirm` from inside a Modal), `ui-foundation-retrofit` (every
  overlay on `ui--overlay` and `ui--presence`) and `ui-field-model-binding` (Field over a model,
  the enum-backed Select). The page is written against those surfaces, not the code in the
  worktree today. **At a contradiction**, where a shipped surface differs, the page follows the
  shipped surface and cites it. If that removes a collision the page was meant to cover, say
  so in `status.md`.
- **`turbo_refreshes_with method: :morph` on a page with a `data-turbo-permanent` frame keeps
  an open Modal through a refresh.** That's the mechanism the docs layout's modal container
  relies on, applied to a frame. **At a contradiction**, the morph sequence records what
  happened and the question goes to `open-questions.md`.

## Critical files

- `examples/config/routes.rb`: the `stress` routes, outside `DocsPages::PAGES`.
- `examples/app/controllers/stress_controller.rb` (new): the page, the Modal content, the
  form's `422` and success, the stream endpoints for replacement and toast.
- `examples/app/models/stress_record.rb` (new): the ActiveModel form object.
- `examples/app/views/layouts/stress.html.erb` (new): the host-shaped layout.
- `examples/app/views/stress/` (new): the page, the overlay-cluster partial, the Modal.
- `examples/app/javascript/application.js`: gains `window.Stimulus`.
- `lib/generators/rails_ui_kit/install/install_generator.rb`: the instructions the layout must
  match. Read, not changed.
- `test/application_system_test_case.rb`: gains `assert_kit_invariants` and
  `capture_console`, by including a module from its own file.
- `test/kit_invariants.rb` (new): the nine invariants.
- `test/system/stress_sequences.rb` (new): the overlay table, the pairs, the profiles and the
  generator.
- `test/system/modal_turbo_probes.rb`, `test/system/toast_helpers.rb`: the probe and
  console-capture patterns to reuse.
- `docs/specs/ui-stress-page/implementation.md`: mechanics.

## Acceptance checks

### agent-loopable

- Every invariant reports a planted fault by name, and passes on a clean page — run: `bundle exec rake test:system TEST=test/system/kit_invariants_test.rb`
- The nesting pairs derived from the page's DOM equal the sequence table's, and each of the six conditions applies and is detected on its own — run: `bundle exec rake test:system TEST=test/system/stress_inventory_test.rb`
- The baseline profile passes every generated sequence, including the full dismissal cross and the soak — run: `bundle exec rake test:system TEST=test/system/stress_p0_test.rb`
- Profile P1 passes, dark, reduced motion, RTL smoke and Turbo off — run: `bundle exec rake test:system TEST=test/system/stress_p1_test.rb`
- Profile P2 passes, dark, 320 px, pseudo-locale and Turbo off — run: `bundle exec rake test:system TEST=test/system/stress_p2_test.rb`
- Profile P3 passes, dark, RTL smoke and pseudo-locale — run: `bundle exec rake test:system TEST=test/system/stress_p3_test.rb`
- Profile P4 passes, reduced motion, 320 px and RTL smoke — run: `bundle exec rake test:system TEST=test/system/stress_p4_test.rb`
- Profile P5 passes, reduced motion, 320 px, pseudo-locale and Turbo off — run: `bundle exec rake test:system TEST=test/system/stress_p5_test.rb`
- The eight files pass together in one process, the shape CI runs, so no profile's emulation leaks into the next — run: `bundle exec rake test:system TEST="test/system/kit_invariants_test.rb,test/system/stress_*_test.rb"`
- The baseline passes with emulated latency — run: `SLOW=1 bundle exec rake test:system TEST=test/system/stress_p0_test.rb`
- The page is not in the docs registry, the sidebar or the index — run: `! grep -rn "stress" examples/config/initializers/docs_pages.rb examples/app/views/layouts/docs.html.erb examples/app/views/docs/index.html.erb`
- The rest of the browser lane stays green with the stress files and the `window.Stimulus` change in place — run: `bundle exec rake test:system`
- The spec set stays clean — run: `specline check`

### judgeable

- The stress layout holds what the install generator's post-install instructions and the Dark Mode page tell a host to add, and nothing else from the docs layout, per § Business rules, rule 3 and § Behavior, item 2.
- Every declared open set and focus target in `stress_sequences.rb` cites a § Behavior item of the owning scope, and none was set from observed behaviour, per § Business rules, rule 2.
- Every wait and every geometry or visibility read in the stress files follows § Business rules, rule 5. A reviewer who finds a read of a pre-existing element after an async boundary, a fixed sleep, or a containment claim with no proof that its reference is laid out fails this, whatever the tests say.
- Every defect the build found has a regression test in its owning component's suite and an entry in `status.md`, per § Business rules, rule 9.

### human-gate

- Jonathan sees the measured time the stress files add to the `test-system` job, recorded in `status.md` against the estimate in § Behavior, item 14 and the 15-minute budget, and, if it went over, the directory sharding § Assumptions commits to.
- Jonathan opens `/stress` in each profile once and agrees it reads as the kit colliding with itself, not as a docs page.

## Out of scope / deferred

- **Adopting `assert_kit_invariants` in existing component suites.** It's available on the base
  class, and each suite adopts it when its owner touches it. Folding the two existing
  console-capture helpers onto it goes with that work.
- **The RTL assertions: mirrored placement, reversed arrows, the gutter side.** They belong to
  the support claim `ui-localization-rtl` deferred.
- **Sharding or parallelising the system job, while within budget.** It's `ui-test-harness`'s
  deferred item. A measured lane over the 15-minute budget pulls it, by directory
  (§ Assumptions).
- **Randomised or property-based sequence generation.** Reconsider it only if the fixed table
  stops finding defects the component suites miss.
- **Firefox and Safari.** The platform-variance questions this suite raises, such as a popover
  light dismiss inside a modal dialog, are Chrome-only here. That matches the harness.
- **Stressing a component that isn't built yet.** A future component joins the page and the
  table in its own scope, and the inventory check fails until it does.
