## State

building

Ratified 2026-09-13 and not started. The component can't start until the four primitive
prerequisites in `spec.md` § Assumptions land: overlay open-without-focus, overlay
respecting `aria-controls`, roving-focus page keys, and a Field label id. Two open
questions are recorded, both with defaults, deadline 2026-09-21. Neither blocks the
first unit.

## Done

- Shaped from the orchestrator's directive (2026-09-13) against the live repository:
  `overlay_controller.js`, `roving_focus_controller.js`, `anchor_controller.js`,
  `dropdown_controller.js`, `dropdown_component.rb`, `field_component.rb` and
  `field/`, `native_select_component.rb`, the positioning and overlay specs, and the
  2026-09-13 component audit.
- Verified both APG key tables against the w3.org pages' HTML on 2026-09-13: the
  select-only combobox example, and the editable combobox with list autocomplete.
- Authored `spec.md`, `relations.md`, `open-questions.md` and this `status.md`, and added
  the § Scopes row to ui-component-library.

## In progress

None. Suggested first unit: the four primitive prerequisites, each with its own system
test. Then the option normaliser and native-select parity
(`test/components/ui/select_component_test.rb`), which needs no JavaScript and fixes
the API before any controller exists.

## Last green checkpoint

none — build has not started; no component, controller or test exists yet

## Dead ends

None yet.

## Corrections
