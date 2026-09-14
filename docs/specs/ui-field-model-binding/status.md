## State

blocked: awaiting ratification. The spec is a draft with no open questions left. It still needs the approving merge. Prerequisite 1 (Select's `aria-required`) has landed under ui-select.

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

## In progress

None.

## Last green checkpoint

none — no code has changed; spec only.

## Dead ends

- Raising when `model:` and `name:`/`errors:` are both given — it forces nested-attribute, `belongs_to` and conditional-validator callers back to the name form, losing every other derivation; explicit-wins was chosen and then ruled (spec § Behavior, item 2).
- Passing the record to `field_id` for the control id — returns `blog_post_title` where `form_with` emits `post_title` for an engine-isolated model; derivation goes through `param_key`.
- A CSS `::after` asterisk for the required marker — generated content enters accessible-name computation, so the label could be read as "Email star"; the marker is an `aria-hidden` span.

## Corrections

None yet.
