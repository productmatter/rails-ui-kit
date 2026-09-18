## State

building

Reshaped 2026-09-18 (Jonathan Simmons): search mode moves from the APG editable combobox
to a trigger button with the search field in its popup — § Behavior, items 13, 17, 18 and
24, § Business rules 4 and 5, and the search, pointer, validation and accessibility
acceptance checks are amended; the old shape is retired, not kept beside the new one. v1
as built on 2026-09-14 stands for select-only mode, the Rails option API, Field, Turbo and
the submission model. Search mode is being rebuilt to the amended contract and
`select_search_test.rb` rewritten to item 17's new table. Jonathan's three human gates
remain, and the VoiceOver gate now also judges the new shape. Remote search stays designed
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
- Removed Dropdown's `kind: :listbox` (§ Behavior, item 36), on the decider's confirmation
  that no live consumer renders it: dropped from `KINDS`, with the fallback to `:menu` for
  an unrecognised kind pinned in `dropdown_component_test.rb`. Landed in the same release as
  Select rather than deprecated for one.
- Fourteen system files and two unit files cover the scope: `select_keyboard`,
  `select_search`, `select_pointer`, `select_enhancement`, `select_accessibility`,
  `select_form_submission`, `select_validation`, `select_form_reset`, `select_turbo_stream`,
  `select_turbo_cache`, `select_in_modal`, `select_no_javascript` (driven by `rack_test`),
  `select_helper`, plus `select_helpers.rb`, and
  `test/components/ui/select_component_test.rb` and `select_options_test.rb`.

## In progress

Search mode to the 2026-09-18 shape (§ Behavior, item 17): a trigger button; the search
field first in the popup; focus in on open and back on close through `ui--overlay`'s
`initialFocus` and focus return, with a Tab-close that lets focus move on; the show-options
button and `rails_ui_kit.select.show_options_label` removed and `search_placeholder` added;
`Ui::Select::Primitives` carrying the mode difference as values, as before;
`select_search_test.rb` rewritten to the new key table, with the pointer, validation and
accessibility checks amended; the docs page's "With search" section and behaviour notes
brought to the new shape. Remote search (items 27–31) stays deliberately later.

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
- § Behavior, item 2 described the coarse-pointer swap as `ui--select` reading `ui--media-query`'s `data-media-matches` and marking the root `data-enhanced="false"`. Primitive F was removed on 2026-09-14 on the decider's ruling that a component with a media-query dependency carries the query in its own CSS. The swap is now `pointer-coarse:` / `not-pointer-coarse:` on the combobox and the select (Tailwind 4, verified against a real compile), the root stays `data-enhanced="true"` once the controller connects, and `select_controller.js` owns the `matchMedia` listener that flips the select's `aria-hidden` and `tabindex`. Proved in Chrome's accessibility tree in both pointer states (`select_enhancement_test.rb`, SE8) — tasteable — decider
- The parent table (`ui-component-library` § Scopes) named this scope `ratified`; this file's own State is `ready-for-review` and names the three outstanding human gates. Corrected the parent table to match, since none of the three is recorded here as closed — provable — implementer
