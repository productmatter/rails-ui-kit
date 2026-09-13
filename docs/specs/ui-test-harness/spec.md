---
slug: ui-test-harness
type: chore
status: building
decider: Jonathan Simmons
blast_radius: medium
size: small
target_model: standard
created: 2026-09-07
stale_after: 2026-10-13
loop_budget: 5
---

## Intent

Three ratified Phase A scopes have already written acceptance checks that run in a
browser, and the browser lane they run in does not exist. `ui-design-tokens` § Acceptance
checks pins the `.dark`-on-`<html>` contract with `test/system/dark_mode_toggle_test.rb`.
`ui-presence-and-overlay-stack` asserts focus return, Escape ordering across nested
overlays and reference-counted scroll lock — none of which can be observed without a real
top layer and real focus. `ui-positioning-and-navigation` asserts roving tabindex,
`aria-activedescendant` and anchor repositioning on scroll, same constraint. Meanwhile
`ui-component-library` § Business rules, rule 6 makes keyboard operation and correct ARIA
definition-of-done rather than a later pass, which is a promise nothing in this repository
can currently check.

The repository's actual state: `test/` holds `components/`, `generators/`,
`tailwind_engine_css_test.rb` and `test_helper.rb`. There is no `test/system/` and no
system-test base class. `test_helper.rb` requires the `examples/` app's environment,
`minitest/autorun` and ViewComponent's test helpers, and mentions Capybara nowhere —
though `capybara` and `selenium-webdriver` are both already in the `Gemfile`'s test group,
unused. And the `Rakefile`'s single test task globs `test/**/*_test.rb`, so the first file
written under `test/system/` silently joins the lane CI runs across four Ruby versions
(3.2, 3.3, 3.4, 4.0 — 3.1 is dropped, since `tailwind_merge` requires 3.2), giving every
PR four headless-Chrome installs and four chances to flake.

This scope exists because that is real, unbudgeted work with its own failure modes, and
because two independent scopes reached for it and neither should own it. It is a chore in
the literal sense: nothing a consumer of the gem can see changes.

## Goal

A browser test can be written, run in isolation, and run in CI — with an accessibility
assertion available to it — without the default `rake test` lane acquiring a browser
dependency, established when a smoke test drives the `examples/` app in headless Chrome
and `bundle exec ruby -Itest -e 'require "test_helper"'` still loads no Capybara.

## Non-goals

- Not writing any sibling scope's tests. This scope ships the lane and one smoke test
  proving it works; `test/system/dark_mode_toggle_test.rb`,
  `ui_overlay_nesting_test.rb`, `roving_focus_menu_test.rb` and their kin are written by
  the scopes that named them.
- Not restructuring the existing unit suite. The 9 component tests, the generator tests
  and `tailwind_engine_css_test.rb` keep running exactly as they do now, on the same
  command.
- Not rebuilding `examples/`. It is already a working dummy host; this scope drives it,
  it does not restructure it (§ Non-goals of ui-component-library).
- Not choosing a second test framework. RSpec is not added, and no gem is adopted that
  requires it.
- Not a general CI overhaul. The workflow gains one job and the existing matrix job keeps
  its shape; nothing else in `.github/workflows/ci.yml` is touched.
- Not visual-regression or screenshot-diffing infrastructure.

## Behavior

A new `test/system/` directory holds browser tests, and a new base class —
`ApplicationSystemTestCase`, in its own file under `test/` — is what they inherit from. That
file, not `test/test_helper.rb`, is where every browser dependency is required. This
split is the whole point of the arrangement: `test_helper.rb` stays a unit-suite entry
point that loads the `examples/` environment, `minitest/autorun` and ViewComponent's test
helpers and nothing else, so a developer who adds a system test cannot accidentally make
the unit suite depend on Chrome. The base class requires `test_helper` first, then the
Rails system-testing and Capybara pieces on top of it.

