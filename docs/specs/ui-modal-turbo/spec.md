---
slug: ui-modal-turbo
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: medium
size: large
target_model: standard
created: 2026-09-13
loop_budget: 6
---

## Intent

Host apps use `Ui::ModalComponent` with Turbo, and the agents that implement those
modals get the wiring wrong. A studio app's own modal doc showed the pattern in use
and exposed the gaps. It used a controller identifier and actions that don't exist in
this gem. It closed the modal on any 2xx response. It wrapped lists in turbo-frames
just to update them. Nothing in the gem told the agent otherwise: the only record of
the intended pattern is the docs app's Modal page.

`6a07152` made the core pattern work. A modal renders into a plain `<div>`, closes
through a Turbo Stream, is replaced by another modal, swaps an inner frame without
re-animating, and survives Turbo's page cache. None of that is proven end to end yet.
The page's stream demo runs on inline `<template>` stand-ins for server responses,
there is no real `422`, and no browser test drives any of it.

This scope turns that working mechanism into a pattern an agent in a host app gets
right the first time:

- blessed patterns and a full open-to-close lifecycle;
- two small API additions, so a modal closes on success and animates out when the
  server closes it;
- one canonical guide, versioned inside the gem, whose code is the demo code and
  whose claims are the system tests;
- an opt-in agent skill that points a host's agents at the guide in the installed gem.

**Appetite.** A guide, real demo endpoints, their browser tests, two API additions and
one generator. The Modal's look, its Ruby constructor and the overlay primitives are
untouched.

## Goal

Every modal lifecycle step in § Behavior runs against real routes and controller
actions in the `examples/` docs app and passes its own system test, and the guide that
describes exactly that code ships in the gem's file list and is what
`rails g rails_ui_kit:agent_skill` points a host's agents to.

## Non-goals

- **Rendering a modal closed and opening it client-side.** A future pattern. It
  conflicts with `6a07152`, where a closed modal removes its own element, so it would
  need a new option.
- **Deep-linkable modals**, beyond documenting `data-turbo-action="advance"`.
- **Modal visual changes.** That is `ui-foundation-retrofit`'s job.
- **Not part of `rails_ui_kit:install`.** Install never writes into `.claude/` or
  `AGENTS.md` unasked.
- **Not a copy of the guide in the host.** The skill points to the installed gem's
  guide, so upgrading the gem can never leave stale agent instructions behind.
- **Not a skill per component.** One kit-wide skill; later components add a reference.
- **Not the overlay primitives.** Scroll lock, focus restore and exit animation stay in
  today's `ui--modal`. Moving them onto `ui--overlay`/`ui--presence` belongs to
  `ui-presence-and-overlay-stack` and `ui-foundation-retrofit`.
- **Not a rebuild of `examples/`** (§ Non-goals of ui-component-library). It gains
  demo endpoints; nothing else is restructured.

## Behavior

### Blessed patterns

1. **Primary: a Turbo Stream into a layout container.** The layout holds
   `<div id="modal">`. A link with `data-turbo-stream` requests the modal. The
   `*.turbo_stream.erb` response does `turbo_stream.update "modal"`, rendering
   `Ui::ModalComponent`. The same response may also update other regions, such as a
   list or the flash.
2. **Supported for read-only modals: a Turbo Frame target.** A `<turbo-frame
   id="modal">` container and a link carrying `data-turbo-frame="modal"`. In the docs
   app this lives in its own read-only demo, separate from the layout's shared
   `<div id="modal">` container that carries the primary pattern (item 1; see
   § Critical files). The guide documents it, but never shows it for a form: a
   redirect after a successful submission renders "Content missing" inside the frame.
3. **An inner content frame.** Inside the modal, `turbo_frame_tag
   "<resource>_modal_content"` wraps the content. Show ↔ edit navigation and
   validation re-renders swap only that frame. The dialog is not re-mounted and does
   not re-animate.

### Lifecycle

Each step has a demo in `examples/`, backed by real routes and controller actions, and
a system test that drives that demo.

4. **Open.** Following the trigger opens the modal with its entry animation. The
   modal has an accessible name, focus moves into the dialog, and the page behind is
   scroll-locked.
5. **In-modal navigation.** A link inside the content frame (show → edit → show)
   replaces only the frame's content. It is the same `<dialog>` element, with no
   entry animation replayed and focus kept inside the dialog.
