## State

ready-for-review: built on this branch. `Ui::OptionSet` moved out from under Select first, with
the Select suites green across the move; then `Ui::ChoicesComponent`, `ui--choices`, the two
Field prerequisites, the docs page and the guide text. Both lanes are green and rubocop is clean.
Two human gates remain (§ Acceptance checks): VoiceOver in Safari, and the card appearance at
phone and desktop widths.

## Done

- Shaped from the orchestrator's directive (2026-09-14) against the live repository:
  `option_set.rb`, `field_component.rb` and `field/`, `select_component.rb`,
  `input_component.rb`, `label_component.rb`, `chrome.rb`, `field_controller.js`,
  `form_change_controller.js`, the locale file, and the parent, Select, Field binding,
  presentational, control-sizing and localization specs.
- Verified Rails against the bundle, ActionView 8.1.3.1, and diffed
  `collection_helpers.rb` against 7.2.3.2 (identical):
  - `collection_check_boxes` and `collection_radio_buttons` both prepend a hidden
    empty field by default;
  - `html_options[:required]` lands on every input;
  - `html_options[:disabled]` leaves the hidden field enabled, while
    `select(multiple:, disabled:)` and `checkbox(disabled:)` disable theirs;
  - an in-memory `has_and_belongs_to_many` update with `role_ids: [""]` empties the
    association, and with the key absent keeps `[1, 2]`;
  - a blank enum assignment gives `nil`.
- Verified browser behaviour in headless Chrome through Selenium:
  - a disabled fieldset submits nothing;
  - `aria-labelledby` names a fieldset, and names an input wrapped in a label with a
    description;
  - `:focus-visible` is set by an arrow key, not by a click, and arrow keys wrap;
  - a click on the description checks the radio;
  - `setCustomValidity` blocks submission and focuses the checkbox;
  - one `required` radio makes the whole group invalid;
  - `required` on every checkbox demands all of them;
  - a fieldset's UA `min-inline-size: min-content` holds it at 382px inside a 100px
    box.
- Verified CSS with tailwindcss 4.3.1 against the kit's `engine.css`: the `has-checked:`,
  `has-focus-visible:`, `has-disabled:` and `group-aria-invalid/choices:` selectors, and
  that `has-checked:` is emitted after `group-aria-invalid/…:` at equal specificity,
  so checked would beat invalid.
- Read axe-core 4.13's standards: `aria-required` is allowed on `radiogroup` but not
  `group`; `aria-invalid` is global; `fieldset` allows `role="radiogroup"`.
- Authored `spec.md`, `relations.md`, `open-questions.md` and this file, and added the
  § Scopes row to ui-component-library.
- Recorded the decider's rulings of 2026-09-14, relayed by the orchestrator:
  - the required-checkbox controller ships, with its not-redundant rationale recorded
    in § Behavior, item 14 and § Business rules, rule 4, and min/max stay out;
  - checked, locked values are carried by hidden inputs as a third Rails deviation,
    with "a locked checkbox is not authorization" required in the docs and guide
    (§ Behavior, item 7);
  - the Choices row moved to Phase C beside Select, and the parent's "Nothing is queued
    behind Select" was corrected.
- Verified Rack 3.2.7 keeps the last value of a repeated non-array key, which the radio
  carrier's ordering relies on.
- Aligned § Behavior, item 19 with `ui-localization-rtl`'s "convert now, promise later"
  ruling: logical classes only, no RTL browser check or claim.
- **Built the `Ui::OptionSet` move as its own step** (§ Behavior, item 3):
  `app/components/ui/select/option_set.rb` → `app/components/ui/option_set.rb`, with the
  four references following it, a required `component:` keyword so an `ArgumentError` names
  the component the caller wrote, and `Item#object` carrying the collection element (nil for
  the array, hash and enum sources). No behaviour change: `select_component_test`,
  `select_options_test` and eight Select browser files stayed green across it, and a new
  `option_set_test.rb` holds the three new facts.
- **Built `Ui::ChoicesComponent`**, its template, `Ui::Choices::Appearance` (the two class
  lists, held apart so the component stays about names and wiring, as `Ui::Select::Primitives`
  is), `choices_controller.js`, the `rails_ui_kit.choices.required_message` key and its row on
  the Internationalization page, and the two Field prerequisites (`labelable?`,
  `checked:` from the record) under `ui-field-model-binding`.
