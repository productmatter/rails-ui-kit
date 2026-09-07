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

None yet. Corrections are recorded here as prose when a build-loop iteration
invalidates something this spec asserts.