6. **Validation errors.** An invalid submission responds `422`. Turbo rejects a `200`
   HTML response to a form submission, so a `200` is never correct for an invalid
   form. The error re-renders inside the content frame, with the field marked
   `aria-invalid` and described by its error. The modal is not re-mounted, does not
   close and does not re-animate.
7. **Success.** The server-sent `turbo_stream.ui_close_modal` action in the success
   response is the primary close mechanism (§ Business rules, rule 3): the server
   knows the save succeeded, so the same response closes the modal with its exit
   animation and updates the other regions it changed, such as the list row and the
   flash. `ui--modal#closeOnSuccess` (item 11) is the convenience path for a
   non-stream response. The scroll lock is released. Focus returns to the trigger
   that opened the modal, including when the response replaced it (§ Business rules,
   rule 8).
8. **Delete.** A destructive action inside the modal asks for confirmation through
   the kit's ConfirmDialog, which opens above the modal. Confirming closes the modal
   with its exit animation and updates the affected regions. Cancelling the
   confirmation leaves the modal open, with focus back inside it.
9. **Cancel.** A close button (`ui--modal#close`), Escape and a backdrop click each
   close the modal with its exit animation, with no server request. The scroll lock
   is released and focus returns to the trigger. With `track_changes: true` and a
   dirty form, the unsaved-changes confirmation runs first.
10. **Replace while open.** A stream response that updates `"modal"` while a modal is
    open replaces it with the new one. There is exactly one dialog in the container
    afterwards, the page stays scroll-locked throughout, and closing the second modal
    returns focus to the element that opened the first.

### API additions

11. **`ui--modal#closeOnSuccess`**, a convenience for a non-stream success response
    (§ Business rules, rule 3), wired by a form inside the modal as
    `data-action="turbo:submit-end->ui--modal#closeOnSuccess"`. It closes the modal
    through the same animated close as `ui--modal#close`, and only when the
    submission succeeded (`event.detail.success`, true for any `2xx`). A `422` leaves
    the modal open.
12. **`turbo_stream.ui_close_modal`**, a kit custom Turbo Stream action, namespaced to
    the kit rather than a bare `close_modal` (§ Business rules, rule 3). The helper
    renders `<turbo-stream action="ui_close_modal" target="modal">`, and it accepts
    another container id. The client action closes the kit modal inside the target
    with its exit animation and leaves the container in place for the next modal. It
    is a no-op when no modal is open, so it is safe alongside `closeOnSuccess`. It
    bypasses the unsaved-changes guard, since the server has already accepted the
    change. Removing or emptying the element from the server still cleans up
    (`6a07152`), but it can't animate, so the guide never shows it as the way to
    close.

### The guide

13. **One canonical guide**, `docs/guides/modal-and-turbo.md`, versioned inside the gem
    and listed in the gemspec's `files`. It is authored in this scope's build, not
    before. It walks items 1–12, and every code sample is the code a named demo
    actually runs. It also covers these gotchas, each against demo code:
    - Don't wrap a list in a turbo-frame just to target it with a stream. Any element
      id works, and a frame changes how every link inside it behaves.
    - Turbo 8 morphing page refreshes can wipe an open modal unless its container is
      `data-turbo-permanent`.
    - Content-frame ids must be unique on the page. A frame id that matches a frame on
      the page behind the modal resolves to the wrong frame.
    - Name every modal through `Ui::ModalComponent`'s `aria:` keyword. A
      `labelledby` id must exist in every state the content frame renders.
    - Focus: where it lands on open, after a content-frame swap, and on close.
    - The Back button: an open modal is removed before Turbo caches the page, so Back
      never restores it (`6a07152`).
    - Format negotiation. A form submission asks for Turbo Stream first. An invalid
      `render :edit` can therefore pick up the modal's *open* template,
      `edit.turbo_stream.erb`, and re-mount the modal instead of re-rendering the frame.
    - `data-turbo-action="advance"`, for a modal whose URL should enter history.
14. **Demos, guide and tests are one source.** The `examples/` Modal demos move from
    inline `<template>` stand-ins to real endpoints that return real streams and real
    `422`s. The system tests in § Acceptance checks drive those endpoints, so the
    guide, the demos and the tests can't drift apart.

### The agent skill

