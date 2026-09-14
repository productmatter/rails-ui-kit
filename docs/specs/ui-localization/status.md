## State

ready-for-review — all four build pieces of this scope are done and every agent-loopable
check passes as written (the fifth piece, the RTL conversion, is `ui-localization-rtl`).
What remains is the judgeable review and the three human gates: reading the
Internationalization page, the pseudo-locale and tall-script look, and a Japanese IME in
Safari.

## Done

- Read the shipped i18n work against the code rather than the summary of it:
  `config/locales/rails_ui_kit.en.yml`, `examples/app/views/docs/i18n.html.erb`,
  `test/fixtures/locales/`, all ten components, all eighteen Stimulus controllers and
  `app/javascript/rails_ui_kit/overlay/`.
- Counted the inventory: **16 chrome strings under 15 keys**, rendered by **four**
  components (Modal, ConfirmDialog, Toast/ToastContainer, Select) plus two host-wired
  controllers. The directive's "26 keys, 6 components" is not what is in the file.
- Verified the per-instance override gap component by component. The directive's list is
  right, and incomplete: `Ui::ToastContainerComponent` also needs `close_label:`, because
  the toasts `window.triggerToast` creates are clones of the templates the container
  renders, so a per-instance close label on `Ui::ToastComponent` alone never reaches them.
- Verified `I18n.t` on a plural key with no `count` returns the whole Hash of forms, for
  `en` and for a six-category Arabic store, including under `Backend::Fallbacks`
  (`i18n` 1.15.2, this bundle, 2026-09-14). Rails exposes no list of a locale's expected
  categories without `rails-i18n`, which is not in this bundle and is not needed.
- Found three defects the directive did not name: `ui--turbo-disable-with` interpolates
  its chrome string into `innerHTML`, including into `aria-label="${…}"`, so a quote in a
  translation breaks the markup; `rails_ui_kit.toast.close` can never be announced,
  because the same button carries an `aria-label`; and the English `one` form is written
  `"1 result"` with the number baked in, which is wrong in every locale where `one`
  covers more than the number one (French 0, Russian 21).
- Confirmed what is already right, so it is not rebuilt: every keydown path guards
  `event.isComposing`; the kit sets no `font-family`; the kit renders no date and exactly
  one number; Select's prompt reads Rails' own `helpers.select.prompt`; engine load-path
  order already makes a host key win.
- Authored `spec.md`, `relations.md`, `open-questions.md` and this file, and added the
  § Scopes rows to `ui-component-library`.

- **Piece 1, the three defects.** `ui--turbo-disable-with` builds its indicator as nodes
  (`textContent`/`setAttribute`, the spinner parsed from static markup), and TDW1–TDW2 prove
  a string holding `"`, `&`, `<script>` and `<b>` renders as characters in the text, the
  accessible name and the announcement; TDW1 failed on the `spinner` and `pulse` styles
  before the fix. `rails_ui_kit.toast.close` and its sr-only span are deleted, not made
  observable: `aria-label` already wins the name computation, so a second string there
  could only drift. Every plural form now carries `%{count}` (en and the fr fixture), and
  CC7 fails a form that doesn't interpolate.
- **Piece 2, the chrome contract.** `Ui::Chrome` (`chrome_string`, `chrome_plural`,
  `chrome_locale`) is the one place resolution happens. Keywords: Modal
  `unsaved_changes_title:`/`unsaved_changes_message:`, Toast `close_label:`/`default_title:`,
  ToastContainer `default_title:`/`close_label:` (passed into every template toast), Select
  `show_options_label:`/`no_results:`/`results:`; ConfirmDialog's four text keywords became
  explicit and `nil` now falls through instead of rendering nothing. Keys renamed to their
  keyword (`confirm_label`, `cancel_label`, `show_options_label`). `examples/` takes
  `?locale=` and renders `<html lang>` from it, with `config.i18n.fallbacks = [:en]`. The
  README's Translations section and the Internationalization page lead with content vs
  chrome, and the key table gained a per-instance keyword column. Proofs: 7 of the 12
  `chrome_override_test` cases fail with the call-site value ignored (the other 5 assert
  locale behaviour that already worked); 5 of 6 `localization_switch_test` cases fail with
  the locale switch removed; CC5 and CC6 each fail on a planted literal.
