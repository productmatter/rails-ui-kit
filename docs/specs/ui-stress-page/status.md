## State

building

Authored 2026-09-15 on the orchestrator's directive, relaying Jonathan's question "Do we need
some sort of UI stress test?". Ratified for build on 2026-09-15 with the two open questions
ruled, the CI budget set at 15 minutes and RTL-as-smoke and the hidden page confirmed
(`open-questions.md`). Phase 1 is built and green: the invariant helper with its self-test, the
`window.Stimulus` handle, and the page's host layout with its form half. Phase 2 is next: the
overlay cluster, the Modal, the sequence table and inventory, the six profiles, the morph guard
and the timing.

## Handoff, 2026-09-15

Phase 1 is reported and green. Phase 2 is mid-build: see § In progress for the exact next step,
and § Defects found for every kit defect this page has found, each with where it was fixed and
whether its pin is written. The harness also gained a viewport fix: `driven_by`'s `screen_size`
was never applied (the window came up 756x413), so `ApplicationSystemTestCase` now sizes the
viewport before every test, leaves a driver with no window alone (`rack_test`), and 37 test files
lost the per-file resize they carried for that reason. `ui--turbo-disable-with` now returns focus
to a submitter Turbo disabled, per the ruling in `open-questions.md`.

## Done

- Read `CLAUDE.md`, the parent spec, `ui-test-harness` (spec and status), and the ratified
  specs of the builds in flight: `ui-toast`, `ui-confirm-dialog`, `ui-foundation-retrofit` and
  `ui-field-model-binding`. Read `ui-presence-and-overlay-stack` in full. Read the Behavior of
  `ui-select`, `ui-modal-turbo`, `ui-choices`, `ui-localization` and `ui-localization-rtl` where
  they bear on a collision.
- Read what the suite would build on: `test/application_system_test_case.rb` (CDP use, axe,
  forced-colours emulation), `modal_turbo_probes.rb`, the two console-capture helpers, the
  `Rakefile`'s lanes, `.github/workflows/ci.yml`'s single system job, `DocsPages::PAGES`, the
  docs layout, the install generator's post-install instructions, and `examples/`' Stimulus
  start-up (no `window.Stimulus` today).
- Verified the six-profile condition table covers every pair of values across all six
  dimensions, by exhaustive enumeration.
- Verified that no docs registry, docs layout or index file mentions "stress" today, so the
  hidden-page grep isn't vacuous.
- Authored `spec.md`, `implementation.md`, `relations.md`, `open-questions.md` and this file, and
  added the § Scopes row to the parent.
- **Recorded the 2026-09-15 rulings** in `open-questions.md` and `spec.md`: outside-both follows
  the browser; an open layer survives a morph, guarded in `ui--overlay`; up to 15 minutes added
  is accepted, with directory sharding if over; RTL smoke and the hidden page confirmed.
- **Phase 1, the invariant helper.** `assert_kit_invariants`, `kit_invariant_failures`,
  `capture_console` and `record_arrival` on `ApplicationSystemTestCase`, from
  `test/kit_invariants.rb` and one module per invariant family under `test/kit_invariants/`.
  `test/system/kit_invariants_test.rb` plants every fault the spec lists on `/stress/bare` and
  asserts each is reported under its own invariant's name, naming the element, and under no
  other. It also plants a lock released away from where it locked, a capture that was never
  installed, and a hidden dangling reference axe doesn't audit. A clean page passes, and so does
  an open Confirm Dialog declared open while it holds the lock and focus.
- **Phase 1, the page.** `window.Stimulus` in `examples/app/javascript/application.js`;
  `GET /stress`, `POST /stress` and `GET /stress/bare` outside `DocsPages::PAGES`;
  `StressController`, `StressRecord`, `layouts/stress.html.erb` (the install generator's three
  lines with `flash:`, the Dark Mode page's head snippet and body controller, lang, title, one
  `main`, one `h1`, `turbo_refreshes_with method: :morph`), and `stress/show.html.erb` with the
  form, the size row and the theme toggle. A valid submit answers a Turbo Stream toast, or a
  flash across a redirect with `?turbo=off`; an invalid one answers `422`.
- **Phase 1, the form sequences.** `test/system/stress_sequences.rb` holds the profile table and
  `define_form_sequences`; `stress_p0_test.rb` runs P0's two. Turbo off and the pseudo-locale
  were run once through the same sequences from a scratch file, green, and are generated for
  P1 to P5 in Phase 2.
- **Fixed the installation page's layout sample**, which still rendered
  `ToastContainerComponent.new` without the `flash:` the generator and README now print.

## Defects found (§ Business rules, rule 9)

Each one was fixed in the component that owns it and pinned in that component's own suite, so the
stress suite is never the only guard on it.

