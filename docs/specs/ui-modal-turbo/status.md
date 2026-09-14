## State

building

Ratified 2026-09-13, built 2026-09-14 on `feature/ui-kit-foundation`. Every § Acceptance check
outside the human gate runs green. What is left is Jonathan's read of the guide and the generated
skill (§ Acceptance checks, human-gate) and the `CHANGELOG.md` entry, which the decider owns.

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
- **The demo resource (2026-09-14).** `Project` and `Invitation` (in-memory ActiveModel objects
  with server-only validations, reset per test), `ProjectsController`, `InvitationsController`,
  their routes and views, the `Modal & Turbo` docs page (`DocsPages` entry, Overlays section) and
  the layout's `<div id="modal" data-turbo-permanent>`. The Modal page's inline `<template>`
  stand-ins are gone; its Usage samples now show the stream pattern rather than a form in a frame
  (§ Business rules, rule 1).
- **The API additions (2026-09-14).** `turbo_stream.ui_close_modal`
  (`lib/rails_ui_kit/turbo_streams.rb`, joined to Turbo's tag builder through its
  `:turbo_streams_tag_builder` load hook; the client half registered from
  `index.js` via `window.Turbo.StreamActions`, so no host needs a new importmap pin) and
  `ui--modal#closeOnSuccess`. Both reach the one animated close (§ Business rules, rule 7).
- **Two primitive fixes the lifecycle proved necessary (2026-09-14).** `ui--overlay` restores
  focus by the trigger's remembered id when the response that closed the modal replaced the
  trigger (§ Business rules, rule 8), and re-applies the scroll lock on `turbo:morph`, which
  morphs `<body>`'s inline styles off it.
- **The guide (2026-09-14).** `docs/guides/modal-and-turbo.md`, shipped through the gemspec's new
  `docs/guides/**/*` glob. `test/modal_and_turbo_guide_test.rb` asserts every sample in it is a
  verbatim slice of the demo file it names, that it quotes every demo file the lifecycle is built
  from, and that it is packaged.
- **The agent skill (2026-09-14).** `rails g rails_ui_kit:agent_skill` writes
  `.claude/skills/rails-ui-kit/SKILL.md` and one `AGENTS.md` pointer line, both resolving the
  guide from the installed gem; `rails_ui_kit:install` still writes neither.
- **The browser lane (2026-09-14).** Ten `test/system/modal_turbo_*_test.rb` files, one per
  § Acceptance check, plus `modal_test.rb` re-pointed at the real demo (its four
  stand-in-era tests that the lifecycle files now cover with stronger assertions were retired,
  not lost: replace, in-frame navigation, focus-across-swap and the frame flow).

## In progress

None.

## Last green checkpoint

2026-09-14, `feature/ui-kit-foundation`: `bundle exec rake test` and `bundle exec rake test:system`
both green, plus `SLOW=1` on every file that submits a form or swaps content, and
`bundle exec rubocop` clean.

## Dead ends

- **Asserting on text the previous modal also renders.** The first draft of the `closeOnSuccess`
  tests waited for `'#modal dialog'` with text "Invite a teammate" — which the *project* modal's
  own button already says, so the assertion passed before the response arrived and every
  measurement after it described the wrong modal. The lifecycle helpers now wait on the incoming
  modal's own content frame.
- **A `presence: true` validation as the 422 demo.** The browser refuses to submit the form at
  all, so the server never sees it. Both demo models grew a rule only the server can check.

## Corrections

All 2026-09-14, against the shipped code, and folded into `spec.md` where they contradicted it:

- **§ Non-goals, "Not the overlay primitives".** Scroll lock, focus restore and the exit
  animation are already `ui--overlay`/`ui--presence`'s (`6116cbd`), not `ui--modal`'s. Two
  changes in this scope are therefore in the primitive, by design rather than by trespass.
- **§ Critical files, `modal_controller.js`.** There is no `close`/`performClose` pair; the
  animated close is `ui--overlay#close` awaiting `ui--presence`. `closeOnSuccess` and
  `closeFromServer` both call it.
- **§ Assumptions, "no `db/` and no models".** `examples/` has had ActiveModel form objects since
  `ui-select` and `ui-field-model-binding`. Only the database is missing.
- **§ Assumptions, page cache vs morphing refresh.** Now observed rather than assumed: a morphing
  refresh does not fire `turbo:before-cache` (it passes `shouldCacheSnapshot: false`), so the
  teardown never runs; the container needs `data-turbo-permanent` or the modal is morphed away;
  and the refresh morphs the scroll lock off `<body>`, which is why `relockScroll` exists.
- **§ Behavior, item 13, `data-turbo-action="advance"`.** Not a pattern to document positively:
  the advance visit caches a snapshot as soon as the response lands, and the teardown removes the
  modal ~15ms after it opened. The guide documents it as a thing not to do.
- **§ Critical files, the docs layout.** The frame-target demo cannot keep "its own separate
  `<turbo-frame id="modal">`" — two elements with the same id on one page. It has
  `id="project_activity_modal"`.
- **§ Acceptance checks, the packaging one-liner.** Replaced by
  `test/modal_and_turbo_guide_test.rb`, which packages *and* pins every sample to its source
  file. Drift between guide and demo was the risk worth a test, not the glob.
