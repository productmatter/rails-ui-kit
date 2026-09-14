## State

ratified

Ratified 2026-09-14 by the orchestrator, who also decided both open questions. Nothing is
built. **The first build step is the top-layer reachability probe** (§ Acceptance checks,
first agent-loopable check). Nothing that depends on promoting the container starts
before its result is recorded here.

## Done

- Read `CLAUDE.md`, the parent spec's § Business rules and § Scopes, `ui-localization`,
  `ui-localization-rtl`, `ui-foundation-retrofit` (spec, implementation, open questions),
  `ui-design-tokens` rule 5, and `ui-component-base`.
- Read the code as it stands, including `spec-localization`'s uncommitted work:
  `toast_component.rb`/`.html.erb`, `toast_container_component.rb`/`.html.erb`, `chrome.rb`,
  `base.rb`, `button_component.rb`, `toast_controller.js`,
  `toast_container_controller.js`, `overlay/presence.js`,
  `lib/rails_ui_kit/turbo_streams.rb`, `engine.css`, `rails_ui_kit.en.yml`, the toast docs
  page and code examples, `README.md`, `UPGRADING.md`, `CHANGELOG.md`, and the toast unit
  and system tests.
- Verified in the bundled turbo-rails 2.0.23 (`app/assets/javascripts/turbo.js`):
  - `FormLinkClickObserver` builds a `<form data-turbo="true">` from a
    `data-turbo-method` link.
  - `FormSubmission#prepareRequest` adds `X-CSRF-Token` for non-GET.
  - `_method` and a named submitter override the method.
  - Link clicks are handled by a bubbling document listener.
- Found that the documented Turbo Stream recipe (`turbo_stream.append "body"`) puts a toast
  outside the container's fixed stack. It's recorded as a defect, fixed by
  `turbo_stream.ui_toast`.
- Found that the controller's enter and exit (`fadeOut`'s `setTimeout(500)`) reimplement
  Primitive D, which parent rule 4 forbids.
- Found no flash integration anywhere in the kit.
- Authored `spec.md`, `relations.md`, `open-questions.md` and this file, and added the
  § Scopes row to the parent.
- Recorded the orchestrator's 2026-09-14 rulings:
  - An action's `class` is Ruby and Turbo Stream only; JavaScript rejects it loudly.
  - The container is promoted with `popover="manual"`, verify-first. The probe is the
    first acceptance check, and the fallback is occlusion.
- Marked this scope ratified, set `conflicts_with` to empty, and trimmed
  `ui-foundation-retrofit`'s spec, `implementation.md` and `open-questions.md` of the Toast
  work this scope took over.

## In progress

None. Next: write and run `test/system/toast_top_layer_probe_test.rb`, record the result
here, and edit spec.md § Behavior item 12 to the branch that holds.

## Last green checkpoint

none — spec only. `specline_check` on the repo: 0 errors, and the same three pre-existing
warnings as before this scope was added.

## Dead ends

- `data-turbo-method` links for non-GET actions, as first directed, were replaced by a
  `button_to`-shaped form (spec.md § Behavior, item 6). The link is announced as a link,
  and with Turbo absent it degrades to a GET on a mutating URL. The payload key `method:`
  is unchanged.
- A JSON map of variant to class string for JavaScript-built actions was considered and
  rejected. It reproduces Button's attributes by hand. Templates rendered by
  `Ui::ButtonComponent` keep identity by construction.

## Corrections

- The parent's § Scopes said Toast and Confirm Dialog had been moved onto the primitives by the retrofit; neither inherits `Ui::Base` or reads tokens yet, and Toast consumes no primitive — provable — reviewer
- The Toast template's type glyph was specified as fixed by `type:`; the decider ruled that no component forces iconography, so the glyph is a default the caller replaces with an `icon` slot or removes with `icon: false` — tasteable — decider
