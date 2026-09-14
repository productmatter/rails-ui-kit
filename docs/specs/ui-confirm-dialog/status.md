## State

ratified

Ratified 2026-09-14 by the orchestrator, who also decided the class-keyword question.
Nothing is built. **The first build step is the default-render regression check**, written
and green against today's unchanged component before the component is touched.

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

None.

## Last green checkpoint

none — spec only. `specline_check` on the repo: 0 errors, and the same three pre-existing
warnings as before this scope was added.

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
