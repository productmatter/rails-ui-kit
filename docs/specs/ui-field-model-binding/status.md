## State

building. Ratified by the orchestrator on 2026-09-14. The help-text swap (§ Behavior, items 19–23) was added on the orchestrator's directive, relaying the decider, before the build began. Prerequisite 1 (Select's `aria-required`) landed under ui-select in `bb7e7b8`.

## Done

- Shaped from the orchestrator's directive (2026-09-14) against the live repository: `field_component.rb` and `field/`, `field_component_test.rb`, `test/support/test_order.rb`, `select_component.rb`, `docs_controller.rb#select_submit`, `_select_round_trip.html.erb`, the `select_form_submission`, `select_validation` and `select_no_javascript` system tests, `demo_order.rb`, and `install_generator.rb`.
- Verified Rails behaviour in this repository's bundle (rails 8.1.3.1, view_component 4.15.0) by rendering real helpers in a scratch script outside the repo. Every result is recorded in spec § Assumptions. Two findings went against the obvious guess:
  - `field_id(record, attr)` uses `model_name.singular`, so it disagrees with `form_with` for an engine-isolated model;
  - `helpers.label.<param_key>.<attr>` outranks `human_attribute_name` in `form.label`.
- Found that Select's combobox has no `aria-required` (prerequisite 1), and that Primitive E's install-generator `field_error_proc` step never shipped.
- Authored `spec.md`, `relations.md`, `open-questions.md` and this file, and added the § Scopes row to ui-component-library.
- Recorded the orchestrator's rulings of 2026-09-14:
  - value filling is decided as specified (§ Behavior, item 16; `open-questions.md`);
  - explicit wins over derived, with no raise (§ Behavior, item 2);
  - `field_error_proc` in host apps is deferred with the form builder as a Rails primitive override (§ Out of scope / deferred).
- Applied the matching corrections elsewhere:
  - `ui-select` § Behavior, item 14, plus its Non-goals and Out of scope bullets that restated it, no longer plan `form.ui_select`;
  - `ui-positioning-and-navigation` Primitive E, its Critical files, its judgeable check and § Out of scope / deferred now record the generator step as never built and deferred, and its human gate for that step is removed, with a Corrections entry in its `status.md`.
- Ratified by the orchestrator, 2026-09-14.
- Specified the help-text swap (§ Behavior, items 19–23, and the amendment to § Business rules, rule 1). Before designing it, checked where a swap can be seen, in headless Chrome against the examples app with Turbo 8.0.23:
  - the Select round trip's `422` is a frame render: only `turbo:before-frame-render` fires, the field is a new node and the old one is disconnected;
  - a `method="morph"` stream keeps the node;
  - a controller can cancel `turbo:before-morph-attribute` for `hidden` and `turbo:before-morph-element` for a removal, and `turbo:morph-element` for the wrapper fires after its children.

  Drive's `422` and morphing-refresh paths were read in `turbo.js`, not driven.

## In progress

None. Every agent-loopable check in § Acceptance checks passes as written (2026-09-14). What remains is the judgeable review and Jonathan's three human gates: VoiceOver on the required preview, the marker's glyph, colour and placement, and VoiceOver on the swap demo.

## Last green checkpoint

2026-09-14, uncommitted, handed to the orchestrator in four pieces (spec, model binding, swap, docs). Unit lane: 431 runs, 0 failures. `bundle exec rubocop`: no offenses. Browser files run one at a time, each with `SLOW=1`: `field_swap_test` (9), `field_test` (6), `select_form_submission` (4), `select_validation` (4), `select_no_javascript` (5), `select_accessibility` (8), `select_enhancement` (11), `select_turbo_stream` (4), `control_sizing` (6) and `docs_chrome` (8), all green. Every new unit and browser test was shown to fail against a targeted mutation of the code it covers.

## Dead ends

- Raising when `model:` and `name:`/`errors:` are both given — it forces nested-attribute, `belongs_to` and conditional-validator callers back to the name form, losing every other derivation; explicit-wins was chosen and then ruled (spec § Behavior, item 2).
- Passing the record to `field_id` for the control id — returns `blog_post_title` where `form_with` emits `post_title` for an engine-isolated model; derivation goes through `param_key`.
- A CSS `::after` asterisk for the required marker — generated content enters accessible-name computation, so the label could be read as "Email star"; the marker is an `aria-hidden` span.
- Animating the swap with a `ui--presence` controller on each part, driven by its `open` value. Rendered open, `ui--presence` enters on connect, so the swap would animate on every page load. A morph resets `hidden` and `data-state` before the value callback runs. The error's removal can't be held by a value at all. And two independent controllers would cross-fade with both parts laid out, so the field would jump twice. One `ui--field` controller composing the presence module by import avoids all four (spec § Behavior, item 22).
- Animating on connect after a frame render. A new node has no previous state to animate from, and telling a frame render apart from a Drive render is a heuristic that would animate page navigations (spec § Out of scope / deferred).

## Corrections

- 2026-09-14, at build: § Assumptions said `DemoTrip` could require `active_model` itself. Autoloaded during a request, that loads ActiveModel's translations too late, and SN4 rendered "Translation missing". The docs app now requires `active_model/railtie` (still no ActiveRecord). The assumption is corrected in place.
- 2026-09-14, at build: § Assumptions said the gemspec allows Rails ≥ 7.0. `81e2cf9` raised the floor to 7.2 on this branch; corrected.
- 2026-09-14, at build: the acceptance check `! grep -rn "ActiveRecord\|active_record"` over the Field files could never have passed: a v0.3.0 comment in `field_component.rb` said "nothing here depends on ActiveRecord". The comment now says "an ORM", with the same meaning.
- 2026-09-14, at build: `ErrorComponent`'s comment and the Field docs page recommended passing `role: "alert"` to a field's error "through attribute forwarding" and "through the control's forwarded attributes". Neither path exists, and the second would make the input an alert. Both now point at the morph path (§ Behavior, item 23).