The driver is Selenium against headless Chrome, registered with the flags a CI container
needs (`--headless=new`, `--no-sandbox`, `--disable-dev-shm-usage`) and a fixed window
size so a test that depends on viewport geometry — anchored positioning collision and flip
behavior, in particular — is deterministic rather than dependent on the runner's default.
The app under test is `examples/`; Capybara's server is the one Rails' system-testing
integration already starts, so no bespoke server plumbing is written.

The `Rakefile` splits into two lanes. The existing `test` task's pattern narrows so it
excludes everything under `test/system/`, keeping the unit lane's file list exactly what
it is today, and a new `test:system` task globs `test/system/**/*_test.rb`. `default`
stays pointed at the unit lane. `.github/workflows/ci.yml` gains a second job: the
existing matrix job keeps running `bundle exec rake test` across all four Rubies, and the
new job runs `bundle exec rake test:system` once, on a single stable Ruby, on a runner
with Chrome available. Fast signal stays on every Ruby; the browser cost is paid once.

Accessibility assertion is part of the harness, not a later addition. `axe-core-capybara`
and `axe-core-api` (both 4.13.0 at authoring time; both resolve on rubygems) join the
`Gemfile`'s test group, and the base class exposes an `assert_accessible`-shaped helper
that runs an axe audit against the current Capybara page and fails with axe's own
violation report rather than a bare boolean. `axe-core-capybara` supplies the
Capybara-session bridge and `axe-core-api` supplies the audit and its failure message;
neither needs RSpec. The helper lives on the system-test base class, not in
`test/test_helper.rb`, because requiring it there would pull Capybara into the unit lane
and undo the separation above — see § Assumptions.

## Business rules

1. `test/test_helper.rb` never requires Capybara, Selenium, `axe-core-*`, or anything
   that transitively requires them. The unit lane runs on a machine with no browser
   installed.
2. The default `rake test` task's file list contains no path under `test/system/`, and
   `default` points at that task. A browser test reaches CI only through the separate
   `test:system` task.
3. System tests run in CI on exactly one Ruby; unit tests run on all four in the existing
   matrix. Neither lane is dropped — running system tests only locally is not an option,
   because it would make § Business rules, rule 6 of ui-component-library unenforceable.
4. The accessibility assertion stack is `axe-core-capybara` + `axe-core-api`, asserted
   directly from Minitest. `axe-core-rspec` is not used and RSpec is not added — this
   repository has one test framework and keeps one (§ Business rules of
   ui-component-library, rule 8, adopt over build, applied to the test stack).
5. Every sibling scope consumes this lane by inheriting the base class and writing a test.
   No sibling registers its own driver, starts its own server, or writes its own axe
   wiring (§ Business rules of ui-component-library, rule 4, restated for test
   infrastructure).
6. The harness ships with at least one accessibility assertion actually exercised, not
   merely available. A helper nobody has run is not a delivered capability (§ Business
   rules of ui-component-library, rule 6).

## Assumptions

- `capybara` and `selenium-webdriver` are already in the `Gemfile`'s test group and are
  currently unused. This scope activates them rather than adding them; no new browser
  dependency is introduced, only wired.
- `axe-core-capybara` and `axe-core-api` both publish at 4.13.0 and are Minitest-agnostic —
  verified against rubygems at authoring time. This **corrects** § Assumptions of
  ui-component-library, which names `axe-core-rspec`: that gem ships RSpec matchers only
  and is unusable in a repository whose `test/test_helper.rb` requires
  `minitest/autorun` and which contains no RSpec anywhere. The parent's assumption is
  amended by this scope rather than worked around.
- `examples/` is a complete Rails app with its own `bin/rails` and `config/environment`,
  already loaded by `test/test_helper.rb`. It is the dummy host, and it already renders a
  docs page per component — so a smoke test has a real page to drive on day one.
- Chrome is available on `ubuntu-latest` GitHub runners. If that stops being true, the
  system job installs it explicitly; it does not become a reason to fold the lanes back
  together.
- `ui-positioning-and-navigation` and `ui-presence-and-overlay-stack` originally
  proposed requiring the a11y helper from `test/test_helper.rb`. That placement is
  incompatible with rule 1 above — it would drag Capybara into the unit lane across all
  four Rubies — so the helper lives on the system-test base class and nowhere else.
  Those scopes now consume this lane rather than proposing their own placement; the
  substance they were reaching for (which axe gems) is unchanged and settled here as
  `axe-core-capybara` + `axe-core-api`.
