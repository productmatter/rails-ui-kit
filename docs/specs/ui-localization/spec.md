---
slug: ui-localization
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: medium
size: large
target_model: standard
created: 2026-09-14
loop_budget: 5
---

## Intent

**Two kinds of words, translated in two places.** This is the frame for everything
below, and the thing the current documentation fails to say.

- **Content** is what the call site writes: a Field's label, a Button's text, help text,
  a Select's options, a Modal's title, a Toast's message. It belongs to the host app and
  the host translates it, through its own `t(".x")`, `human_attribute_name` and locale
  files. **The kit never ships a translation for content.** Field's model binding and
  Select's enum labels already work this way — they resolve through Rails' own label and
  attribute lookups, so the host's locale files translate them and the kit adds nothing
  (`ui-field-model-binding` § Behavior; `ui-select` § Behavior, item 7).
- **Chrome** is what the kit says on its own, that no call site ever writes: a toast's
  close-button accessible name, Select's "No results" and its result count, the
  unsaved-changes prompt, the show-options button's name. A host doesn't pass these
  because it doesn't know they exist. **Only chrome lives in
  `config/locales/rails_ui_kit.en.yml`.**

That file is not a translation of the components. It is sixteen strings the kit says in
its own voice. The README, the CHANGELOG and the docs page all currently say "every
user-visible string the kit renders", which reads as the former, and cost the decider a
wrong mental model. Saying it plainly is part of this scope's work.

