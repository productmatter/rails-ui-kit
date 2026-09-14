## State

ready-for-review

Built. **Corrected 2026-09-14:** this read `building`, describing the 2026-09-13
token-contract changes (kit extensions, host-wins layering, `@custom-variant dark`
ownership, Tailwind-4-only) as in progress. They landed and are in the v0.3.0 CHANGELOG.
Every agent-loopable check was re-run green on 2026-09-14: the `@theme` mapping and
`@theme inline` greps, no engine `@custom-variant dark`, the install generator test
(14 runs, 0 failures) and `test/system/dark_mode_toggle_test.rb`. What remains is the
judgeable review and the two human gates, Jonathan's approval of the `oklch()` values
and the tweakcn spot-check, neither of which has a recorded sign-off.

`ui-control-sizing` added three more kit extensions under rule 5 on 2026-09-14,
`--control-height-sm`, `--control-height` and `--control-height-lg`, owned and tested
by that scope.

## Done
- Read the parent spec (`ui-component-library/spec.md`) in full, plus
  `app/assets/tailwind/rails_ui_kit/engine.css`,
  `lib/generators/rails_ui_kit/install/install_generator.rb`,
  `app/javascript/rails_ui_kit/controllers/dark_mode_controller.js`, and `README.md`,
  to ground the token contract in the actual repo surface.
- Authored `spec.md`: token names/values, the `:root`/`.dark` mechanism, the
  Tailwind v4 `@theme` exposure, the install-generator delivery path, and the
  compatibility assertion with the existing dark-mode controller.
- Built and committed the `:root`/`.dark` token blocks and the `@theme inline`
  mapping in `cdd9820`, alongside `Ui::Base` and `Ui::ButtonComponent` —
  deliberately ahead of `ui-test-harness`, as a vertical slice for review.
  Repointed `examples/app/assets/tailwind/application.css` to `@import`
  `engine.css` directly in the same commit, since it had never been on the
  token-delivery path (§ Assumptions, § Critical files).
- `4361a6f` (concurrent, same branch) added `--destructive-foreground` as this
  scope's first kit extension, formalizing Jonathan's 2026-09-13 decision (§
  Business rules, rule 5) and consumed by `Ui::ButtonComponent`'s destructive
  variant.
- Ran the agent-loopable checks against the current tree:
  - `grep -c -- "--color-background: var(--background)" app/assets/tailwind/rails_ui_kit/engine.css` → `1` (pass).
  - `grep -q "^@theme inline {" app/assets/tailwind/rails_ui_kit/engine.css` → exits 0 (pass).
  - `bundle exec rake test:system TEST=test/system/dark_mode_toggle_test.rb` → at the time, `rake aborted! Don't know how to build task 'test:system'` — the lane didn't exist yet; not a defect in this scope. Now that `ui-test-harness` has shipped the lane and written that test file (pinning the `.dark`-on-`<html>` contract per its own § Acceptance checks), the command is green: 1 run, 3 assertions, 0 failures.
- Counted the shadcn-contract names actually defined in `engine.css`: 32 (31
  color tokens + `radius`), not 33 — the old closure claim's own enumeration
  only ever listed 32 names, and separately mislabeled the sidebar group's
  seven variants as five. Corrected in § Business rules, rule 1.

## In progress
None — the `ui-test-harness` dependency has shipped and the regression check
now runs green (see § State). Nothing else queued for this scope.

## Last green checkpoint
cdd9820 (extended by 4361a6f) — full unit lane green (`bundle exec rake test`,
93 runs / 246 assertions / 0 failures) and both runnable agent-loopable checks
green, for the vertical slice (tokens, `Ui::Base`, `Ui::ButtonComponent`) built
ahead of `ui-test-harness` as a deliberate review slice.

## Dead ends
None yet.

## Corrections
- Closed "33 tokens, no more no fewer" claim was wrong on its own enumeration (32 names), and superseded regardless by Jonathan's 2026-09-13 decision making the contract two-part (shadcn names + kit extensions) — tasteable — decider
- Sidebar enumeration was labeled "five variants" but named seven — provable — implementer
- Rule implied every token, including `--radius`, carries an `oklch()` value under both `:root` and `.dark`; `--radius` is a length, defined under `:root` only — provable — implementer
- Human-gate line cited "33 tokens"; corrected to the enumerated 32 shadcn-contract names plus ratified kit extensions — provable — implementer
- `size: small` no longer fit: the spec carries 10 Behavior + Acceptance items, and the scope genuinely grew with the 2026-09-13 decisions (kit extensions, host-wins layering, `@custom-variant dark` ownership, Tailwind-4-only) rather than being padded; corrected to `size: large` — tasteable — decider
- `@theme` vs `@theme inline` was unpinned; plain `@theme` silently breaks `.dark`-scope overrides below `<html>`, so it's now pinned to `inline` with a grep check that fails on plain `@theme` — provable — implementer
- Assumed the existing `@import` chain already carried the tokens everywhere; `examples/app/assets/tailwind/application.css` was never on that chain and needed repointing in `cdd9820` — provable — implementer
- § Assumptions implied `components.css` carried tokens to Tailwind 3/Sprockets setups; it holds only modal transform classes, so the bullet is corrected and that path dropped for the token-based kit — provable — reviewer
- Kit tokens were unlayered and imported last, silently overriding a host's theme; Jonathan's 2026-09-13 decision puts them in a low-priority layer so the host always wins (rule 7) — tasteable — decider
- The engine shipped no `@custom-variant dark`, so a host's `dark:` followed the OS while the tokens followed `.dark`; Jonathan's 2026-09-13 decision has the install generator write it into the host's CSS (rule 8) — tasteable — decider
- The spec promised tokens on all three README paths; Jonathan's 2026-09-13 decision makes the token-based kit Tailwind CSS 4 only (rule 9) — tasteable — decider
- `--input` shipped at `oklch(0.915 0.005 75)` light and `oklch(0.345 0.011 75)` dark, the same value as `--border`, which put a control's boundary at 1.15–1.29:1 light and 1.13–1.65:1 dark against `--background`/`--card`/`--popover`/`--muted`/`--accent` — below the 3:1 WCAG 1.4.11 requires; retuned to `oklch(0.62 0.012 75)` light and `oklch(0.69 0.011 75)` dark, measured in the browser at 3.11–3.66:1 light, 4.63–6.79:1 dark, and 3.15–4.05:1 against the `dark:bg-input/30` fill (`--border` left as it was: decoration is exempt) — provable — implementer
- Dark `--destructive` shipped at `oklch(0.545 0.185 27)`, which is 2.37–3.48:1 as text on the dark surfaces, below the 4.5:1 text needs; lightened to `oklch(0.71 0.14 27)` with dark `--destructive-foreground` moved from `oklch(0.985 0.006 27)` to `oklch(0.2 0.02 27)`, mirroring the dark `--primary` precedent — measured 4.73–6.94:1 as text and 6.65:1 for its label (5.55:1 on `hover:bg-destructive/90`); light destructive was 5.86–6.91:1 and is unchanged — provable — implementer
- `--input` was doing two jobs: a control's boundary and, through `dark:bg-input/30`, its fill; lightening it to clear 3:1 dragged the fill with it and dropped `--muted-foreground` on a filled control to 3.47–4.47:1. `--muted-foreground` is deliberately unchanged — lightening it would weaken every muted pair in the kit to fix one control — and the fill moved to `dark:bg-muted/50` instead (`ui-presentational-components` rule 7(a)), measured back at 5.86–6.70:1. `--input` is now boundaries only — tasteable — decider