15. **`rails g rails_ui_kit:agent_skill`** is a separate, opt-in generator. It writes a
    thin `.claude/skills/rails-ui-kit/SKILL.md` into the host. The skill's description
    triggers when an agent implements a modal, a modal form or a Turbo-driven overlay.
    Its body tells the agent to read the guide from the installed gem version
    (`bundle info --path rails_ui_kit`, then `docs/guides/`). It lists Modal
    (`modal-and-turbo.md`) as its first reference and copies no guide content.
16. The generator adds one pointer line to the host's `AGENTS.md` for non-Claude
    agents, naming the same installed-gem guide location — creating `AGENTS.md`
    containing just that line when the host has none, and appending the line when the
    host already has the file (decided 2026-09-13, Jonathan Simmons).
17. Re-running the generator changes nothing that is already in place. It doesn't
    duplicate the `AGENTS.md` line, and it overwrites `SKILL.md` only with Rails'
    usual conflict prompt.

## Business rules

**Must**

1. **One primary pattern.** The guide leads with the stream-into-a-container pattern
   (§ Behavior, item 1). The frame-target pattern appears only for read-only modals;
   no guide sample or demo puts a form in it.
2. **An invalid submission responds `422`, in every format including `turbo_stream`.**
   No guide sample, demo or test answers an invalid form with a `2xx` — a `200`
   `turbo_stream` error re-render would trip `ui--modal#closeOnSuccess`'s
   `detail.success` check and close the modal on a failed submission (§ Behavior,
   item 7; decided 2026-09-13, Jonathan Simmons).
3. **The server closes a modal with `turbo_stream.ui_close_modal`, and it is the
   primary close mechanism.** The guide never shows `remove` or an empty `update` as
   the way to close one. The action is namespaced — `ui_close_modal`, not
   `close_modal` — because an unprefixed name can silently collide with an action a
   host app already registers, and `ui_` matches the kit's `ui--` Stimulus prefix and
   `Ui::` namespace. `ui--modal#closeOnSuccess` (§ Behavior, item 11) remains a
   convenience for a non-stream success response: it reacts to Turbo's own
   `detail.success` (true for any `2xx`), which is safe only because rule 2 makes
   every invalid submission a `422` — closing on any `2xx` without that guarantee is
   exactly the defect the studio app's own modal doc shipped (§ Intent). All decided
   2026-09-13, Jonathan Simmons.
4. **The guide, the demos and the tests change together.** Every guide code sample
   matches demo code, and every lifecycle step has a system test driving that demo. A
   change to one without the others is incomplete, not a follow-up.
5. **The guide ships in the gem, and the skill never copies it.** `spec.files`
   includes the guide via a targeted `docs/guides/**/*` glob, not a top-level
   `guides/` directory — nothing in Specline's rules rejects an extra `docs/`
   subtree, and the targeted glob keeps specs and audits out of the gem (decided
   2026-09-13, Jonathan Simmons). The generated skill resolves the guide from the
   installed gem version at the time the agent reads it.
6. **Install stays quiet.** `rails_ui_kit:install` writes nothing into `.claude/` or
   `AGENTS.md`. Only the opt-in `rails_ui_kit:agent_skill` generator does.
7. **Neither API addition is a second close implementation.** `closeOnSuccess` and the
   `ui_close_modal` stream action both reach `ui--modal`'s existing animated close
   (§ Business rules of ui-component-library, rule 4).
8. **Accessibility is in the definition of done** (§ Business rules of
   ui-component-library, rule 6). Every demo modal is named, focus is correct at every
   lifecycle step — including remembering the trigger's id and restoring focus to the
   element now carrying it when a success response replaced the trigger, or leaving
   focus unmoved when the trigger had no id (§ Behavior, item 7; decided 2026-09-13,
   Jonathan Simmons) — and the demos pass `assert_accessible`.

**Should**

9. **One kit-wide skill.** A later component adds a reference to it, never a second
   skill.
10. **Stream targets are plain ids.** The guide and demos never wrap a region in a
    turbo-frame solely so a stream can target it.

**May**

11. A host may use the frame-target pattern for a read-only modal (§ Behavior, item 2).

## Assumptions

- **Turbo 8 is present.** `Gemfile.lock` resolves `turbo-rails` 2.0.23, which provides
  custom `StreamActions` and morphing page refreshes. The kit's JavaScript must reach
  `StreamActions` without a new importmap pin for host apps. **At a contradiction**,
  where registering the action requires a new pin or a host-side import, escalate
  rather than adding a pin quietly.
