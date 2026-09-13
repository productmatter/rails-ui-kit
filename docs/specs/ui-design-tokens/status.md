## State

building

`ui-test-harness`, the blocker, has shipped the browser lane and is built. The
`.dark`-on-`<html>` regression check now has somewhere to run and is green:
`bundle exec rake test:system TEST=test/system/dark_mode_toggle_test.rb` — 1
run, 3 assertions, 0 failures. Every agent-loopable check for this scope is
green. Another worker is implementing this scope's 2026-09-13 token-contract
changes (kit extensions, host-wins layering, `@custom-variant dark` ownership,
Tailwind-4-only) right now, so the scope itself is mid-build, not merely
unblocked.

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
