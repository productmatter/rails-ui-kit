# Status — ui-positioning-and-navigation

## State

building

Shaped and ratified. No implementation has started; the two open questions in
`open-questions.md` do not block starting Primitive A. Two further questions —
the accessibility assertion stack, and how system tests stay out of the unit
lane — were answered by `ui-test-harness` and removed from that file.

## Done

- Shaped against the live repository: the three duplicated `position()` implementations,
  `config/importmap.rb`, `package.json`, `index.js`, the `Rakefile` test lane.
- Controller identifiers chosen and recorded: `ui--anchor`, `ui--roving-focus`,
  `ui--media-query`. Primitive E ships no controller.
- The parent's Floating UI importmap assumption checked against the actual published
  artifacts and found incorrect for the pinned version. Evidence recorded in
  § Assumptions; the decision it implies is escalated in `open-questions.md`.

## In progress

Nothing yet.

## Last green checkpoint

none — no implementation has started; the system-test lane this scope's acceptance
checks run in does not exist in the repository yet.

## Dead ends

None recorded yet.

## Corrections

- Spec said disabled items are skipped by navigation, `Home`/`End` and typeahead; the shipped `dropdown_controller` (`032b33c`) instead follows the W3C ARIA Authoring Practices — reachable but inert, since skipping hides options from screen reader users. `skipDisabled` now defaults to `false` (focusable-but-inert), with `true` available for groups that want skipping. Rule 5 ("always exactly one tab stop") corrected to allow a focused disabled item to hold the tab stop in the default mode — tasteable — decider
- Spec said `Home`, `End` and typeahead are always handled by the group; in `activedescendant` mode an editable `input` target (a real text field) keeps those keys for itself, and the controller only claims them when the `input` target is non-editable (a select-only combobox) — provable — implementer
- Spec was silent on pointer interaction in `activedescendant` mode; the shipped controller cancels `mousedown` on an item so a click can't pull DOM focus out of the `input` — provable — implementer
- Spec was silent on why `ui--anchor` has no `turbo:before-cache` handler; recorded that it holds no open state, so `disconnect()` plus a fresh render on restore is sufficient and a handler would be dead code — provable — implementer
- The Floating UI pin-collapse open question is resolved: decided 2026-09-13, Jonathan Simmons, option (a). `config/importmap.rb` now pins one `@floating-ui/dom` entry at the jsDelivr `+esm` URL; `core` and `utils` pins deleted. Removed from `open-questions.md` and folded into § Assumptions — tasteable — decider

**Follow-up for the code, not this spec:** the shipped `roving_focus_controller.js` still defaults `skipDisabled` to `true` (skip), and the primitives demo page's own values table documents that default — both are the opposite of the decision above and need to flip to `false` before this spec and the code agree. Flagged for whichever worker owns that file next; not fixed here since this worker owns only `docs/specs/`.
