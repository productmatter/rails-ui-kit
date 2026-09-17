## State

ready-for-review

Built and verified 2026-09-14. Every agent-loopable check in § Acceptance checks passes
exactly as written. What remains is the judgeable review of the token surface and
Jonathan's human gate: the side-by-side docs comparison and a mixed row at each size,
at the kit's tokens and at a denser host value.

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

Step 1 of the build is done: `test/system/control_sizing_test.rb` (CS1 and CS2) measures
every control's box at its defaults and passes against the unmodified components, at
Tailwind's own spacing unit and with `--spacing` retuned on `:root`. It was also proved
to fail: moving Input from `h-9` to `h-10` failed both cases, naming the metric and both
spacing units. The Button docs page's sizes row gained an `id` so the test can scope to
it; no component was touched.

Step 2 is done. The three tokens are in `engine.css`, under `:root` only. Button's sizes
moved onto them, and Input, Textarea and Select (including search mode's show-options
button) gained `size:`. CS1 and CS2 stayed green without a single expectation edited. New:

- CS3–CS5 in the same browser file cover alignment, popup width at every step, and a
  token override on `:root` and on one wrapper.
- `test/components/ui/control_size_test.rb` holds the shared unit contract.
- The mixed row they measure is `#control-sizes-preview` on the Field docs page.

Proofs of failure: CS3 and CS5 failed before any component changed. `control_size_test.rb`
failed 19 of 20 against the original components. The one that passed, caller-wins, is a
preservation guard. Swapping Input's token for the named key `h-control` failed it with
`["h-control", "h-12"]`, the exact failure mode rule 4 exists for. CS4 (popup width) passed
before the change too: the anchor already matched width, and the check guards that at the
new steps.

Parent rule 1 now names control height, and `ui-design-tokens` is corrected to
`ready-for-review` in its status.md and the parent's § Scopes row.

Step 3 is done. CS6 measures WCAG 2.5.8's 24px floor directly, since axe won't. It covers
every control at `sm`, an icon-only `sm` Button (added to the Field page's mixed row) and
the `icon` Button, at the kit's own token values, with no clamp. Proved able to fail in
both dimensions: `--control-height-sm` set to 20px failed on height ("the button is 20px
in height"), and an icon-only `sm` Button narrowed failed on width ("22px in width").

Step 4 is done. Input, Textarea and Select show `size: :sm` and `size: :lg` inside their
existing previews, so the axe and contrast checks already there cover them. All four
component pages document `size:` in their Options table. README's Overriding section
documents the three tokens and says plainly that a control height under 24px breaks
WCAG 2.5.8. The CHANGELOG entry is in the existing `## [0.3.0]` section.

Nothing is in progress.

## Last green checkpoint

Step 3 and 4 on `a3bd7bb` (uncommitted). `bundle exec rubocop`: 109 files, no offenses.
`bundle exec rake test`: 367 runs, 1107 assertions, 0 failures. Browser lane, one file at
a time with `pgrep -x chromedriver` checked before each: 52 files, 326 runs, 2592
assertions. 51 were green on the first pass. `slow_lane_test.rb` SL1 failed once, a fetch
of the Installation page measured at 268ms against its 250ms bound, on a machine at load
average 22–36 with other workers running. Neither the page nor its request path is touched
by this scope. Re-run alone three times, it was green 3 of 3. The four § Acceptance checks,
run verbatim: `/unchanged/` 2 runs, `/align/` 3 runs, `/target/` 1 run, and the literal
guard plus `control_size_test.rb` 20 runs, all 0 failures. CS1 and CS2 are unedited since
`a3bd7bb`: the diff of the test file has no removed lines.

## Dead ends

- Named theme keys (`--spacing-control` in `@theme inline`, giving `h-control`) compile
  cleanly in Tailwind 4.3.1 but break the caller-wins merge (§ Business rules, rule 4).
  Don't revisit without re-checking `tailwind_merge`.

## Corrections

- Step 2 was reported green without running rubocop. `Ui::SelectComponent` had gone from 148 to 161 lines, over `Metrics/ClassLength`'s 150. No limit was raised and nothing was disabled. The per-mode primitive values (`root_data`, `popup_data`, `navigation_data`, `combobox_actions`, `PAGE_STEP`) moved into `Ui::Select::Primitives`: how Select's two modes configure the five primitives, a job that needs only `search:` and `native_on_touch:`. The moved lines were checked against HEAD and none changed. Select is now 124/150 and `Primitives` 46. Every report now includes rubocop — provable — reviewer

- § Critical files said this scope would extend `select_enhancement_test.rb`'s SE2 and SE3 to every step. The same measurements live in `control_sizing_test.rb` (CS3, CS4) against the Field page's mixed row instead, which covers every control at once — provable — implementer
- Before this scope, `size: :sm` on Input, Textarea or Select didn't fail. `Ui::Base` forwarded it as an HTML `size="sm"` attribute, a real attribute on `<input>` and `<select>`, so it sized nothing. The keyword is now consumed, and a unit test asserts no `size` attribute renders — provable — implementer
- Three existing caller-wins assertions checked that `h-9` or `h-10` was absent (`button_component_test.rb`, `field_component_test.rb`, `select_component_test.rb`). Once the literals were gone they would have passed vacuously, so they now assert that the token class is absent. Button's `SIZE_MARKERS` moved to the token classes the same way. These are class-name markers. The rendered metrics are CS1 and CS2, which were not edited — provable — implementer
