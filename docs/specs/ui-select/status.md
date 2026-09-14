## State

ready-for-review

v1 is built: both modes, the Rails option API, Field, Turbo, the submission model and the
deprecation of Dropdown's `kind: :listbox`, with every agent-loopable acceptance check
passing. What remains is the judgeable review and
Jonathan's three human gates — VoiceOver in Safari, the throttled-connection swap, and the
phone check that confirms or overturns the coarse-pointer default. Remote search is designed
in § Behavior, items 27–31 and deliberately unbuilt. Two corrections are recorded below.

## Done

- Shaped from the orchestrator's directive (2026-09-13) against the live repository:
  `overlay_controller.js`, `roving_focus_controller.js`, `anchor_controller.js`,
  `dropdown_controller.js`, `dropdown_component.rb`, `field_component.rb` and
  `field/`, `native_select_component.rb`, the positioning and overlay specs, and the
  2026-09-13 component audit.
- Verified both APG key tables against the w3.org pages' HTML on 2026-09-13: the
  select-only combobox example, and the editable combobox with list autocomplete.
- Authored `spec.md`, `relations.md`, `open-questions.md` and this `status.md`, and added
  the § Scopes row to ui-component-library.
- Landed the four primitive prerequisites in `11d71a9`, each under its owning spec and each
  with its own test: `ui--overlay`'s `moveFocus` (already shipped in `8446865`, and proven
  here to cover focus falling to `<body>` while the content changes), `ui--overlay` keeping a
  trigger's existing `aria-controls`, `ui--roving-focus`'s `pageStep`, and an id on Field's
  label. Recorded in the owning specs in `8f606c4`.
- Built the option model in `d16bd8a`: `Ui::Select::OptionSet` normalises collection, array,
  hash, grouped and enum sources, renders the native `<option>`s through Rails' own helpers,
  and matches Rails' blank, prompt and required-implicit-blank rules;
  `Ui::Select::ListboxComponent` renders the same list as `role="option"` elements. Unit
  tests hold the two renderings equal for every source.
- Enhanced it into the select-only combobox in `7c60947`: `ui--select`, the submission
  mirror, the APG select-only key table, the progressive-enhancement swap, and the docs page.
- Added search mode in `a885d9c`: the editable combobox with list autocomplete, local
  filtering (case- and diacritic-insensitive, hiding emptied groups), the empty state, the
  polite result-count announcement, and the commit-on-close rules.
- Closed both open questions on their defaults: select-only mode keeps the platform picker on
  a coarse pointer (`native_on_touch:`, default true), and the `ui_select` Capybara helper
  ships in `lib/rails_ui_kit/test_helpers.rb` with its own system test and a docs section.
- Deprecated Dropdown's `kind: :listbox` (§ Behavior, item 36): it still renders, and warns
  once per process naming `Ui::SelectComponent`, with the once-per-process behaviour pinned in
  `dropdown_component_test.rb`. Removal lands one release later.
- Fourteen system files and two unit files cover the scope: `select_keyboard`,
  `select_search`, `select_pointer`, `select_enhancement`, `select_accessibility`,
  `select_form_submission`, `select_validation`, `select_form_reset`, `select_turbo_stream`,
  `select_turbo_cache`, `select_in_modal`, `select_no_javascript` (driven by `rack_test`),
  `select_helper`, plus `select_helpers.rb`, and
  `test/components/ui/select_component_test.rb` and `select_options_test.rb`.

## In progress

None. The next units in this scope's line are both deliberately later: removing Dropdown's
`kind: :listbox` one release on, and building remote search behind `search_url:`
(§ Behavior, items 27–31), which the v1 API is already shaped for.

## Last green checkpoint

2026-09-14, on the uncommitted Field/Turbo/accessibility work over `a885d9c`:
`bundle exec rake test` 347 runs / 992 assertions, `bundle exec rubocop` 105 files clean, and
every `test/system/` file run on its own. Select's own files: `select_keyboard` 14,
`select_search` 16, `select_pointer` 7, `select_enhancement` 11, `select_accessibility` 7,
`select_form_submission` 4, `select_validation` 4, `select_form_reset` 3,
`select_turbo_stream` 4, `select_turbo_cache` 3, `select_in_modal` 4, `select_no_javascript` 5,
`select_helper` 7 — 0 failures throughout.

## Dead ends

- A hidden input, a form-associated custom element and customizable `<select>` were all
  weighed against the mirrored native select in § Behavior, item 1's table before any code
  existed; each loses something the platform gives for free.
- Replaying a character typed at a closed Select through a `requestAnimationFrame` after
  opening: a second character can arrive first, so "ne" searched "en". Characters are held
  until the overlay reports the popup open, then replayed in order.
- Driving the popup's activation from a frame rather than from `ui--overlay:opened`: Escape
  and outside clicks are the browser's light dismiss, which never passes through the
  controller's own `close()`, so visual focus was left set on a closed listbox.
- `(pointer: coarse)` cannot be emulated through CDP's `Emulation.setEmulatedMedia`; touch
  emulation plus mobile device metrics is what actually makes it match.

## Corrections

- § Behavior, item 17's key table said Escape on a closed search field clears it, transcribed from the APG editable-combobox example. Here the value lives in the select, not in the text field, so clearing the text would either strand an empty field over a real value (breaking § Business rules, rule 1) or clear the selection — making the cancel key destructive, dispatching `input` and `change` from a "never mind" keystroke, diverging from select-only mode where a closed Escape does nothing, and behaving differently depending on whether the caller offered a blank option. Escape now restores the field's text to the selected option's label and changes nothing else; clearing a choice is what `include_blank:` and `prompt:` are for. Recorded in the key table and in prose under item 17 — tasteable — decider
- § Assumptions' first prerequisite described `ui--overlay` as it stood before `8446865`, which had already added `moveFocus`. What the prerequisite actually needed — that focus landing on `<body>` while the content changes is not pulled into the popup — was already true, and is now covered by a test rather than assumed — provable — implementer
