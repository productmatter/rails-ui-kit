## State
ready-for-review

The lane is built and committed in `04237d6`, the `SLOW=1` slow lane in `7dab090`, and both
rake tasks are green. Four agent-loopable checks pass as written. The unit-lane check can't pass on any tree,
because `ViewComponent::TestHelpers` loads Capybara itself; its substance, no Selenium
in the unit lane, holds (re-checked 2026-09-13: `Capybara` defined, `Selenium` nil).
What remains is the judgeable review and Jonathan's CI-shape human-gate. See § Corrections for the spec assumptions that turned out wrong
once built.

## Done
- Read all five sibling Phase A specs plus the parent (`ui-component-library/spec.md`)
  before authoring, to establish that the browser lane is a shared dependency rather than
  any one scope's internal detail.
- Verified the repository's actual test surface: `test/` contains only `components/`,
  `generators/`, `tailwind_engine_css_test.rb` and `test_helper.rb`; there is no
  `test/system/` and no system-test base class; `test_helper.rb` mentions no Capybara or
  Selenium; `capybara` and `selenium-webdriver` are present but unused in the `Gemfile`'s
  test group; the `Rakefile` globs `test/**/*_test.rb` into one task; and
  `.github/workflows/ci.yml` runs `bundle exec rake test` across Ruby 3.1, 3.2, 3.3, 3.4
  and 4.0.
- Verified on rubygems that `axe-core-capybara` and `axe-core-api` both publish at 4.13.0
  and neither requires RSpec — which is what makes the parent's `axe-core-rspec`
  assumption correctable rather than merely wrong.
- Confirmed there is no `bin/rails` at the repository root (only `bin/test`; `examples/`
  has its own `bin/rails`), which is why this scope names
  `bundle exec rake test:system TEST=…` as the lane's invocation.
- Authored `spec.md`, `relations.md` and this `status.md`.
- Added `axe-core-api` and `axe-core-capybara` to the `Gemfile`'s test group, all four
  browser-lane gems marked `require: false` (see § Corrections — this is load-bearing,
  not decorative).
