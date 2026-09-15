## State

draft

Authored 2026-09-15 on the orchestrator's directive, relaying Jonathan's question "Do we need
some sort of UI stress test?". Waiting on ratification and the two rulings in
`open-questions.md`. Nothing is built.

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
- Verified that `Rake::FileList` expands the brace glob the one-process acceptance check uses,
  and that no docs registry, docs layout or index file mentions "stress" today, so the
  hidden-page grep isn't vacuous.
- Authored `spec.md`, `implementation.md`, `relations.md`, `open-questions.md` and this file, and
  added the § Scopes row to the parent.

## In progress

None.

## Last green checkpoint

None. Nothing built. `specline_check` was clean of new findings when this was authored.

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

## Corrections

None yet.
