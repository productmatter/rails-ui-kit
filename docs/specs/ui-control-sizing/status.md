## State

draft

Shaped 2026-09-14 and not ratified. Nothing is built. Two open questions carry
defaults, so a build could start on those defaults once the scope is ratified.

## Done

- Shaped the scope from the orchestrator's directive against the live repository:
  `button_component.rb`, `input_component.rb`, `textarea_component.rb`,
  `select_component.rb` and its template, `listbox_component.rb`, `anchor_controller.js`,
  `engine.css`, `test/system/button_test.rb`, `test/system/select_enhancement_test.rb` and
  `assert_accessible` in `test/application_system_test_case.rb`.
- Verified in the repository's bundle (2026-09-14) that `tailwind_merge` 1.5.5 merges
  the arbitrary-value classes `h-(--x)`, `size-(--x)` and `min-h-[calc(…)]` against a
  caller's plain utility, and doesn't merge the named key `h-control` against `h-12`.
  That is the basis for § Business rules, rule 4.
- Verified with `tailwindcss-ruby` 4.3.1, compiling a scratch stylesheet outside the
  repository, that `h-(--control-height)` and the `min-h-[calc(…)]` form compile, and
  that `--spacing` is emitted on `:root`.
- Found that no existing browser test measures a control's height or hit target.
  SE2 and SE3 measure Select geometry and BTN6 measures icon glyph size. And
  axe-core 4.13's `target-size` rule ships disabled, so `assert_accessible` doesn't
  cover WCAG 2.5.8 (§ Business rules, rule 5).
- Found a second height literal the directive didn't list: search mode's
  show-options button hardcodes `h-9` in `select_component.html.erb`.
- Authored `spec.md`, `relations.md`, `open-questions.md` and this file, and added the
  § Scopes row to ui-component-library.

## In progress

None. Waiting for ratification.

The first build step, once ratified, is the § Acceptance checks "unchanged" test
written and passing against unmodified v0.3.0 components, before any component
changes (§ Business rules, rule 3).

## Last green checkpoint

None. Nothing built.

## Dead ends

- Named theme keys (`--spacing-control` in `@theme inline`, giving `h-control`) compile
  cleanly in Tailwind 4.3.1 but break the caller-wins merge (§ Business rules, rule 4).
  Don't revisit without re-checking `tailwind_merge`.

## Corrections

None yet.
