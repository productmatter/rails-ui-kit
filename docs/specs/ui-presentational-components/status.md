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
- The docs site's own chrome fails the accessibility bar rule 4 sets: `examples/app/views/layouts/docs.html.erb` still uses hardcoded palette classes (`text-neutral-400` and similar) instead of tokens, measuring 2.58:1 on the sidebar section headings and 4.34:1 on the version badge, both below 4.5:1. A whole-page `assert_accessible` can't pass while this stands, which is why browser tests scope to a component's own `#<name>-preview`/`main` rather than the full page. A fix is in progress now — provable — implementer
- Rule 4 named native `<progress>` as a mandatory semantic element; it ships as `role="progressbar"` on a `div` instead. The Progress worker proved `getComputedStyle` reports the native element's `::-webkit-progress-value`/`::-moz-progress-bar` fill and track as transparent, so the mandatory 3:1 fill-versus-track check can never be verified against them — matches shadcn/ui's own choice. Rule 4 and the Progress row now carry this as a named exception, plus a general note for any future shadow-pseudo-element-only styling — provable — implementer
- Rule 2's "border is for decoration, input is for control boundaries" was too loose: Badge's outline variant, Alert and Item's outline variant all draw an identifying edge and use `input`, and none of them is a form control. Tightened to a border-identifies-a-shape test rather than a form-control-only one — provable — implementer
- Rule 6 didn't say how a usage snippet reaches the docs page; an inline ERB snippet containing its own `%>` breaks ERB's scanner, which matches the first `%>` and cuts the snippet from the surrounding template. Three workers hit this independently; rule 6 now requires every snippet go through `examples/app/helpers/code_examples_helper.rb` — provable — implementer
- Kbd and Aspect Ratio were dropped from scope after being built: both fail the bar of owning a Rails/Turbo concept or being hard to get right in a browser (Kbd is a `<kbd>` with two classes, Aspect Ratio is one class) — they were built only because they're in shadcn's catalogue, which is not a reason. Removed everywhere: components, tests, docs pages, the registry, the CHANGELOG's Unreleased section, and this spec's § Behavior table and component counts (twenty → eighteen presentational components; the parent spec's 22 → 20). Neither had shipped, so nothing downstream depended on them — judgeable — decider