- **Piece 3, plurals.** Select renders `data-ui--select-results-value` (the whole map as
  JSON) and `data-ui--select-locale-value` (`I18n.locale`, `_`→`-`); `ui--select` picks with
  `Intl.PluralRules`, honours an explicit `zero` at 0, falls back to `other`, formats with
  `Intl.NumberFormat`, and never throws on a bad tag. An Arabic fixture with six
  categories and a plural demo on the Internationalization page (options sized 1, 2, 3,
  11 and 100) back `localization_plural_test`; with the old `count === 1` logic 5 of its 10
  cases fail (Arabic zero/two/few/many, French 0).
- **Piece 4, expansion and the pseudo-locale.** Select's open-list options wrap
  (`min-w-0 wrap-break-word` — `min-w-0` is what lets a flex child shrink enough to wrap);
  Tooltip wraps at `max-w-xs` instead of `whitespace-nowrap`. `test/support/pseudo_locale.rb`
  generates `en-XA` from the English file at boot (never committed). `localization_pseudo_test`
  covers chrome on four surfaces, control heights, the wrapped option and the tooltip box;
  LP6 and LP7 fail with `truncate` and `whitespace-nowrap` restored.
- **Control fills (orchestrator, mid-build, decider's call).** Input, Textarea and Select's
  box are `bg-background dark:bg-muted/50`; `ui-presentational-components` rule 6(a) is
  amended to match. `control_fill_test` CF1 fails with `bg-transparent` restored.

## In progress

Nothing.

## Last green checkpoint

uncommitted on `278dcf7` — `bundle exec rubocop` 147 files, no offenses; `bundle exec rake test` 473 runs, 0 failures; browser lane file by file 68/68 files, 410 runs, 3052 assertions, 0 failures; `SLOW=1 turbo_disable_with_test` 4 runs, 0 failures after the TDW2 race fix.

## Dead ends

- A single `strings:` hash keyword per component (`strings: { no_results: … }`) — rejected:
  `Ui::ConfirmDialogComponent` already ships four flat keywords in `v0.2.0`, and a second
  convention beside it costs more than it buys.
- Reading the plural locale from `<html lang>` — rejected: the kit does not own that
  element, and the docs app hardcodes `lang="en"`, which would select French strings with
  English rules. The locale is stamped by the same render that resolves the strings.
- `i18n-tasks` as a dependency — rejected: 15 keys, one locale, and it does not check the
  two things that actually drift here (a controller's English fallback, a docs row).

## Corrections

- TDW2 read the announcer with a non-waiting `.text` right after the click, which lost the controller's 100ms write and failed under SLOW=1 while passing at normal speed; it now waits with an exact-text assertion — provable — implementer
- The pseudo-locale and plural tests first asserted status text with Capybara's default substring match, which let "0 résultats" satisfy "0 résultat"; every plural assertion is now exact_text — provable — implementer
- `localization_switch_test` LS5 was written in Piece 2 expecting "0 résultats" and went red once Piece 3 correctly put French 0 in the `one` category; the expectation was wrong, not the code — provable — implementer
- The first plural test expected Arabic-Indic digits; Chrome 152's CLDR formats `ar` with Latin digits by default, so the expectation was corrected and the assumption recorded in spec.md — provable — implementer
- The chrome inventory is fifteen strings, not sixteen, after `toast.close` was deleted; spec.md, README and the docs page were corrected — provable — implementer
- The directive's inventory count (26 keys, 6 components) was wrong; it is 16 strings under 15 keys across 4 components — provable — implementer
- The directive's per-instance override list omitted `Ui::ToastContainerComponent(close_label:)`, without which JavaScript-created toasts keep the app-wide string — provable — implementer
