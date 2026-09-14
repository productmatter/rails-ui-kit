# Status — ui-positioning-and-navigation

## State

ready-for-review

All five primitives are built and every component consumes them, with each
agent-loopable check passing. What remains is the judgeable review and Jonathan's
human gates. `ui-select` is the next consumer; the primitive support it needed
(`pageStep`, and the Field label id) has already landed.

## Done

- Shaped against the live repository: the three duplicated `position()` implementations,
  `config/importmap.rb`, `package.json`, `index.js`, the `Rakefile` test lane.
- Controller identifiers chosen and recorded: `ui--anchor`, `ui--roving-focus`,
  `ui--media-query`. Primitive E ships no controller.
- The parent's Floating UI importmap assumption checked against the actual published
  artifacts and found incorrect for the pinned version. Evidence recorded in
  § Assumptions; the decision it implies is escalated in `open-questions.md`.
- Built all five primitives in `39e7dd8`: `ui--anchor` (the kit's only Floating UI
  importer, publishing `data-side` and `data-align` from the resolved placement,
  measuring the caller's control rather than a wrapper, releasing `autoUpdate` on
  disconnect or a Turbo Stream swap), `ui--roving-focus` (arrows, `Home`, `End` and
  typeahead in the two separate focus models), `ui--media-query`, and
  `Ui::FieldComponent` with `Ui::Field::ControlComponent`,
  `Ui::Field::DescriptionComponent` and `Ui::Field::ErrorComponent`. Floating UI
  collapsed from four hand-maintained pins to the one bundled ESM pin.
- Retrofitted the consumers in `144d104`: Dropdown, Popover and Tooltip lost 379 lines
  between them, Floating UI is imported once, and Dropdown's menu keyboard model moved
  onto `ui--roving-focus`. That commit also flipped `skipDisabled` to default `false`,
  which is what the § Corrections follow-up below asked for, and the flip exposed a real
  defect: a natively disabled item was navigable, so arrows dead-ended on an element
  that cannot take focus. Natively disabled items are now excluded from roving
  navigation while `aria-disabled` ones stay discoverable.
- Added the support `ui-select` needs, in `11d71a9`: `ui--roving-focus`'s `pageStep`
  (`PageDown` / `PageUp`, off at `0`), and an id on Field's label so a control
  `<label for>` cannot name has something to point `aria-labelledby` at. Both are
  recorded in § Behavior, Primitive C and Primitive E (`8f606c4`).
- Twelve test files cover the scope: `anchor_position`, `anchor_arrow`,
  `anchor_cleanup`, `roving_focus_menu`, `roving_focus_listbox`,
  `roving_focus_page_keys`, `roving_focus_dynamic`, `roving_focus_typeahead`,
  `media_query` and `primitives_a11y` in the browser lane, plus
  `test/components/ui/field_component_test.rb`,
  `test/javascript/register_controllers_test.rb` and
  `test/importmap/floating_ui_pins_test.rb` in the unit lane. Browser helpers shared by
  the anchor and roving-focus files live in `test/system/primitives_helpers.rb`.

## In progress

None. The next work that touches this scope is `ui-select`, which composes `ui--anchor`
and `ui--roving-focus` (`activedescendant` mode, both key tables) and reimplements
neither.

## Last green checkpoint

2026-09-14, at `359aa75` plus the uncommitted `ui-select` Phase 1 work, every
agent-loopable check run on its own: `bundle exec rake test` 300 runs / 827 assertions,
which carries the Field, `registerControllers` and Floating UI pin checks;
`anchor_position` 9, `anchor_arrow` 4, `anchor_cleanup` 4, `roving_focus_menu` 12,
`roving_focus_listbox` 8, `roving_focus_page_keys` 4, `roving_focus_dynamic` 7,
`roving_focus_typeahead` 8, `media_query` 3 and `primitives_a11y` 2 runs — 0 failures
throughout.

## Dead ends

None recorded yet.

## Corrections

- Spec said disabled items are skipped by navigation, `Home`/`End` and typeahead; the shipped `dropdown_controller` (`032b33c`) instead follows the W3C ARIA Authoring Practices — reachable but inert, since skipping hides options from screen reader users. `skipDisabled` now defaults to `false` (focusable-but-inert), with `true` available for groups that want skipping. Rule 5 ("always exactly one tab stop") corrected to allow a focused disabled item to hold the tab stop in the default mode — tasteable — decider
- Spec said `Home`, `End` and typeahead are always handled by the group; in `activedescendant` mode an editable `input` target (a real text field) keeps those keys for itself, and the controller only claims them when the `input` target is non-editable (a select-only combobox) — provable — implementer
- Spec was silent on pointer interaction in `activedescendant` mode; the shipped controller cancels `mousedown` on an item so a click can't pull DOM focus out of the `input` — provable — implementer
- Spec was silent on why `ui--anchor` has no `turbo:before-cache` handler; recorded that it holds no open state, so `disconnect()` plus a fresh render on restore is sufficient and a handler would be dead code — provable — implementer
- The Floating UI pin-collapse open question is resolved: decided 2026-09-13, Jonathan Simmons, option (a). `config/importmap.rb` now pins one `@floating-ui/dom` entry at the jsDelivr `+esm` URL; `core` and `utils` pins deleted. Removed from `open-questions.md` and folded into § Assumptions — tasteable — decider
- The `skipDisabled` follow-up recorded here for whichever worker owned `roving_focus_controller.js` next is done: `144d104` flipped the default to `false` and updated the primitives demo page's values table with it, so the code and this spec agree — provable — implementer