- **Turbo's form-submission contract is as described.** A `200` HTML response to a
  form submission is rejected. `turbo:submit-end` reports `detail.success` for a `2xx`
  response. Non-GET submissions list Turbo Stream first in `Accept`, which is the
  format-negotiation gotcha in § Behavior, item 13.
- **The page-cache teardown and morphing refreshes are unverified together.**
  `6a07152` removes an open modal on `turbo:before-cache`. Whether a morphing refresh
  fires that event, and so closes a modal inside a `data-turbo-permanent` container
  anyway, has not been observed. Verify it in the browser before the guide states the
  gotcha. **At a contradiction**, escalate. Don't weaken the cache teardown, which
  fixes a live Back-button bug.
- **The docs app has no database.** `examples/` has no `db/` and no models. The demo
  resource is an in-memory ActiveModel object with real validations, reset between
  tests. Its controller code must still read like a host app's ActiveRecord
  controller. If that isn't possible without distorting the guide's samples, escalate
  rather than adding a database.
- **`bundle info --path rails_ui_kit` finds the installed guide** for both rubygems
  and git-sourced installs. Both live consumers use a `git:` source on `main`, where
  Bundler checks out the whole repository. The gemspec's `files` is what governs a
  built gem.
- **Claude Code discovers project skills at `.claude/skills/<name>/SKILL.md`,** with
  `name` and `description` frontmatter. If that format has moved at build time, follow
  the current format and record a correction. The pointer-to-installed-guide design
  doesn't change.
- **The browser lane exists.** `ui-test-harness` built it in `04237d6`
  (`relations.md`). Every system test here inherits `ApplicationSystemTestCase` and
  runs with `bundle exec rake test:system`.
- **The retrofit will rewrite `ui--modal`'s internals.** `ui-foundation-retrofit` moves
  Modal onto `ui--overlay`/`ui--presence`. `closeOnSuccess`, `ui_close_modal` and the
  `aria:` keyword are public API that must survive the move, and these system tests
  are how it proves that. The guide is updated in the same change as any rename.

## Critical files

- `app/javascript/rails_ui_kit/controllers/modal_controller.js` — gains
  `closeOnSuccess`; `close`/`performClose` is the animated path both API additions
  reuse.
- `app/javascript/rails_ui_kit/index.js` — the registration surface; the
  `ui_close_modal` stream action is registered from here.
- `lib/rails_ui_kit/engine.rb` — where the `turbo_stream.ui_close_modal` helper joins
  Turbo's tag builder.
- `app/components/ui/modal_component.rb` — the `aria:` keyword the guide teaches. Read
  only; no constructor or class changes.
- `rails_ui_kit.gemspec` — `spec.files` globs `{app,config,lib}/**/*` plus
  `MIT-LICENSE`, `Rakefile`, `README.md` and `package.json`, so no `docs/` file ships
  today. It gains `docs/guides/**/*`, not `docs/**/*`, which would also ship specs and
  audits.
- `docs/guides/modal-and-turbo.md` (new) — the canonical guide.
- `lib/generators/rails_ui_kit/agent_skill/` (new) — the opt-in generator and its
  `SKILL.md` template.
- `lib/generators/rails_ui_kit/install/install_generator.rb` — read for generator
  conventions; must not gain any `.claude/` or `AGENTS.md` write.
- `examples/config/routes.rb`, `examples/app/controllers/docs_controller.rb` — today's
  `modal_demo`, `demo_submit` (`sleep 1.5; head :no_content`) and `demo_delete` stand-ins.
  They gain the real demo resource routes and actions.
- `examples/app/views/docs/modal.html.erb` — the Turbo Stream pattern section and its
  inline `<template>` stand-ins, which real endpoints replace.
- `examples/app/views/docs/modal_demo.turbo_stream.erb` — the position-preview stream.
- `examples/app/views/layouts/docs.html.erb` — moves from today's single shared
  `<turbo-frame id="modal">` to the blessed `<div id="modal">` for the primary
  pattern (§ Behavior, item 1). The frame-target pattern (item 2) keeps its own
  separate `<turbo-frame id="modal">` in a read-only demo, not the shared layout
  container.
- `test/application_system_test_case.rb`, `test/system/` — the lane every lifecycle
  test joins.
