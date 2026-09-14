## State

blocked: awaiting ratification — the spec is shaped and nothing is built. Two entries in
`open-questions.md` carry defaults and a 2026-09-21 deadline; neither gates the build.

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

## In progress

Nothing. No component, controller, test or doc has been touched.

## Last green checkpoint

none — spec work only; no code changed.

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

- The directive's inventory count (26 keys, 6 components) was wrong; it is 16 strings under 15 keys across 4 components — provable — implementer
- The directive's per-instance override list omitted `Ui::ToastContainerComponent(close_label:)`, without which JavaScript-created toasts keep the app-wide string — provable — implementer
