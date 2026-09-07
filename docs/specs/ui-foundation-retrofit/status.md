## State
building

Spec is ratified and the build has not started. This is the last scope in Phase A's
build order (harness → tokens → base → primitives → retrofit); it starts once
`ui-component-base`, `ui-presence-and-overlay-stack` and
`ui-positioning-and-navigation` have shipped (`relations.md` carries the direct edge
to the last of these).

## Done
- Read `ui-component-library/spec.md` (the parent) in full.
- Read all 7 components under `app/components/ui/` (`.rb` + `.html.erb`) and all 11
  Stimulus controllers under `app/javascript/rails_ui_kit/controllers/`, plus
  `index.js`.
- Read `app/assets/stylesheets/rails_ui_kit/components.css`, `README.md`,
  `PLAN.md`, `CHANGELOG.md`, `specline.yml`, and the parent's `relations.md` /
  `open-questions.md`.
- Read all 9 files under `test/` (component tests in full for Modal, ConfirmDialog,
  Toast; grepped Dropdown/Popover/Tooltip/ToastContainer for hardcoded-class
  assertions) — confirmed `toast_container_component_test.rb` asserts the literal
  `bg-red-100` and `confirm_dialog_component_test.rb` asserts the constructor keys
  this scope deletes.
- Read `docs/archive/README.md` and `docs/conventions/doc-architecture.md` to ground
  the `PLAN.md` disposition call in this repo's actual Specline conventions rather
  than guessing.
- Read the sibling `ui-design-tokens/spec.md` (already ratified) for section-weight
  and citation-style precedent, and to confirm its token set is closed ("no more, no
  fewer"), which is what makes the Toast semantic-color gap a real cross-scope
  question rather than a detail this scope can resolve unilaterally.
- Ran `specline check . --format json`: 0 errors, 1 pre-existing warning on the
  parent spec (`UNKNOWN-SECTION` for `## Scopes`), unrelated to this folder.
- Authored `spec.md`, `relations.md`, `implementation.md`, and this `status.md`.

## In progress
None — spec drafted; next step is implementation against it, not further authoring.

## Last green checkpoint
none — spec authored, no implementation or test run has happened yet.

## Dead ends
None yet.

## Corrections
None yet — no corrections recorded.
