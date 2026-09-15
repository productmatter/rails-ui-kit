# Implementation notes — ui-stress-page

Advisory. The how that `spec.md` keeps out of its contract. The builder may do better, and
where it does, `status.md` records why.

## Build order

1. **`assert_kit_invariants` and `kit_invariants_test.rb` first.** They need no stress page: the
   self-test plants faults on a `data:` page, the way `accessibility_assertion_test.rb` does, or
   on a bare route. Once green, the three builds in flight can adopt the helper while they're
   still open.
2. **The page, its layout and `stress_inventory_test.rb`.** The inventory test is the page's own
   check that it contains what the table says.
3. **`stress_sequences.rb` and `stress_p0_test.rb`.** Expect the first full P0 run to find real
   defects. Fix each where it lives, per § Business rules, rule 9, before starting P1.
4. **P1 to P5**, then the one-process run, then `SLOW=1` on P0, then the timing record.

## The invariant helper

One `page.evaluate_script` returns a report object, so the whole check is a single round trip
plus axe. Ruby turns each non-empty section into a failure message that names the element with
its first 120 characters of `outerHTML`.

- **Scroll lock.** On arrival, snapshot `document.documentElement.style.cssText` and
  `document.body.style.cssText` into `window.__kitArrival`, and install (once per document) a
  `MutationObserver` on `style` that notes where `<body>` went `position: fixed` and records any
  release that doesn't leave the page scrolled there. Compare styles against the snapshot, and
  report the recorded releases. Turbo Drive keeps `window`, so after a visit or Back the
  sequence takes a new snapshot, and the declared document render is what allows it. As built:
  the first cut compared `scrollX`/`scrollY` with arrival, which the driver's own
  scroll-into-view on click broke (`status.md`).
- **Open set.** `document.querySelectorAll('dialog[open], :modal, :popover-open')`, compared by
  id with the declared set. "Claimed" means `Stimulus.getControllerForElementAndIdentifier` finds
  a `ui--overlay` on an ancestor whose `openValue` is true.
- **Stuck transitions.** `[data-state="closing"]`, and `[data-state="open"]` where `hidden` is set
  or `checkVisibility()` is false.
- **`aria-expanded`.** For each `[aria-expanded]`, resolve what it opens: `aria-controls` first,
  then the `ui--overlay` content target of its controller. `true` requires that element to be
  open (`:popover-open`, `:modal`, or `dialog[open]`), and `false` requires it not to be. A
  combobox's `aria-controls` names the listbox inside the popup
  (`ui-presence-and-overlay-stack` § Business rules, rule 6), so resolve up to the nearest
  popover or dialog.
- **Focus.** `document.activeElement`, `isConnected`, `checkVisibility({ checkOpacity: true,
  checkVisibilityCSS: true })`, a non-zero `getBoundingClientRect()`, `closest('[inert]')`,
  `closest('dialog:not([open])')`, `closest('[popover]:not(:popover-open)')`. Script can't read
  top-layer order, and document order is wrong here: the shared Confirm Dialog comes before the
  Modal's frame in the layout but opens above it. So the sequence declares the topmost modal,
  and the helper checks focus against that.
- **As built, the helper is five files.** `test/kit_invariants.rb` composes one module per
  invariant family under `test/kit_invariants/` (`top_layer.rb` for 1 to 4, `focus.rb`,
  `console.rb`, `connections.rb` for 8 and 9), each one script round trip, with axe between.
  One nine-invariant module broke `Metrics/ModuleLength`.
- **Console.** `capture_console` registers a script with `Page.addScriptToEvaluateOnNewDocument`
  that wraps `console.error` and `console.warn` and listens for `error` and
  `unhandledrejection`. Register it before any other new-document script: Chrome runs them in
  registration order. Entries are mirrored to `sessionStorage` under a per-capture key, so a
  Turbo-off full page load keeps what the previous document logged. It pushes into
  `window.__kitConsole` and sets
  `window.__kitConsoleInstalled = true`. Remove the registration in teardown by its returned
  identifier. The invariant fails if `__kitConsoleInstalled` is absent.
- **Controllers.** For each `[data-controller]`, split the tokens and keep `ui--*`. Each needs
  `Stimulus.getControllerForElementAndIdentifier(element, identifier)` to be non-null. Stimulus
  connects on a microtask after insertion, so run this after the settle signal, never straight
  after a swap.
- **Ids.** Count `[id]` values, then resolve every IDREF token in the five attributes.

## Conditions

- **Motion:** `Emulation.setEmulatedMedia`, with features `prefers-reduced-motion: reduce`. Reset
  with an empty features list.
- **Viewport:** `Emulation.setDeviceMetricsOverride` with `{ width: 320, height: 800,
  deviceScaleFactor: 1, mobile: false }`. Reset with `Emulation.clearDeviceMetricsOverride`.
- **Theme:** `localStorage.clear()` on the stress origin before the visit, then click the toggle.
  Proof: `document.documentElement.classList.contains('dark')`.
- **Direction:** `document.documentElement.dir = 'rtl'` after the visit. Proof: `dir` and
  `getComputedStyle(document.body).direction`.
- **Locale:** `?locale=<PseudoLocale::LOCALE>`. Proof: the Confirm Dialog's rendered
  `data-default-title` contains `PseudoLocale::OPEN`.
- **Turbo off:** `?turbo=off`. Proof: `form[data-turbo="false"]`.

Wrap the whole application in `setup` and the reset in `teardown` with `ensure` semantics, as
`assert_focus_outline_in_forced_colors` does.

## The generator

`StressSequences` is plain data plus one `define_for(profile, cross:)` class method called at
the top of each profile file:

```ruby
class StressP0Test < ApplicationSystemTestCase
  include StressSequences
  define_for StressSequences::PROFILES.fetch(:p0), cross: true
end
```

Each overlay row carries an `open` lambda, a `settled_open` probe, and a `dismissals` hash from
`:escape`, `:outside` and `:own` to a lambda plus the focus target it promises and the spec
reference it cites. A pair is `[outer, inner]`. Test names are
`"P3 M>Dd escape/outside"`, so a failure line reads as the sequence.

A constant `EXPECTED_COUNTS = { cross: 90, diagonal: 44 }` asserts the generated counts, so any
change to the table shows up in the diff as a change to the number too.

## Covering array

The six profiles are a strength-2 covering array over six binary factors. Each non-baseline
column is a distinct weight-3 vector over rows P1 to P5 that isn't the complement of another,
which guarantees every pair of columns shows all four value combinations. It was verified
exhaustively at authoring time. If a seventh dimension is ever added, six rows still suffice up
to ten binary factors.

## Settle signals to wait on

- Overlay: `ui--overlay:opened` and `ui--overlay:closed`, counted on `document` from before the
  action.
- Presence: `data-state` reaching `open` or `closed`, never a duration.
- Stream replacement: the replacement's `data-stress-render` token, which the stress controller
  increments per render, differing from the tagged old one.
- Frame: `turbo:frame-render` counted, as `modal_turbo_probes.rb` does.
- Morph: `turbo:morph` counted.
- Visit and Back: `turbo:load` counted, then the new arrival snapshot.
