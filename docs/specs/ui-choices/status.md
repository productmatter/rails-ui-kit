## State

blocked: awaiting ratification — both open questions are decided (2026-09-14); the build starts after `spec-localization` commits its Select changes, because the `Ui::OptionSet` move touches Select's files. Nothing is built.

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

## In progress

None.

## Last green checkpoint

none — spec only; no code exists for this scope yet, and `specline_check` reports 0 errors with no new warnings.

## Dead ends

- A `div role="group"` root instead of a fieldset — loses native `disabled` over every descendant, including the hidden field, and stops being a group when CSS and ARIA are gone.
- Naming the group with Field's `<label for>` pointed at the first input — clicking the group's label would toggle that choice, and the input would take the group's name.
- A `<legend>` rendered by Choices — the visible label is Field's and lives in Field's layout; moving it into the fieldset means restructuring Field for one control.
- `required` or `aria-required` on each checkbox for a required group — announces, and in the browser enforces, that every box is required.
- Following Rails for checked, disabled values (not submitting them) — deletes a value the form showed as checked and locked on every save; overruled by the decider 2026-09-14.
- `ui--roving-focus` on the radio group — native radios already own arrow keys, and a second implementation would fight the browser's.

## Corrections

None yet.