- `test/generators/install_generator_test.rb` — the precedent for the new generator
  test.
- `CHANGELOG.md` — records both API additions and the generator.

## Acceptance checks

### agent-loopable

- Opening from a `data-turbo-stream` link renders the modal into the layout container, names it, moves focus into it and locks scroll — run: `bundle exec rake test:system TEST=test/system/modal_turbo_open_test.rb`
- Show → edit → show inside the content frame keeps the same dialog element open without replaying the entry animation, with focus inside the dialog — run: `bundle exec rake test:system TEST=test/system/modal_turbo_navigation_test.rb`
- An invalid submission gets a `422`, re-renders the error inside the content frame with `aria-invalid`, and neither closes nor re-mounts the modal — run: `bundle exec rake test:system TEST=test/system/modal_turbo_validation_test.rb`
- A valid submission closes the modal with its exit animation both ways — `ui_close_modal` in a stream response that also updates the list row and flash, and `closeOnSuccess` on a non-stream response — releasing scroll and restoring focus each time — run: `bundle exec rake test:system TEST=test/system/modal_turbo_success_test.rb`
- Confirming a delete closes the modal and removes the row; cancelling the confirmation keeps the modal open with focus inside it — run: `bundle exec rake test:system TEST=test/system/modal_turbo_delete_test.rb`
- Close button, Escape and backdrop click each close without a request, release scroll and restore focus — run: `bundle exec rake test:system TEST=test/system/modal_turbo_cancel_test.rb`
- A stream that replaces an open modal leaves exactly one dialog, keeps scroll locked throughout, and returns focus to the first trigger when the second closes — run: `bundle exec rake test:system TEST=test/system/modal_turbo_replace_test.rb`
- A read-only modal opened through the frame-target pattern opens and closes cleanly, and Back after opening never restores it — run: `bundle exec rake test:system TEST=test/system/modal_turbo_frame_test.rb`
- An open modal in a `data-turbo-permanent` container survives a morphing page refresh — run: `bundle exec rake test:system TEST=test/system/modal_turbo_morph_refresh_test.rb`
- The demo modal passes an axe audit when open and in its validation-error state — run: `bundle exec rake test:system TEST=test/system/modal_turbo_accessibility_test.rb`
- `turbo_stream.ui_close_modal` renders a `ui_close_modal` stream targeting `modal`, or the id it is given — run: `bundle exec rake test TEST=test/turbo_stream_ui_close_modal_test.rb`
- The guide exists and is in the built gem's file list — run: `ruby -e "raise('guide not packaged') unless Gem::Specification.load('rails_ui_kit.gemspec').files.include?('docs/guides/modal-and-turbo.md')"`
- The agent-skill generator writes `SKILL.md` and one `AGENTS.md` pointer line idempotently, and install writes neither — run: `bundle exec rake test TEST=test/generators/agent_skill_generator_test.rb`

### judgeable

- Every lifecycle step in the guide shows the code its demo actually runs, and nothing the guide instructs contradicts that code — judged against § Behavior, items 1–12, and § Business rules, rule 4.
- The guide covers every gotcha listed in § Behavior, item 13, each tied to demo code rather than asserted in prose alone.
- `closeOnSuccess` and the `ui_close_modal` action both reach `ui--modal`'s existing animated close, with no second close path, per § Business rules, rule 7 and rule 4 in the § Business rules section of ui-component-library.
- The generated `SKILL.md` is thin: it copies no guide content and resolves the guide from the installed gem, per § Behavior, item 15 and § Business rules, rule 5.

### human-gate

- Jonathan reads the guide and the generated skill as an agent would, and confirms they would produce a correct modal implementation the first time.

## Out of scope / deferred

- **A modal rendered closed and opened client-side** — a future pattern needing an
  option, because `6a07152` makes a closed modal remove its own element.
- **Deep-linkable modals** beyond documenting `data-turbo-action="advance"`.
- **Modal visual changes** — `ui-foundation-retrofit`.
- **Moving Modal onto the overlay primitives** — `ui-presence-and-overlay-stack` builds
  them and `ui-foundation-retrofit` ports Modal, keeping this scope's tests green.
- **Skill references for other components** — each added by the scope that ships the
  component's guide.
- **Agent-specific formats beyond Claude Code's skill** (editor rule files and the
  like) — the `AGENTS.md` pointer is the only non-Claude surface.
