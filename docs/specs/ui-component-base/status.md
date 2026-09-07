## State

building

Spec is ratified and the build has not started. The one precondition is the token
layer, which `ui-design-tokens` owns and ships first (`relations.md` carries the
edge): the proof-of-caller-wins test component's variant table names token-backed
utilities that only compile once that layer exists, so this build starts once it
ships.

## Done

- Read the parent spec (`docs/specs/ui-component-library/spec.md`) in full.
- Verified `class_variants` resolves at 1.1.1 and `tailwind_merge` resolves at
  1.5.5 on rubygems — matching the versions the parent's Assumptions section
  already pins. No contradiction found.
- Confirmed both gems' actual READMEs against the directive's assumed API:
  `ClassVariants.build(base:, variants:, compound_variants:, defaults:)` ->
  `.render(**values)`, and `TailwindMerge::Merger.new.merge(...)` with the
  later-merged string winning on conflicting utilities. Matches exactly.
- Read `rails_ui_kit.gemspec` and the three existing overlay components
  (`dropdown_component.rb`, `popover_component.rb`, `tooltip_component.rb`) that
  already use `renders_one` slots, to ground the slots-are-content-only
  assumption and the attribute-forwarding convention in real code.
- Wrote `spec.md`, `relations.md`, `open-questions.md`.

## In progress

None — this scope's authoring pass is complete pending the orchestrator's final
validator run and review.

## Last green checkpoint

none — authoring-only pass; no implementation loop has started against this spec
yet, so there is no test-green checkpoint to record.

## Dead ends

None yet — no dead ends recorded.

## Corrections

None yet — no corrections recorded.