**What is already true** (verified against the code on 2026-09-14): 16 chrome strings
under 15 keys, resolved through `I18n.t` at render time by four components — Modal,
ConfirmDialog, Toast/ToastContainer and Select — plus two controllers a host wires up
itself (`ui--dark-mode`, `ui--turbo-disable-with`), which read their strings from data
attributes the host renders. Where a Stimulus controller needs a string, the owning
component renders the translated value into a data attribute and the controller reads it
back; the English literal in the controller is only the fallback for hand-written markup.
The engine puts its locale file on `I18n.load_path` automatically, and an app's own
`config/locales` is loaded after every engine's, so a host key wins with no
monkey-patching. Keyboard input already guards IME composition (`event.isComposing`) in
every keydown path. **The kit renders no date, no currency, and exactly one number**
(Select's result count), so date and number formatting are genuinely the host's.

**What is missing.** Three things, and they are the shape of this scope:

1. **A host cannot override a chrome string for one instance.** Only ConfirmDialog
   accepts overrides. Seven strings across four components can be changed only
   app-wide, by redefining a key. A confirm dialog gets `confirm_label:`; the Toast
   beside it cannot be told what its close button is called.
2. **Plural categories break outside English.** Select ships two forms and picks with
   `count === 1`. Arabic has six categories, Russian four, Polish four. Worse, the
   English form is written `one: "1 result"` with the number baked in, which teaches
   translators a pattern that is wrong the moment `one` covers more than the number one
   — French `one` covers 0, Russian `one` covers 21, 31, 101.
3. **Nothing proves any of it.** No test in the browser lane switches locale. Nothing
   catches the next hardcoded string, and nothing catches a chrome string that is
   translated on the server and then overwritten in English by JavaScript.

**Appetite.** The chrome contract, stated once and enforced by tests, plus the two
mechanical fixes that contract exposes (per-instance overrides, real plural categories)
and what the kit guarantees when translated text outgrows its box. Direction — RTL — is
a different promise with a different cost and is `ui-localization-rtl`.

**Build order**, because two of these land in the same four lines of Select: the chrome
contract and the per-instance keywords first (it renames keys and moves resolution into
one place), then Select's plural map on top of the keyword it just gained, then the
text-expansion guarantees, then the proof lane. Doing plurals first means writing the
`results` data attribute twice.

## Goal

Every chrome string the kit renders resolves call site → host locale file → kit default,
in Ruby and in every Stimulus controller that displays one; Select announces its result
count in the plural category the reader's locale actually uses; and a build that
introduces a hardcoded English string, an untranslated chrome surface or a key with no
home fails a check without a human noticing. Established when every agent-loopable check
in § Acceptance checks passes.

## Non-goals

- **Translating content.** The kit ships no translation for a label, an option, a button's
  text, a toast's message or an error message. Those come from the host's locale files
  through Rails' own lookups.
- **Shipping locales beyond `en`.** Decided 2026-09-14 by Jonathan Simmons: the kit
  ships English chrome only, because the studio cannot maintain quality in languages
  nobody here reads, and a wrong translation is worse than an obvious gap — a host meets
  a missing translation immediately and fixes it, where a plausible-looking wrong one
  reaches its users. The 15 strings are listed on one docs page for a host to translate in
  ten minutes, and the host's own locale files already win by load order. The `fr` and
  `ar` files this scope adds live in `test/fixtures/locales/`: they prove the mechanism
  and are never packaged in the gem.
- **Date, time, currency and number formatting.** The kit renders none, except the one
  result count, which this scope formats. Adding a date component is not this scope's
  business (`ui-component-library` § Out of scope).
- **Font stacks, CJK typography and `lang` on the document.** The kit sets no
  `font-family` anywhere (verified) and does not own `<html>`. A host sets `lang`, which
  it already owes under WCAG 3.1.1, and picks fonts for its scripts.
- **Marking language of parts on a fallback.** When a host runs in a locale the kit has
  no translation for, English chrome appears inside a page in another language. The kit
  does not annotate it with `lang`; the host translates the 15 strings instead.
- **A helper that renders the two host-wired controllers' chrome.** `ui--dark-mode` and
  `ui--turbo-disable-with` are wired onto the host's own markup; the docs page shows the
  one-line `I18n.t` each needs. A generator or helper for that is not worth its API.
- **An i18n tooling dependency.** `i18n-tasks` earns its place in an app with hundreds of
  keys and many locales. The kit has 15 keys and one locale; the checks here are twenty
  lines of Minitest against a known inventory, and they cover things `i18n-tasks` does
  not (a JavaScript fallback drifting from its key, a docs row going stale).
- **Locale-aware text matching in Select's filter and typeahead.** Case folding is
  `toLowerCase` plus diacritic stripping, which is right for Latin, Greek and Cyrillic
  and wrong for Turkish dotless ı and for half-width Japanese kana. No client needs it
  (§ Out of scope).

## Behavior

1. **The chrome inventory was 16 strings under 15 keys when this was shaped; deleting
   `toast.close` (item 4) leaves 15.** Verified against the code at shaping time:

   | Key (under `rails_ui_kit.`) | Rendered by | Per-instance override today |
   |---|---|---|
   | `modal.unsaved_changes_title` | `Ui::ModalComponent` → `ui--modal` value | none |
   | `modal.unsaved_changes_message` | same | none |
   | `confirm_dialog.title` | `Ui::ConfirmDialogComponent` | `title:` |
   | `confirm_dialog.message` | same | `message:` |
   | `confirm_dialog.confirm` | same | `confirm_label:` |
   | `confirm_dialog.cancel` | same | `cancel_label:` |
   | `toast.close_label` | `Ui::ToastComponent`, and the templates `Ui::ToastContainerComponent` renders | none |
   | `toast.close` | same — the sr-only twin of `close_label` | none |
   | `toast.default_title` | `Ui::ToastComponent(message: nil)`, `Ui::ToastContainerComponent` value | none |
   | `select.show_options` | `Ui::SelectComponent(search: true)` | none |
   | `select.no_results` | same | none |
   | `select.results.one` / `.other` | same, through `ui--select` | none |
   | `turbo_disable_with.processing` | no component: the host's meta tag | `data-turbo-disable-with` |
   | `dark_mode.switch_to_light` / `.switch_to_dark` | no component: the host's toggle markup | the toggle's data attributes |

   Rails' own `helpers.select.prompt` is read, not redefined, and already resolves call
   site (`prompt:`) → host locale → Rails' default. It is the shape every row above
   takes.

2. **Every chrome string resolves call site → host locale file → kit default.** Each
   component takes a keyword for each chrome string it renders. A keyword given wins; a
   keyword left out (or `nil`) resolves through `I18n.t` at render time, which a host
   key in its own `config/locales` overrides app-wide. The new keywords:
   `Ui::ModalComponent(unsaved_changes_title:, unsaved_changes_message:)`,
   `Ui::ToastComponent(close_label:, default_title:)`,
   `Ui::ToastContainerComponent(default_title:, close_label:)` — the container needs both
   because the toasts JavaScript creates are clones of the templates it renders —
   `Ui::SelectComponent(show_options_label:, no_results:, results:)`. ConfirmDialog's
   four keywords already exist and keep their names.

3. **The keyword is the key's leaf.** One name per string across the YAML key, the Ruby
   keyword and the docs table, so a host that reads a key name knows the keyword and the
   reverse. Two keys are renamed to meet it (`confirm_dialog.confirm` →
   `confirm_label`, `.cancel` → `cancel_label`), and `select.show_options` →
   `show_options_label`, which also says what it is: an accessible name, not a caption.
   The renames are free: no release has shipped any of these keys (§ Assumptions).

4. **`toast.close` is deleted.** The close button carries both an `aria-label` and an
   sr-only twin. `aria-label` wins the accessible-name computation, so the sr-only string
   is never announced and never seen: a key nobody can observe. The button keeps the
   `aria-label` from `close_label`; the sr-only span goes.

5. **A per-instance override reaches a Stimulus controller unchanged.** Resolution
   happens in Ruby; the component renders the resolved string into the data attribute its
   controller already reads. No controller gains a lookup, and the English literal in the
   controller stays exactly what it is — the fallback for hand-written markup that carries
   no attribute — and is asserted equal to its key's English value so the two cannot
   drift.

6. **Select sends the whole plural map and picks with `Intl.PluralRules`.** Ruby renders
   the map `I18n.t('rails_ui_kit.select.results')` returns — whatever categories the
   locale defines, verified to come back as a Hash — as one JSON data value, together
   with the locale that rendered it. The controller selects with
   `new Intl.PluralRules(locale).select(count)`, falls back to the `other` form when the
   locale's category has no entry, and uses the `zero` entry when `count` is 0 and one
   exists, which is Rails' own explicit-zero convention. A malformed or unknown locale
   tag never throws: it degrades to the `other` form.

7. **The locale comes from the render, not from the document.** The same Ruby call that
   resolves the strings stamps `I18n.locale` (with `_` normalised to `-`) beside them. It
   is not read from `<html lang>`: the kit does not own that element, a host may not set
   it — the kit's own docs app hardcodes `lang="en"` on every page — and a French map
   selected with English rules gets 0 wrong. Strings and the rules that pick between them
   come from one place.

8. **The count is formatted for its locale** (`Intl.NumberFormat`), so 1 234 results
   reads as its locale writes numbers rather than as `1234`.

9. **The English `one` form carries `%{count}`.** `one: "%{count} result"`, not
   `"1 result"`. The `one` category is not the number one in most locales, and the
   shipped file is the example every host translation is copied from.

10. **A call-site `results:` replaces the whole map.** Merging a call site's forms into a
    locale's map mixes two languages in one sentence. A partial map — one without
    `other` — raises, in the same development-and-test way an unknown variant does.

11. **Chrome strings are escaped wherever they are written.**
    `ui--turbo-disable-with` interpolates its text into an `innerHTML` template,
    including into `aria-label="${…}"`. A translation containing a quote or an angle
    bracket breaks the markup, and any value that ever carries user data is an injection.
    The label and the text are set as data, not as markup.

12. **What the kit guarantees when text outgrows its box.** Controls hold their height:
    Button, Input, Select and Textarea's minimum stay on the `--control-height*` step
    they read (`ui-control-sizing` § Behavior), whatever the text does, because a row of
    controls lining up is the contract that scale exists for. Within that:
    - **Button** grows along the inline axis and never wraps (its `whitespace-nowrap` is
      deliberate — a wrapped button breaks the height contract). A label too long for its
      container is the host's layout to solve, on host content.
    - **A closed Select** truncates with an ellipsis, as a native select does, and the
      full text stays reachable: in the accessible name, and in the open list.
    - **The open list wraps.** Options stop truncating. The popup takes the control's
      width, so a truncated option is text a sighted user has no way to read at all.
      Rows keep their one-line minimum at every step, which is what `ui-control-sizing`
      fixes; content makes a row taller, a step never does.
    - **A Tooltip wraps** at a maximum width instead of running off the viewport on one
      `whitespace-nowrap` line.
    - **Input and Textarea** hold their step and their content scrolls, which is the
      platform's behaviour and right.

13. **The docs say which words the kit translates.** The README's Translations section,
    the CHANGELOG entry and the docs app's Internationalization page lead with the
    content/chrome split — the kit translates only what it says in its own voice — and
    the key table gains the keyword each string's per-instance override uses.

14. **The docs app can switch locale.** `examples/` takes a `locale` parameter, applies
    it around the request and renders `<html lang>` from it. Without it, no browser check
    below can exist. It is also where a reader sees the pseudo-locale.

## Business rules

These refine `ui-component-library` § Business rules, rules 5 and 6. They weaken none.

**Must**

1. **Content is the host's, chrome is the kit's.** The kit ships no translation for a
   string a call site provides. A key under `rails_ui_kit.*` for a label, an option, a
   message body or an error is out of bounds: it would be the kit guessing at the host's
   product vocabulary.
2. **Every chrome string a user can meet is in the locale file, and reachable per
   instance.** "A user can meet it" includes accessible names, sr-only text, live-region
   announcements and anything a screen reader reads. It excludes `console.warn` and
   `console.error`, which address a developer; those stay English literals and are the
   only literals allowed in the JavaScript.
3. **No chrome string resolves at class-load time.** Every lookup happens per render, so
   a locale switch between two renders in one process takes effect. A string frozen into
   a constant is the defect this rule names.
4. **A Stimulus controller never keeps a second copy of a translated string.** Its
   English literal exists only as a fallback for markup the kit did not render, and it is
   asserted equal to the English value of the key it mirrors.
5. **Plural selection is CLDR's, not the kit's.** No `count === 1`, no hand-written
   category tables, no plural logic in Ruby that JavaScript then repeats.
6. **A control's height never depends on its text** (§ Behavior, item 12;
   `ui-control-sizing` § Business rules, rule 3).

