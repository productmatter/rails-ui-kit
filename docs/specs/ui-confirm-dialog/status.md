## State

ratified

Ratified 2026-09-14 by the orchestrator, who also decided the class-keyword question. The
regression check and the component, its two controllers, the docs page, the README and the
UPGRADING entries are built and verified in both browser lanes.

## Done

- Read `CLAUDE.md`, the parent spec, `ui-foundation-retrofit` (spec, implementation, open
  questions), `ui-localization`, `ui-localization-rtl` § Behavior item 4, and
  `ui-component-base`.
- Read `confirm_dialog_component.rb` and `.html.erb` (with `spec-localization`'s in-progress
  `Ui::Chrome` diff), `dialog_controller.js`, `turbo_confirm_controller.js`,
  `button_component.rb`, `base.rb`, `modal_component.rb`'s backdrop, the README's Confirm
  dialog theming section, `test/system/confirm_dialog_test.rb` and
  `test/system/turbo_confirm_test.rb`.
- Verified Turbo's confirm hook in bundled turbo-rails 2.0.23:
  - `FormSubmission#start` reads `data-turbo-confirm` from submitter then form, and calls
    `config.forms.confirm(message, formElement, submitter)`.
  - `FormLinkClickObserver` copies only `data-turbo-confirm` onto the form it builds from a
    link.
- Authored `spec.md`, `relations.md`, `open-questions.md` and this file, and added the
  § Scopes row to the parent.
- Recorded the orchestrator's 2026-09-14 ruling: eight class keywords stay, merged, and
  `icon_class:` is removed. This reverses the retrofit's ratified deletion. The one
  behaviour difference is stated in the UPGRADING text.
- Marked this scope ratified, set `conflicts_with` to empty, and trimmed
  `ui-foundation-retrofit` of the Confirm Dialog work this scope took over.

## In progress

- Built, 2026-09-14:
  - `test/system/confirm_dialog_default_render_test.rb` (CR1-CR5), written and green against the
    unmodified component, proved able to fail by planting a changed footer padding, and still
    green unedited after the rework.
  - `Ui::ConfirmDialogComponent` on `Ui::Base`: tokens, no icon, `icon`/`body` slots,
    `confirm_variant:` (default `:destructive`), eight merged class keywords, `icon_class:`
    raising, `Ui::ButtonComponent` for both buttons and one `<template>` per confirm variant.
    Its backdrop classes are read from `Ui::ModalComponent`, so the kit has one modal backdrop
    and the component file carries no palette literal.
  - `dialog_controller.js`: every part resolved from options over the rendered `data-default-*`,
    validation against `data-strict`, and a variant swap that clones a server-rendered template.
  - `turbo_confirm_controller.js`: all four attributes, submitter then form then remembered link.
  - New browser checks: `confirm_dialog_variant_test.rb`, `confirm_dialog_icon_test.rb`,
    `confirm_dialog_validation_test.rb`, `turbo_confirm_test.rb` (TC2, TC3),
    `confirm_dialog_test.rb` (CD8, axe in both modes and both directions), and
    `test/system/confirm_dialog_helpers.rb`.
  - Docs page, README's two sections, and UPGRADING §4 and §5 with their grep lines.

- **Found and fixed, a defect the spec did not name:** below `sm` the panel had no width of its
  own, so a short confirmation shrink-wrapped to its text. Recorded in spec.md § Behavior item 1.
- **Found by a fresh-install review and fixed, 2026-09-15:** nothing put `ui--dialog` on the
  page except the docs layout's wrapper, so a fresh app had no `window.defaultConfirmDialog`.
  The `<dialog>` now carries it (spec.md § Behavior item 4), the wrapper is gone, and CD9 proves
  the component alone installs and answers. CD10 covers `customConfirmDialog("1-archive")` (an
  id that isn't a valid selector) and a confirm whose dialog is removed resolving `false`.

## Last green checkpoint

Unit lane: 486 runs, 1 failure, and that failure is another worker's undocumented
`rails_ui_kit.choices.required_message` chrome key. Rubocop: clean over every file this scope
touched. Browser lane, 2026-09-15: every confirm-dialog file, `turbo_confirm_test`, `modal_test`, the
four `modal_turbo_*` files that open a confirm, both localization files and
`ui_overlay_removal_test` green in the normal and SLOW lanes.

## Dead ends

- `tone:` (`:destructive`/`:default`) choosing both the icon and the confirm button, as
  first directed, was overruled by the decider, because a tone that picks an icon is the
  kit forcing iconography. It's replaced by an icon slot that is empty by default and a
  plain `confirm_variant:`.
- Rendering every confirm variant as hidden sibling buttons was rejected in favour of
  `<template>`s. Hidden siblings match `button[value='confirm']` more than once and
  complicate every existing check.

## Corrections

- The directive treated the class keywords' fate as undecided; `ui-foundation-retrofit` had ratified deleting all nine, so keeping eight is recorded as overriding that decision and escalated rather than decided here — provable — reviewer
