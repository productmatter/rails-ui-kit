## State
ready-for-review

Built on 2026-09-15. Modal, Dropdown, Popover and Tooltip inherit `Ui::Base`, read colour
from the tokens, merge `class:`, stamp `data-slot`, and raise on an unknown closed-set value in
development and test. Dropdown runs on `ui--overlay` in layer mode. Every agent-loopable
acceptance check passes. What remains is outside this build: the judgeable review, Jonathan's
three human gates, the consumer-repo pins, the v0.3.0 `CHANGELOG.md` migration entry (drafted
for the orchestrator, not written into the file), and deleting `PLAN.md`, which § Behavior
specifies and this build did not do.

## Done
- Pinned the four components' output at HEAD before changing anything:
  `test/components/ui/overlay_render_pin_test.rb`, RP1–RP4. The pins assert structure,
  Stimulus wiring, ARIA and every non-palette class, and list the classes this scope removes
  beside each pin. None was edited afterwards.
- `Ui::Base`: raises on an undeclared `*_class:`/`*_classes:` keyword, resolves closed-set
  keywords through its unknown-variant handling (`resolve_option`), and warns about a
  deprecated class keyword through `RailsUiKit.deprecator`, which the engine registers.
- Modal: on `Ui::Base`, `data-slot="modal"` and `class:` on the `<dialog>`; `position:` is a
  `class_variants` axis; `max_width:` is deprecated and merged; the prompt values are renamed
  `unsavedChangesTitle`/`unsavedChangesMessage`. `BASE_CLASSES` and its `backdrop:` entries
  are unchanged, because Confirm Dialog reads them.
- Popover and Tooltip: on `Ui::Base` and the tokens; placement from `Ui::Placement`, which
  takes symbols; `panel_classes:` deprecated in favour of `with_panel(class:)`.
- Dropdown: on `Ui::Base` and `ui--overlay` (layer mode). It binds its own trigger and emits
  the overlay's events; its slot is `panel`, with `with_menu` a deprecated alias;
  `content_classes:` is deprecated; `kind:` and `placement:` raise on an unknown value. It
  warns about a missing `ui--anchor` only when opening, no longer on every connect.
  `ui--overlay` gained `closeNow` for its Tab.
- Modal warns once, after its element's other controllers have connected, when `ui--overlay`
  is missing, as Dropdown, Popover and Tooltip do: hand-written 0.2.0 markup had never opened
  in silence (M9, M10).
- Tests: new unit tests for every behaviour above; M8 (the renamed values reach the prompt),
  and DD22–DD25 (no false warning, the self-bound trigger, lifecycle events, a menu inside a
  modal). Each was run against the code without its change and failed.
- `UPGRADING.md` § 2, the overlay-markup section: verbatim 0.2.0 markup was run on this branch
  to write what it now does, and every "after" block was injected into a browser and opened
  with no console warnings.
- Docs: the Dropdown, Popover, Tooltip and Modal pages' previews, option and slot tables, and
  their usage snippets in `code_examples_helper.rb`.

## In progress
None.

## Last green checkpoint
2026-09-15: unit lane green; rubocop clean; the browser lane green file by file.

## Dead ends
- Naming Dropdown's slot `content`, as directed: ViewComponent reserves the name, and
  `renders_one :content` raises at class load. Named `panel`, which is what the directive's
  own reason, reading beside Popover's `panel`, asks for.

## Corrections
- The acceptance checks named `turbo_confirm_regression_test.rb` and `modal_form_change_regression_test.rb`, neither of which exists. The contracts are pinned by `confirm_dialog_test.rb` (CD9), `turbo_confirm_test.rb`, `modal_turbo_cancel_test.rb` and `modal_test.rb`, and the checks now name those files — provable — implementer
- The palette acceptance check failed on Modal's `backdrop:bg-black/50`. The orchestrator ruled on 2026-09-15 that the scrim stays and the check allows it by name — tasteable — decider
- `dropdown_test.rb` read `aria-expanded` and focus straight after Escape, but `ui--overlay` closes a layer a frame later and returns focus once the exit animation ends. Those reads now wait, through the helpers `popover_test.rb` already used. The "stays open" reads stay immediate, with a settle before the one that follows Escape. DD19 and DD21 re-point from the removed `opacity-100 scale-100` classes to `data-state="open"`; DD21's wrapper keeps `ui--overlay` while losing `ui--anchor`, as its scenario says; DD20's clone turns flip off, as DD19's does, because a viewport-positioned panel at the page's foot flips — provable — implementer
- The first cut regressed: a trigger press during the exit animation stayed closed, as `ui--overlay#toggle` has it, where Dropdown reopens (DD2, DD8, DD13). Dropdown now reads the open value itself — provable — implementer