**Should**

7. **Adopt the platform.** `Intl.PluralRules` and `Intl.NumberFormat` are the browser's;
   the kit adds no pluralization library and no polyfill.
8. **One name per string** (§ Behavior, item 3), so the docs table, the YAML and the
   keywords cannot disagree.

**May**

9. A component may accept a keyword whose value is a Hash of plural forms (`results:`);
   that is the one chrome keyword that is not a plain String.

## Assumptions

- **No release has shipped any `rails_ui_kit.*` key.** `v0.2.0` is the only tag and has
  no locale file at all; the CHANGELOG's `0.3.0` section is unreleased on this branch.
  That is what makes renaming two keys, deleting `toast.close` and replacing Select's
  two `results-*` Stimulus values with one map free. **At a contradiction** — a `v0.3.0`
  tag cut before this builds — stop and escalate: the renames then need deprecated
  aliases, which is a different design.
- **`I18n.t` on a pluralization key with no `count` returns the whole Hash of forms**,
  including under `I18n::Backend::Fallbacks` (verified 2026-09-14 against `i18n` 1.15.2
  in this bundle, for `en` and for a six-category Arabic store). Rails exposes no
  enumeration of a locale's *expected* categories without `rails-i18n`, which is not in
  this bundle, and the kit does not need one: it sends what the locale file has and the
  browser decides what to ask for. **At a contradiction** — a backend that returns
  something other than a Hash — escalate rather than reconstructing the map key by key.