1. **A morph left every Select un-enhanced.** A `422` on a page that refreshes with morph is
   rendered as a morph. It rewrote each Select to the server's markup, where the combobox is
   `hidden` and the root has no `data-enhanced`, and `ui--select`'s morph handler re-rendered the
   label without enhancing again, so every Select vanished behind its native select.
   `ui-select` § Behavior, item 35 promises a working Select after a morph. Fixed in
   `select_controller.js`; pinned by ST5 in `select_turbo_stream_test.rb`, which morphs towards
   the page's own server render. ST3 couldn't catch it, because it clones the live element.
2. **A morph stripped what `ui--overlay` writes into its markup**, so the next open threw
   `NotSupportedError` from `showPopover()`, and a trigger kept an `aria-controls` naming an id
   the morph had taken away (the dangling `aria-controls="ui-overlay-N"` invariant 9 reported
   after a 422). Fixed in `overlay_controller.js`: a `turbo:before-morph-attribute` guard for what
   it owns, and a re-sync after any morph that puts back a remembered generated id, `popover`,
   `aria-controls` and `aria-expanded`. `ui--dropdown` re-applies its own ARIA the same way.
   Pinned in `ui_overlay_morph_test.rb`, seen to fail with the guard disabled.
3. **A morph closed every open layer.** (`layer` and `hint` modes only: a Modal is morphed away
   unless its container is marked `data-turbo-permanent`, which is `ui-modal-turbo`'s promise and
   is pinned by `modal_turbo_morph_refresh_test.rb`.) The server's markup has no id on a Dropdown's panel or a
   Select's root, so the morph replaced those elements rather than updating them, disconnecting
   the controller. This is the ruled behaviour in `open-questions.md`: while an overlay is open,
   `ui--overlay` now keeps the morph off its own element and its content, and `ui--select`
   re-renders instead of closing. Both go back to morphing normally as soon as they close.
4. **A Tooltip on an `aria-disabled` control never opened on hover.** The Tooltip page documents
   `aria-disabled="true"` as the way to keep a disabled control's tooltip reachable, and the kit's
   own Button gives such a control `pointer-events: none`, so it never saw a pointer event.
   `ui--tooltip` now tracks hover on the trigger wrapper and keeps focus on the control. Pinned as
   TT9 in `tooltip_test.rb`; TT7, which dispatched synthetic events at the control, now dispatches
   them at the wrapper.
5. **Focus was left on the `<dialog>` after an outside click inside a Modal**, against
   `ui-presence-and-overlay-stack` § Behavior, item 12. `ui--overlay` now treats focus the browser
   parked (`<body>`, the documentElement, or a `<dialog>` containing the overlay) as lost.
6. **One gesture that closed one layer and opened another left focus on the wrong trigger.**
   Opening a Popover over an open Dropdown light-dismissed the Dropdown, whose focus return ran
   during `pointerdown` -- before the browser's own focus of the clicked trigger. The Popover then
   recorded the Dropdown's trigger as where focus came from, and Chrome restored focus there when
   the Popover closed. `ui--overlay` now takes its trigger as the return target (item 12 says so
   directly) and defers the restore to the next frame, so the gesture's own focus wins. Reduced
   motion is what makes it reproducible: with no exit animation the close finishes first.
7. **A centred Modal sat half off-screen in a right-to-left document.** A fixed element's `left`
   follows the inline start in RTL, so `left-1/2` with `translate(-50%)` put a 320 px-wide dialog
   at x = -160, with its controls unreachable. `Ui::ModalComponent` now centres with
   `inset-x-0 mx-auto` and the CSS transforms carry the vertical movement only. Pinned as M10 in
   `modal_test.rb`. This is the RTL smoke doing its job (§ Behavior, item 7): a layout that
   strands controls, not a mirroring nicety.
8. **The Confirm Dialog has no backdrop dismissal**, which `ui-confirm-dialog` left as "the
   backdrop behaving as today": its own full-viewport wrapper takes every click, so the dialog
   element never receives one. Recorded as a table edit, per § Assumptions: M > C is 3 x 2 and
   `EXPECTED_COUNTS[:cross]` is 87, not 90. No kit change.

## In progress

None. Phase 2 is built: the overlay cluster, the Modal behind a `data-turbo-permanent` frame, the
sequence table and its generator, the inventory's DOM-parity check, the six profiles, the morph
guard and the measured runtime.

## Last green checkpoint

2026-09-15, uncommitted, on top of `712f10b`. Every stress file on its own, then the shape CI
runs.

Two late fixes -- scoping the morph guard to `layer` and `hint`, and deferring the focus restore
for pointer dismissals only -- were surfaced by the measuring lane run through three files, and
re-proven afterwards file by file: the whole `modal_turbo_*` family (10 files, 41 runs, including
the three that failed), `ui_overlay_morph`, `kit_invariants`, and `stress_p0`, `stress_p3` and
`stress_p5` under the final code. All green.

| Run | Result |
|---|---|
| `kit_invariants_test.rb` | 15 runs, 307 assertions, 12s |
| `stress_inventory_test.rb` | 8 runs, 55 assertions, 8s |
| `stress_p0_test.rb` | 87 runs, 1473 assertions, 271s |
| `stress_p1` to `stress_p5` | 44 runs each, 88-121s each |
| All eight in one process | **330 runs, 5000 assertions, 0 failures, 11m50s** |
| `SLOW=1 stress_p0_test.rb` | 87 runs, 0 failures, 5m22s |

