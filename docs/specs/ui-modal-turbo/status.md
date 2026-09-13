## State

building

Ratified 2026-09-13 and not started. Nothing blocks the first unit. All five open
questions were decided by Jonathan on 2026-09-13 and folded into `spec.md`;
`open-questions.md` is deleted. The browser lane they run in is built (`04237d6`).

## Done

- Shaped from Jonathan's approved direction (2026-09-13) against the live repository:
  `6a07152`, `modal_controller.js`, `modal_component.rb`,
  `examples/app/views/docs/modal.html.erb`, `modal_demo.turbo_stream.erb`, the docs
  layout, `docs_controller.rb`, `routes.rb`, `rails_ui_kit.gemspec` and the install
  generator.
- Confirmed the gemspec's `files` glob ships no `docs/` file today, which is why
  § Critical files names the `docs/guides/**/*` addition.
- Authored `spec.md`, `relations.md`, `open-questions.md` and this `status.md`.
- Folded Jonathan's five 2026-09-13 open-question decisions into `spec.md` (§ Behavior
  items 2, 7, 11, 12, 16; § Business rules, rules 2, 3, 5, 8) and deleted
  `open-questions.md`, now empty.

## In progress

None. Suggested first unit: the in-memory demo resource with real routes and a real
`422`, driven by `test/system/modal_turbo_open_test.rb` and
`test/system/modal_turbo_validation_test.rb`. The API additions and the guide both
build on those endpoints.

## Last green checkpoint

none — build has not started; no demo endpoint, guide or generator exists yet

## Dead ends

None yet.

## Corrections