- **`Intl.PluralRules` covers every locale a host will run.** It is in every browser the
  kit supports. **At a contradiction** — a locale tag it rejects — the `other` form is
  shown; that is specified, not a failure.
- **Rails' `:zero` is an explicit-zero form, and CLDR's `zero` category is a category.**
  They coincide for Arabic, Latvian and Welsh, where CLDR's `zero` selects 0. They differ
  for Latvian's 10–20, where CLDR also says `zero`. A Latvian translation therefore reads
  as CLDR intends, not as Rails' Simple backend would have read it in Ruby. This is
  accepted: the browser is where the count is known. **At a contradiction** — a host
  reporting a wrong Latvian form — the fix is the translation, not a second rule table.
- **Arabic counts render in Latin digits by default.** Measured 2026-09-14 in Chrome 152:
  `Intl.NumberFormat("ar")` formats 11 as `11`, not `١١` — current CLDR gives `ar` the
  `latn` numbering system. A host that wants Arabic-Indic digits needs the locale tag to
  carry `-u-nu-arab`; whether a Rails locale named that way is practical is unverified.
  **At a contradiction** — a client needing Arabic-Indic digits — escalate rather than
  hardcoding a numbering system in the kit.
- **Machine translation in the browser** (Chrome's translate, Safari's) may or may not
  translate `aria-label`. The kit does not rely on it either way, and does not choose
  between an accessible name and visible text on that basis.