- This scope establishes two invocations for the whole repository: `bundle exec rake
  test TEST=…` for the unit lane and `bundle exec rake test:system TEST=…` for the
  browser lane. The sibling scopes originally wrote three different commands
  (`bin/rails test …`, `bin/test TEST=…`, `bundle exec rake test TEST=…`) against a
  `bin/rails` this repository does not have at its root; their acceptance checks have
  since been reconciled onto these two in their own specs, not here. A future scope
  that writes a browser check names `bundle exec rake test:system`, and a system test
  file sits flat at `test/system/<name>_test.rb`.

## Critical files

- `test/test_helper.rb` — the unit-lane entry point; gains nothing, and must keep
  mentioning no browser.
- `test/application_system_test_case.rb` (new) — the Capybara base class, the headless
  Chrome driver registration, and the `assert_accessible` helper.
- `test/system/` (new) — the browser-test lane and its smoke test.
- `Rakefile` — the single `test/**/*_test.rb` glob that currently sweeps system tests into
  the default run; splits into the unit and `test:system` lanes here.
- `.github/workflows/ci.yml` — the four-Ruby matrix; gains the single-Ruby system job.
- `Gemfile` — `capybara` and `selenium-webdriver` already present in the test group;
  gains `axe-core-capybara` and `axe-core-api`.
- `bin/test` — currently `exec bundle exec rake test`; the shorthand whose meaning the
  lane split changes.
- `examples/` — the dummy host the system tests drive.

## Acceptance checks

### agent-loopable

- A system test inheriting the new base class boots headless Chrome, drives a real rendered `examples/` page and passes — run: `bundle exec rake test:system TEST=test/system/harness_smoke_test.rb`
- The unit lane stays browserless: loading `test/test_helper.rb` defines no Capybara — run: `bundle exec ruby -Itest -e 'require "test_helper"; abort("browser dependency leaked into the unit lane") if defined?(Capybara)'`
- The two lanes are separate tasks and the default lane no longer globs `test/system/` — run: `bundle exec rake -T | grep -q "rake test:system" && ! grep -q "test/\*\*/\*_test.rb" Rakefile`
- `assert_accessible` runs a real axe audit and fails with axe's violation report on a page seeded with a known violation — run: `bundle exec rake test:system TEST=test/system/accessibility_assertion_test.rb`

### judgeable

- The lane is consumable unchanged by the browser checks three siblings have already written — the `test/system/dark_mode_toggle_test.rb` check in § Acceptance checks of ui-design-tokens, and the focus-return, Escape-ordering, scroll-lock, roving-focus and anchor-reposition checks in § Acceptance checks of ui-presence-and-overlay-stack and ui-positioning-and-navigation — with each of those scopes writing only a test file, no harness plumbing of its own, per § Business rules of ui-component-library, rule 4.

### human-gate

- Jonathan approves the CI shape before it lands — unit tests on all four Rubies, system tests once on one stable Ruby with Chrome — since it changes what every pull request runs and is the reason this scope exists separately at all.

## Out of scope / deferred

- The sibling scopes' own browser tests — written by `ui-design-tokens`,
  `ui-presence-and-overlay-stack`, `ui-positioning-and-navigation` and
  `ui-foundation-retrofit` against this lane.
- Reconciling those scopes' existing acceptance-check commands onto
  `bundle exec rake test:system` — a correction in each of them; see § Assumptions.
- Visual-regression / screenshot diffing — no scope needs it, and the human-gate visual
  reviews in `ui-foundation-retrofit` are deliberately human, not automated.
- Cross-browser system runs (Firefox, Safari). One headless Chrome is the lane;
  `ui-presence-and-overlay-stack`'s `popover`-unsupported fallback is exercised at its own
  human-gate, in a real non-supporting browser, not here.
- Parallel or sharded system-test execution — premature at one smoke test.
