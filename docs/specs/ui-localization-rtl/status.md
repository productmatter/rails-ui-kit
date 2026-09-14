## State

ready-for-review — decided 2026-09-14: convert now, promise later. The sixteen component
classes and the docs app's 110 are converted, the guard scans both, and every
agent-loopable check passes. No human gate applies; the RTL support claim and its gates
stay deferred.

## Done

- Counted the physical direction classes properly, by tokenising every class string in
  `app/components`, `app/javascript` and `app/assets` rather than grepping lines:
  **sixteen are direction-dependent**, in five files. The rest of what a naive count
  catches is symmetric (`left-0 right-0`), centred (`left-1/2` with a `-50%` translate),
  sideless (`origin-top`), already logical (flex `items-*` / `justify-*`) or genuinely
  physical (Modal's `:left` / `:right` positions). The directive's "roughly 30" and its
  `origin-top-right` on menus do not match the code: the kit has no `origin-top-right`
  anywhere, and Select's chevron offset is `right-2.5`, not `pr-8` — `pr-8` is the
  control's padding, which reserves the space for it.
- Verified Floating UI from the pinned bundle, not from memory: `config/importmap.rb`
  pins `@floating-ui/dom@1.6.1` via jsDelivr `+esm`, whose graph closes over
  `core@1.6.0` and `utils@0.2.1`. `core@1.6.0`'s `computeCoordsFromPlacement` flips the
  alignment axis when `rtl && sideAxis === "y"`, and `dom`'s `isRTL` reads the floating
  element's computed `direction`. So `-start` / `-end` mirror without kit code. Confirmed
  the kit never portals an overlay (no `appendChild` in the overlay stack), so `direction`
  inherits from the DOM position.
- Compiled a scratch stylesheet with this repo's `tailwindcss-ruby` 4.3.1 and confirmed
  every replacement class emits: `ps-*`, `pe-*`, `ms-*`, `me-*`, `inset-s-*`, `inset-e-*`,
  `text-start`, `border-s/e`, `rounded-s/e`, `float-start`, plus the `rtl:` and `rtl:sm:`
  variants (as `:where(:dir(rtl), [dir="rtl"], [dir="rtl"] *)`). Found no logical form for
  `transform-origin` or `translate-x` — those pair with `rtl:`. Confirmed from Tailwind's
  changelog that `start-*` / `end-*` are deprecated in favour of `inset-s-*` / `inset-e-*`.
- Ran `tailwind_merge` 1.5.5 against the conversions: it does **not** merge `ps-3` with a
  caller's `pl-4` (different properties to it), and Tailwind emits physical padding,
  margin and inset utilities after their logical counterparts, so caller-wins still holds
  on source order. `text-start` is the exception — emitted after `text-left` — and it
  appears only in ConfirmDialog, whose classes a caller replaces wholesale.
- Measured the RTL scrollbar question in headless Chrome 152 rather than assuming it:
  `innerWidth - clientWidth` is 0 in both directions on macOS (overlay scrollbars), so the
  scroll-lock gutter cannot be observed locally. Recorded as an assumption with its
  contradiction path instead of a claim.
- Authored `spec.md`, `relations.md`, `open-questions.md` and this file, and added the
  § Scopes rows to `ui-component-library`.
- Converted the sixteen classes in § Behavior, item 1, exactly as tabled: `ps-*`/`pe-*`,
  `ms-*`, `inset-e-*`, `text-start`, and `rtl:origin-right` / `rtl:sm:-translate-x-2` beside
  the two physical classes that have no logical form.
- Converted the docs app in the same pass (§ Behavior, item 7): 107 classes by sweep, and
  three more — an input group's `rounded-l-lg border-r-0` / `rounded-r-lg` in
  `modal_demo.turbo_stream.erb` — that the sweep missed and the guard caught.
- `test/components/ui/logical_direction_test.rb` scans components, controllers and docs
  views against an allow-list of decisions (Modal's positions and centring, the toast
  timer's symmetric pair and its two `rtl:`-paired classes). It failed on a planted `ml-2`.
  Its first version flagged Floating UI placements (`left-start`) and JavaScript object keys
  (`left:`); a physical side must now carry a Tailwind value to count as a class.
- `test/tailwind_logical_utilities_test.rb` compiles every introduced class with the
  bundled `tailwindcss-ruby` and asserts its logical declaration, that `inset-e-4` equals
  `right-4` and `ps-3` equals `pl-3`, and that `rtl:` targets `:dir(rtl)`.
- LTR unchanged: `select_enhancement_test` (11 runs), `control_sizing_test` (6 runs, 224
  assertions, padding at every size) and `anchor_position_test` (9 runs) pass unedited.

## In progress

Nothing.

## Last green checkpoint

uncommitted on `278dcf7` — rubocop 147 files clean; unit lane 473 runs, 0 failures; browser lane file by file 68/68 files, 410 runs, 3052 assertions, 0 failures, including the three LTR geometry suites unedited.

## Dead ends

- `start-*` / `end-*` as the inset spelling — rejected: deprecated upstream in Tailwind's
  own changelog, and canonicalisation migrates them to `inset-s-*` / `inset-e-*`.
- Pre-flipping `-start` / `-end` placements in `ui--anchor`, or correcting its coordinates
  for direction — rejected: Floating UI already does it, and parent rule 4 forbids a
  second implementation of anchored positioning.
- Deriving the scroll-lock gutter's side from the document's direction — rejected: which
  side the viewport scrollbar sits on is a browser and platform decision, so the lock
  measures it rather than inferring it.

## Corrections

- `tailwindcss-ruby` 4.3.1 emits the `rtl:` variant as nested CSS (`.rtl\:origin-right { &:where(:dir(rtl), …) }`), where a standalone CLI build flattened it; the compiled-CSS test reads the rule body rather than the selector — provable — implementer
- The spec excluded the docs app from the conversion; a long-running dev server serving new logical classes against a stale stylesheet showed a mixed tree is worse than either end, so the docs app converted in the same pass and the guard scans it — judgeable — decider
- The directive's physical-class count (roughly 30, including `origin-top-right` on menus and `pr-8` on Select's chevron) overstated the change; the inventory is sixteen classes in five files and the kit has no `origin-top-right` — provable — implementer
- The directive asked whether Floating UI or the kit resolves `-start`/`-end` in RTL; the pinned build resolves it, so the expensive-looking half of RTL is already done — provable — implementer