- **Safari's IME quirk.** Every keydown path already ignores `event.isComposing`, which
  is correct in Chrome and Firefox. WebKit has historically reported the composition-
  ending Enter differently. Unverified here; it is the one thing in this scope a browser
  check cannot settle, so it is a human gate with a Japanese IME rather than a claim.
- **Tall scripts in fixed-height controls.** Thai, Devanagari and Arabic set taller line
  boxes than Latin at the same font size, and the kit's controls are a fixed height with
  `text-sm`. Whether a stacked diacritic clips is a rendering question no assertion
  settles well. It is a human gate. **At a contradiction** — visible clipping — the fix
  is line-height on the control, not a different control height, which would break
  `ui-control-sizing` rule 3.

## Critical files

- `config/locales/rails_ui_kit.en.yml` — the chrome inventory; the only file in the gem
  that holds a translation.
- `app/components/ui/modal_component.rb`, `toast_component.rb` and its template,
  `toast_container_component.rb`, `select_component.rb`, `select/primitives.rb` — the
  four components that render chrome, and where the keywords land.
- `app/components/ui/confirm_dialog_component.rb` — the shape the other three follow.
- `app/javascript/rails_ui_kit/controllers/select_controller.js` — `announce()`, the only
  place a plural is chosen.
- `app/javascript/rails_ui_kit/controllers/turbo_disable_with_controller.js` — the
  `innerHTML` interpolation in `disableElement`.
- `app/components/ui/select/listbox_component.rb`, `tooltip_component.rb` — the two
  truncation decisions § Behavior item 12 changes.
- `test/fixtures/locales/` — `rails_ui_kit.fr.yml` (whose `one` form needs `%{count}`)
  and the Arabic fixture this scope adds.
- `examples/app/controllers/application_controller.rb`, `examples/app/views/layouts/docs.html.erb`
  — the locale switch and the `lang` attribute it sets.
- `examples/app/views/docs/i18n.html.erb`, `README.md` (Translations), `CHANGELOG.md` —
  the three places that currently say "every user-visible string".

## Acceptance checks

### agent-loopable