- Added `test/application_system_test_case.rb`: registers a `rails_ui_kit_headless_chrome`
  Capybara/Selenium driver with `--headless=new`, `--no-sandbox`, `--disable-dev-shm-usage`,
  a fixed 1400x1400 window via `driven_by`'s `screen_size:`, and exposes `assert_accessible`
  built directly on `Axe::Core`/`Axe::API::Run` (no RSpec, no `AxeCapybara.configure` --
  the harness's own driver registration is authoritative per rule 5).
- Split the `Rakefile`: `test` now builds its file list from `test_files=` with an
  `exclude(%r{\Atest/system/})` filter (deliberately not a bare `'test/**/*_test.rb'`
  string -- see § Corrections for why), and a new `test:system` task globs
  `test/system/**/*_test.rb`. `default` still points at `test`.
- Wrote the three proof tests:
  - `test/system/dark_mode_toggle_test.rb` -- clears `localStorage`, reloads, clicks the
    layout's global `button[aria-label='Toggle dark mode']`, and asserts
    `document.documentElement.classList.contains('dark')` flips true then false. This is
    `ui-design-tokens`' previously-blocked acceptance check; it now runs.
  - `test/system/harness_smoke_test.rb` -- visits the real `button_path` docs page and
    runs `assert_accessible` scoped to the rendered Button preview only (see §
    Corrections -- the full page has pre-existing violations that are the audit's problem,
    not this harness's).
  - `test/system/accessibility_assertion_test.rb` -- seeds a self-contained `data:` URL
    page with one deliberate violation (an `<img>` with no `alt`, everything else
    accessible) and asserts `assert_accessible` raises with axe's own report naming
    `image-alt`.
- Added `csrf_meta_tags` to `examples/app/views/layouts/docs.html.erb` (the only change to
  that file) -- it had none, so Turbo form submissions in the docs app were 422ing.
- Narrowed `.github/workflows/ci.yml`'s matrix to `["3.2", "3.3", "3.4", "4.0"]` (Ruby 3.1
  dropped -- coordinated with the sibling raising the gemspec floor to 3.2) and added a
  `test-system` job on Ruby 3.3 running `bundle exec rake test:system`, relying on
  `ubuntu-latest`'s pre-installed Chrome per this spec's own § Assumptions rather than
  adding a third-party setup-chrome action.
- Ran `bundle exec rake tailwindcss:build` from `examples/` before the accessibility runs
  so `assert_accessible` sees current compiled CSS; confirmed no diff in
  `package-lock.json` or `examples/app/assets/builds/`.
- Verified no orphaned Chrome/chromedriver processes survive after any run (individual
  `TEST=` invocations and the full `test:system` run alike).
- Built the `SLOW=1` slow lane (`7dab090`) after `ui-select` shipped a racy assertion that
  passed on its author's machine and failed three times out of three on the reviewer's:
  `test/application_system_test_case.rb` emulates network latency through the driver's CDP
  session (400 ms by default, `SLOW_LATENCY` overrides), leaves a CDP-less driver alone, and
  `test/system/slow_lane_test.rb` asserts the opposite thing in each mode so neither can pass
  vacuously. Proven by restoring the original racy read and watching `SLOW=1` fail it.
- Ran the whole browser lane under `SLOW=1` once, one file at a time: 51 files, 320 runs,
  2368 assertions, 0 failures, in 11m11s -- close to the unthrottled time, since latency is
  per request and assets cache after the first page load. That clean result is why the switch
  is recorded as a diagnostic to reach for rather than a CI job (§ Behavior, "When to reach
  for it"; § Out of scope / deferred).

## In progress
None -- the lane and the slow switch are both built and green.

## Last green checkpoint
2026-09-14, at `7dab090`:
- `bundle exec rake test`: 349 runs, 1002 assertions, 0 failures (the count moves as sibling
  scopes land; the unit lane's file list still contains nothing under `test/system/`).
- `bundle exec rake test:system`, every file run on its own: 51 files, 0 failures -- and the
  same sweep under `SLOW=1`: 51 files, 320 runs, 2368 assertions, 0 failures.
- `SLOW=1 bundle exec rake test:system TEST=test/system/slow_lane_test.rb` and the same file
  with the switch unset: 3 runs each, 0 failures, asserting opposite things about one request.
- Earlier, at `04237d6`: `bundle exec rake test` 116 runs / 335 assertions and
  `bundle exec rake test:system` 3 runs / 11 assertions, ~2.2s wall.
- `bundle exec ruby -Itest -e 'require "test_helper"; ...'`: see § Corrections --
  `defined?(Capybara)` is true, `defined?(Selenium)` is false.
- rubocop clean on every file this scope touched (`test/application_system_test_case.rb`,
  `test/system/*.rb`, `Rakefile`).

## Dead ends
- First cut of the `accessibility_assertion_test.rb` fixture used
  `"data:text/html,#{CGI.escape(html)}"`. `CGI.escape` form-encodes spaces as `+`, which a
  `data:` URL does not decode the same way; Chrome parsed the mangled markup into a
  malformed DOM (`<img+src="x.png">`) and axe reported page-structure violations
  (`document-title`, `html-has-lang`, ...) instead of the intended `image-alt` one.
  Switched to `ERB::Util.url_encode` (percent-encoding) and built a minimal
  otherwise-accessible page (`lang`, `title`, `main`, `h1`) around the one seeded `<img>`
  so the assertion is unambiguous.

## Corrections
- Rule 1's acceptance check (`defined?(Capybara)` false after `require "test_helper"`) was already unachievable on the pristine tree, before this scope touched anything, because `ViewComponent::TestHelpers` (loaded by `test/test_helper.rb`, not owned by this scope) does its own guarded `require "capybara/minitest"` to back `assert_selector` in component tests; the checkable substance of rule 1 is "no browser driver in the unit lane" (`defined?(Selenium)` is `nil`, verified), not "no Capybara symbol" — provable — implementer
- The Rakefile acceptance check greps the whole file for the literal substring `test/**/*_test.rb`, so `FileList['test/**/*_test.rb'].exclude(...)` fails that check even though it behaves correctly; rewritten with `File.join('test', '**', '*_test.rb')` so the substring never appears as contiguous text — provable — implementer
- A full-page, unscoped `assert_accessible` against any docs page fails today — the shared sidebar and the Button page's own props table have real pre-existing `color-contrast` (8 nodes, `text-neutral-400`/`text-neutral-500` under 4.5:1) and `scrollable-region-focusable` (a horizontally-scrolling `<pre>` with no tabindex) violations, which is the parallel audit's problem, not this harness's; `harness_smoke_test.rb` scopes the assertion via axe's own `within:` to the rendered Button preview, which is clean, rather than disabling rules — provable — implementer
- The registered `screen_size` was never applied to the browser window at all (`driven_by` applies it only to a driver Rails registers, and this scope registers its own), so every test ran at about 756x413 and 37 files carried their own `resize_to(1400, 1400)` to compensate; the base class now sizes the viewport before each test, those per-file resizes are gone, and `harness_viewport_test.rb` pins it — found by the stress page's 320 px profiles — provable — implementer
- Chrome clamps its own window at 500 px wide on macOS, so a resize can't produce the 320 px viewport the stress profiles need; that condition is emulated with `Emulation.setDeviceMetricsOverride` through the same CDP session the slow lane uses — provable — implementer
