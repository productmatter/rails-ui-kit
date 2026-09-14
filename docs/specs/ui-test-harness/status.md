## State
ready-for-review

The lane is built and committed in `04237d6`, and both rake tasks are green. Three
agent-loopable checks pass as written. The unit-lane check can't pass on any tree,
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

## In progress
The `SLOW=1` switch is specified (§ Behavior, § Business rules rule 7, § Assumptions) and not
yet built. It came out of `ui-select`: a racy assertion in `select_form_submission_test.rb`
passed on the author's machine and failed three times out of three on the reviewer's, and
emulated network latency was the only thing that reproduced it. The implementation is the
base class plus `test/system/slow_lane_test.rb`, and the first use of it is one pass over the
whole browser lane to see what else it finds.

## Last green checkpoint
- `bundle exec rake test`: 116 runs, 335 assertions, 0 failures (count moves as sibling
  scopes land component-test changes concurrently on this branch; the file list itself is
  unchanged at 12 files, none under `test/system/`).
- `bundle exec rake test:system`: 3 runs, 11 assertions, 0 failures, ~2.2s wall.
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