- The inventory holds: every key in `rails_ui_kit.en.yml` is referenced by the kit, has a row on the docs page, and its leaf is the keyword its component takes; every English literal in a Stimulus controller that mirrors a key equals that key's value; no user-facing literal exists outside `I18n` in `app/components` or `app/javascript` beyond the allow-list (the required marker's `*`, and console messages). The scan is proved able to fail by a planted literal — run: `bundle exec rake test TEST=test/i18n/chrome_contract_test.rb`
- For each of Modal, Toast, ToastContainer, Select and ConfirmDialog: a keyword wins over a host locale key, which wins over the kit's default; a keyword left out or passed `nil` resolves at render time, so two renders in one process under different locales produce different strings; a keyword's value reaches the data attribute the controller reads; a partial `results:` raises — run: `bundle exec rake test TEST=test/components/ui/chrome_override_test.rb`
- In the browser under the `fr` fixture, every chrome surface shows French: the modal's unsaved-changes prompt, the confirm dialog's default title, message and both buttons, a toast's close-button accessible name, a toast created by `window.triggerToast(type)` with no message, Select's show-options name, its empty state and its status announcement. Under `en`, English — run: `bundle exec rake test:system TEST=test/system/localization_switch_test.rb`
- Under an Arabic fixture with all six categories, Select's status announcement matches the category `Intl.PluralRules` selects for 0, 1, 2, 3, 11 and 100; under `fr`, 0 selects the `one` form and renders "0"; under `en` the existing English wording is unchanged; a call-site `results:` wins; the count is formatted for the locale — run: `bundle exec rake test:system TEST=test/system/localization_plural_test.rb`
- Under a pseudo-locale generated from `rails_ui_kit.en.yml` (never a committed file, so it cannot drift), every chrome surface renders a pseudo-marked string — no English chrome survives — and at roughly 40% expansion: every control still measures its step's token height, a long option in an open Select wraps and is fully visible, a long tooltip wraps within its maximum width and stays on screen, and no kit-rendered element clips text it does not deliberately truncate — run: `bundle exec rake test:system TEST=test/system/localization_pseudo_test.rb`
- A disable-with text containing `"`, `<b>` and `&` renders as those characters in the button's text and its accessible name, and injects no element — run: `bundle exec rake test:system TEST=test/system/turbo_disable_with_test.rb`
- The whole suite stays green with no existing expectation rewritten to accommodate this scope — run: `bundle exec rubocop && bundle exec rake test && bundle exec rake test:system`

### judgeable

- The README's Translations section, the CHANGELOG entry and the docs app's
  Internationalization page lead with the content/chrome split and cannot be read as "the
  kit translates the components". The key table names each string's keyword. Judged
  against § Intent and § Behavior, items 1–3, and `conventions/`.
- Resolution lives in one place per component rather than being re-derived per call site,
  and no controller gained a lookup. Judged against § Business rules, rules 3 and 4.

### human-gate

- Jonathan reads the Internationalization page and confirms he would not mistake the
  locale file for a translation of the components.
- Jonathan views the docs pages under the pseudo-locale and under Arabic sample content,
  and accepts what expansion and tall scripts do to the controls (§ Assumptions).
- A Japanese IME in Safari: typing into a search Select and pressing Enter to commit a
  composition does not choose an option.

## Out of scope / deferred

- **Direction and RTL** — `ui-localization-rtl`. A separate promise, separately costed.
- **Shipping non-English locale files in the gem: declined** (§ Non-goals). Revisit if a
  client build ships a second language and the studio can review the strings.
- **Locale-aware collation in Select's filter and typeahead: not planned.** Turkish
  dotless ı and half-width kana don't match today. `Intl.Collator` with sensitivity
  `base` would fix the first and `String#normalize("NFKC")` the second; neither has a
  pulling need, and both change what matches for every existing locale.
- **A translated `required` marker.** The asterisk is `aria-hidden`, and the state a
  screen reader announces comes from the `required` attribute, which the browser renders
  in the user's own language. The kit translates no glyph.
- **Turbo page-cache staleness across a locale switch.** A cached snapshot in the
  previous language is Turbo's behaviour on the host's own content; the kit's chrome is
  no different from it.