Also green, each on its own: `modal_test.rb` (with M10), `tooltip_test.rb` (with TT9),
`select_turbo_stream_test.rb` (with ST5), `ui_overlay_morph_test.rb`, every other `ui_overlay_*`
file, `dropdown_test.rb`, `popover_test.rb`, `select_keyboard_test.rb`, `select_in_modal_test.rb`,
`select_turbo_cache_test.rb`, `field_swap_test.rb`, `modal_turbo_morph_refresh_test.rb`,
`choices_no_javascript_test.rb` and `select_no_javascript_test.rb` (the two that the viewport fix
had to leave alone), and the 37 files whose per-file resize was removed. `bundle exec rake test`:
627 runs, 0 failures. rubocop clean on every Ruby file this scope added or touched outside
`examples/`. `specline check`: 0 errors.

## The runtime, measured (§ Behavior, item 14, and the human gate)

The estimate was 11 to 13 minutes added. **Measured: the eight stress files run in 11m50s in one
process** (330 tests, about 2.15s each -- the per-test estimate was right). P0 is 4m31s of that,
because it alone runs the full dismissal cross and the soak.

**The whole lane, measured in one process on 2026-09-15: 859 runs, 9063 assertions, 20m27s.**
The lane without these files was 6m27s (544 runs), so the stress page adds **14m00s** -- inside
the 15-minute budget ruled on 2026-09-15, so the `test-system` job is not sharded by directory.
There is no headroom to spare: a seventh profile, or a second page, would need that decision
re-opened rather than assumed.

That measuring run also found three failures, all from one over-broad fix of this build's own
(see § Dead ends): the focus restore was deferred for every dismissal rather than for pointer
dismissals only, which broke the focus hand-off when a Turbo Stream replaces one Modal with
another. Scoped and re-proven file by file.

## Dead ends

- **One condition flipped at a time (7 profiles).** Rejected: dark mode never meets 320 px, and
  reduced motion never meets RTL. A strength-2 covering array is six profiles and pairs
  everything.
- **The full dismissal cross in every profile.** About 90 tests × 6, roughly 20 minutes.
  Rejected for P1–P5: the cross tests state left behind between dismissals, which doesn't depend
  on theme, viewport or locale. It runs once, in P0.
- **Chaining every sequence in one visit.** Rejected as the default, because the first failure
  hides everything after it and the cause of a later one is unattributable. Kept as P0's single
  soak test, for the drift-over-many-operations defects a fresh visit can't show.
- **Running the stress page in the docs layout.** Rejected: that layout supplying a controller a
  host never gets is one of the defects that motivated this scope.
- **Invariant 1 comparing the scroll position with arrival.** The first P0 run failed on it
  after a plain click on Save: the driver scrolls a click's target into view. Replaced by a watch
  that checks each lock release restores the position the lock took.
- **Guarding every overlay mode against a morph.** The first cut of the ruled morph guard kept
  the morph off any open overlay, including a Modal, which morphed an unmarked Modal back into
  existence and failed `modal_turbo_morph_refresh_test.rb`. Scoped to `layer` and `hint`: a Modal
  the server's markup no longer contains is closed by the host's own intent, expressed with
  `data-turbo-permanent`; a menu the user has open is not. Confirmed by the orchestrator.
- **Deferring every focus restore to the next frame.** The displacement defect (a Popover opened
  over a Dropdown) needed the restore to wait for the browser's own focus, but deferring
  unconditionally broke the modal-replacement hand-off: a Turbo Stream replaces one Modal with
  another in the same task, and the second read focus before the first had restored it, so
  `modal_turbo_replace_test.rb` lost the element that opened the first Modal. Deferral is now for
  pointer dismissals only -- the only case that competes with the browser's own focus.
- **Waiting for a submitted form's tagged node to disappear.** A morphed `422` keeps the node, so
  the tag vanished only because the morph stripped the attribute. It now waits on the render
  token.

## Corrections

- § Behavior, item 9.1 compared scroll position with arrival, which a driver's scroll-into-view breaks; it now checks styles against arrival, a held lock while one is declared, and that every release restores where the lock was taken — provable — implementer
- § Behavior, item 10 kept the arrival snapshot in the stress files, but invariant 1 is unusable without it, so `record_arrival` ships with the helper and the stress files keep only when it is taken — provable — implementer
- § Behavior, item 9.5 allowed `<body>` only right after a document render, but F8 from a freshly loaded page records `<body>` and Escape returns there; that is allowed when declared. A Turbo submission leaving focus on `<body>` was ruled a kit fix instead (`open-questions.md`) — provable — implementer
- `implementation.md`'s one-module helper broke `Metrics/ModuleLength`, and console capture must be registered before any other new-document script; both recorded there — provable — implementer
