## State

building

Ratified 2026-09-13 and not started. Button and Card shipped under this scope's name
before the spec existed and are its precedents. Three open questions gate the first
batch. Input-first build order and the `--input` and dark `--destructive` contrast
fixes each have a default, so work can start on the defaults.

## Done

- Derived the conventions from `app/components/ui/base.rb`, Button, Card and its parts,
  their unit and browser tests, `engine.css`, the `ui-component-base` and
  `ui-design-tokens` specs, and `docs/audits/2026-09-13-component-audit.md`.
- Measured token contrast from `engine.css` values (oklch → sRGB → WCAG ratio):
  `--input` on `--background`/`--card` is 1.27/1.29:1 light and 1.64/1.52:1 dark; dark
  `--destructive` text is 3.49:1 on `--background` and 3.22:1 on `--card`; light
  `--destructive` text is 6.82:1; `--muted-foreground` on `--muted` is 4.69:1 light and
  5.87:1 dark.
- Dry-ran the palette-literal check against today's tree: it passes, and it fails on a
  seeded `bg-white`.
- Authored `spec.md`, `relations.md`, `open-questions.md` and this file.

## In progress

None. Both shared pieces the batches need have landed: the docs registry in `aa0fd24`
as `DocsPages::PAGES` with its drift test in `test/docs_pages_test.rb`, and the
colour-probe helper, moved out of `test/system/button_test.rb` into
`test/application_system_test_case.rb` as `color_of`, `contrast_ratio`,
`each_token_surface`, `disable_transitions`, `focus_visibly`, `outline_of` and
`assert_focus_outline_in_forced_colors` (§ Business rules, rule 5). Card's docs page and
browser test moved to the rule 6 `id="card-preview"` convention at the same time, and the
`--input` and dark `--destructive` retune those rules depend on is in `engine.css`,
with rule 7(a)'s dark fill moved off `--input` onto `dark:bg-muted/50`.

## Last green checkpoint

none — no component in this scope has been built

## Dead ends

None yet.

## Corrections

- Registry drift test path was guessed as test/docs_registry_test.rb; the shipped test is test/docs_pages_test.rb — provable — reviewer
- State token was written as ratified, which is not a valid State token; building — provable — reviewer