- **Built the docs page** — both variants, both appearances, sizes, the required pair, the
  locked group with the "a locked checkbox is not authorization" warning, the
  `include_hidden: false` cost, and a real 422 round trip against `DemoMembership` — plus the
  README's "Radio and checkbox groups" section carrying the same warning.
- **Wrote the checks**, one file per acceptance line: `choices_component_test` (render parity,
  held against what `collection_radio_buttons`/`collection_check_boxes` render from a real view
  context), `choices_submission_test` (an in-memory `has_and_belongs_to_many` round trip from
  the rendered markup), `option_set_test`, `field_choices_test`, and the browser files
  `choices_submission`, `choices_keyboard`, `choices_validation`, `choices_accessibility`,
  `choices_variant`, `choices_layout`, `choices_turbo` and `choices_no_javascript`.
  Each new behaviour was proved to fail without its implementation: dropping the CSS swap,
  the accessibility flip, the carriers or the controller's derivation each turns its checks red.

## In progress

None.

## Last green checkpoint

`bundle exec rake test` — 516 runs, 0 failures. Browser lane, one file at a time:
`choices_submission` 5, `choices_keyboard` 7, `choices_validation` 7, `choices_accessibility` 7
(axe in light and dark), `choices_variant` 6, `choices_layout` 4, `choices_turbo` 4,
`choices_no_javascript` 6 — 0 failures, plus the eight Select files re-run across the
`Ui::OptionSet` move. `bundle exec rubocop` clean, with no inline disables and no config change.

## Dead ends

- A `div role="group"` root instead of a fieldset — loses native `disabled` over every descendant, including the hidden field, and stops being a group when CSS and ARIA are gone.
- Naming the group with Field's `<label for>` pointed at the first input — clicking the group's label would toggle that choice, and the input would take the group's name.
- A `<legend>` rendered by Choices — the visible label is Field's and lives in Field's layout; moving it into the fieldset means restructuring Field for one control.
- `required` or `aria-required` on each checkbox for a required group — announces, and in the browser enforces, that every box is required.
- Following Rails for checked, disabled values (not submitting them) — deletes a value the form showed as checked and locked on every save; overruled by the decider 2026-09-14.
- `ui--roving-focus` on the radio group — native radios already own arrow keys, and a second implementation would fight the browser's.
- Marking the round-trip demo's checkbox group `required:` — the browser then blocks the empty submission before the request, so the page could never show the 422 it exists to show. The required pair has its own section; the round trip is the no-JavaScript path, enforced by the model.

## Corrections

- § Behavior, item 5 said Rails' blank hidden field carries `autocomplete="off"`. It does not: `collection_helpers.rb` renders it through `hidden_field_tag` with `id: nil` and `form:` only (ActionView 8.1.3.1, and identical in 7.2.3.2). `autocomplete="off"` belongs to `checkbox`'s hidden field. Choices renders what the collection helpers render, and `choices_component_test` compares attribute for attribute against the real helper rather than against this spec's prose — provable — implementer
- § Behavior, item 16 said a `currentColor` stroke becomes `CanvasText` in forced colours, so the mark survives. Measured in Chrome 152 with forced colours emulated: the input's own `background-color` is forced to `Canvas`, but an SVG's `stroke`/`color` is left alone, so the mark stayed `--primary-foreground` and the measured contrast against the forced-white fill was 1.04:1 — invisible. The mark now names the system colour itself (`forced-colors:text-[CanvasText]`), and `choices_variant_test` measures it rather than trusting the forcing — provable — implementer
- § Behavior, item 3 said the option set's error messages "take the calling component's name"; it did not say how. `component:` is a required keyword on `Ui::OptionSet`, so a new caller cannot forget it and inherit Select's name by accident — tasteable — implementer
- The fieldset's own class list (`group/choices grid min-w-0 gap-2`) is what item 16's invalid rule and item 18's `min-w-0` both hang off. It was missing from the first implementation, and both the variant check (invalid lost to checked, measured as a real colour) and the layout check caught it. Recorded because the same omission would be invisible in a render test — provable — implementer
- `appearance:` was renamed to `variant:`, ratified 2026-09-15 by an independent API review, relayed by the orchestrator: `appearance` is a style variant, the same shape Button already names `variant:`, and Choices had zero released consumers to break. `Ui::Choices::Appearance` moved to `Ui::Choices::Variant` (`app/components/ui/choices/variant.rb`), `choices_appearance_test.rb` became `choices_variant_test.rb`, and the docs page and spec were updated to match — provable — implementer
