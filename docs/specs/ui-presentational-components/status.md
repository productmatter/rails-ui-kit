## State

ready-for-review

Ratified 2026-09-13. Button shipped under this scope's name before the spec existed and
is its precedent; Card also shipped before the spec existed but was cut from scope
(§ Corrections) and is no longer part of it. Input, Label and Textarea, the batch the
three open questions gated, are built (§ Corrections): the agent-loopable checks are
green, and what remains is Jonathan's human gate — every rendered docs page in light
and dark mode, on both surfaces (§ Acceptance checks, human-gate).

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

Re-verified 2026-09-15 against `feature/ui-kit-foundation`, superseding this file's earlier "no
component in this scope has been built": `bundle exec rake test` green, the palette-literal grep
(§ Acceptance checks, agent-loopable) finds nothing outside the `ui-foundation-retrofit`
exclusion, and `bundle exec rake test TEST=test/docs_pages_test.rb` green. `bundle exec rake
test:system` (the accessibility audits) was not re-run in this pass — unverified here.

## Dead ends

None yet.

## Corrections

- Registry drift test path was guessed as test/docs_registry_test.rb; the shipped test is test/docs_pages_test.rb — provable — reviewer
- State token was written as ratified, which is not a valid State token; building — provable — reviewer
- The docs site's own chrome fails the accessibility bar rule 4 sets: `examples/app/views/layouts/docs.html.erb` still uses hardcoded palette classes (`text-neutral-400` and similar) instead of tokens, measuring 2.58:1 on the sidebar section headings and 4.34:1 on the version badge, both below 4.5:1. A whole-page `assert_accessible` can't pass while this stands, which is why browser tests scope to a component's own `#<name>-preview`/`main` rather than the full page. A fix is in progress now — provable — implementer
- Rule 4 named native `<progress>` as a mandatory semantic element; it ships as `role="progressbar"` on a `div` instead. The Progress worker proved `getComputedStyle` reports the native element's `::-webkit-progress-value`/`::-moz-progress-bar` fill and track as transparent, so the mandatory 3:1 fill-versus-track check can never be verified against them — matches shadcn/ui's own choice. Rule 4 and the Progress row now carry this as a named exception, plus a general note for any future shadow-pseudo-element-only styling — provable — implementer
- Rule 2's "border is for decoration, input is for control boundaries" was too loose: Badge's outline variant, Alert and Item's outline variant all draw an identifying edge and use `input`, and none of them is a form control. Tightened to a border-identifies-a-shape test rather than a form-control-only one — provable — implementer
- Rule 6 didn't say how a usage snippet reaches the docs page; an inline ERB snippet containing its own `%>` breaks ERB's scanner, which matches the first `%>` and cuts the snippet from the surrounding template. Three workers hit this independently; rule 6 now requires every snippet go through `examples/app/helpers/code_examples_helper.rb` — provable — implementer
- Sixteen components were dropped from scope after being built, cut against the parent spec's rule 0 (admission gate): Native Select, Input Group, Badge, Alert, Avatar, Separator, Skeleton, Spinner, Progress, Table, Breadcrumb, Pagination, Button Group, Empty, Item and Card — none owned a Rails/Turbo concept or a genuinely hard browser behaviour; they were built only because they're in shadcn's catalogue, which is not a reason (ui-component-library § Business rules, rule 0; decided 2026-09-13, Jonathan Simmons). Removed everywhere: components, tests, docs pages, the registry, the CHANGELOG's Unreleased section, README's component table, and this spec's § Behavior table, § Business rules (the compound-component rule and every cut-component example), § Critical files and § Acceptance checks. Card was this spec's compound precedent; with it gone, the scope's surviving components (Input, Label, Textarea, plus Button) are all single-element, so the compound-component rule and its tests were removed rather than kept unused. Component counts: eighteen § Behavior rows → three; the parent spec's twenty → four. None of the sixteen had shipped on `main`, so nothing downstream depended on them — judgeable — decider
- Kbd and Aspect Ratio were dropped from scope after being built: both fail the bar of owning a Rails/Turbo concept or being hard to get right in a browser (Kbd is a `<kbd>` with two classes, Aspect Ratio is one class) — they were built only because they're in shadcn's catalogue, which is not a reason. Removed everywhere: components, tests, docs pages, the registry, the CHANGELOG's Unreleased section, and this spec's § Behavior table and component counts (twenty → eighteen presentational components; the parent spec's 22 → 20). Neither had shipped, so nothing downstream depended on them — judgeable — decider
- This file's `State` and `Last green checkpoint` still read "not started" / "no component in this scope has been built" after Input, Label, Textarea and the cut-and-kept Button had already landed (`f4d4170`, `c38167f`, `5f8cd2f`, all 2026-09-13) — contradicted by the two entries directly above this one, which record the same build. Corrected to `ready-for-review`, matching the parent table once that was also fixed (§ Corrections was already current; the summary fields at the top of this file were not) — provable — implementer
