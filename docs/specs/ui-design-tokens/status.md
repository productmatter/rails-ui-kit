## State
building

Spec is ratified and the build has not started. The one precondition is the
system-test lane, which `ui-test-harness` owns and ships first (`relations.md`
carries the edge): the `.dark`-on-`<html>` regression check in § Acceptance checks
runs in that lane, so this build starts once it exists.

## Done
- Read the parent spec (`ui-component-library/spec.md`) in full, plus
  `app/assets/tailwind/rails_ui_kit/engine.css`,
  `lib/generators/rails_ui_kit/install/install_generator.rb`,
  `app/javascript/rails_ui_kit/controllers/dark_mode_controller.js`, and `README.md`,
  to ground the token contract in the actual repo surface.
- Authored `spec.md`: token names/values, the `:root`/`.dark` mechanism, the
  Tailwind v4 `@theme` exposure, the install-generator delivery path, and the
  compatibility assertion with the existing dark-mode controller.

## In progress
None — spec drafted; next step is implementation against it, not further authoring.

## Last green checkpoint
none — spec authored, no implementation or test run has happened yet.

## Dead ends
None yet.

## Corrections
None yet — no corrections recorded.
