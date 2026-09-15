# Implementation notes — ui-foundation-retrofit

Per-component migration detail supporting `spec.md`. This file is not authoritative
over `spec.md` — where they disagree, `spec.md` wins. Nothing here is a new
Business rule or Acceptance check; it's the mechanical breakdown `spec.md`
deliberately deferred to stay readable in one sitting.

Written before the build. Where it predicts no public API change or no Dropdown test impact,
the build differs, and `spec.md` § Behavior records what shipped on 2026-09-15.

## Ui::ModalComponent

- **Tokens.** `bg-white dark:bg-gray-900` in `BASE_CLASSES` → a token utility
  (`bg-popover` or `bg-card`, decided against the component's role, not guessed here).
  Backdrop's `bg-black/50` is a scrim, not a themed surface — check whether the token
  set treats scrims specially or whether `bg-black/50` is an accepted non-token
  literal (it isn't a *palette* class in the rule-1 sense; flag if `Ui::Base`
  disagrees).
- **`Ui::Base`.** `BASE_CLASSES`/`POSITION_CLASSES`/`dialog_classes` string-join
  becomes a `class_variants` variant definition keyed on `position`, merged through
  `tailwind_merge` with any caller `class:`.
- **Primitives.** Presence primitive replaces `modal_controller.js`'s
  `translateInClasses`/`translateOutClasses`/`setTimeout` choreography; overlay-stack
  primitive replaces the manual `document.body.style.overflow` scroll lock; the
  `z-[61]` / backdrop `z-[60]` literals are deleted outright, since a `<dialog>` opened
  with `showModal()` is in the top layer and no z-index applies. Positioning
  primitive is **not** consumed — Modal doesn't float relative to a trigger.
- **CSS.** The 16 transform classes in `components.css` are kept, re-targeted from
  `modal-<position>-hidden/visible` class-swap to selectors keyed off the presence
  primitive's `data-state` attribute (exact selector shape is `Ui::Base`/primitive
  implementation detail, not this scope's to dictate further).
- **Public API break.** None to the Ruby constructor (`position`, `track_changes`,
  `close_on_backdrop`, `max_width` all stay). The break is in rendered class names
  and in `data-controller`/`data-*` attributes if the presence/overlay-stack
  primitives rename them — any consumer CSS written against the literal old class
  names breaks.
- **Regression.** `trackChanges` ↔ `form_change_controller`'s `form:changed`/
  `form:pristine` events must survive untouched — this is the scope's most
  load-bearing regression check.
- **Test impact.** `modal_component_test.rb` asserts `modal-center-hidden`/
  `modal-right-hidden` literal class names and `max-w-2xl` passthrough. Survives if
  the class *names* are kept (only their CSS targeting changes per above); breaks if
  the primitive renames them, in which case the test's literal strings move with the
  rename.

## Ui::DropdownComponent

- **Tokens.** No hardcoded palette classes today (`content_wrapper_classes` uses
  only structural/utility classes) — this component's contribution to the "zero
  literals" check is confirming that stays true after `Ui::Base` adoption, not
  fixing an offender.
- **`Ui::Base`.** `content_wrapper_classes`'s array-join becomes a variant/merge call.
- **Primitives.** Positioning primitive replaces `dropdown_controller.js`'s direct
  `computePosition`/`flip`/`shift`/`offset` calls — **delete the `@floating-ui/dom`
  import**. Presence primitive replaces the manual `hidden`/`opacity-0`/`scale-95`
  classlist toggling and the `setTimeout(..., 100)` hide delay. Overlay-stack
  primitive replaces the hand-rolled `clickOutsideHandler`/`escapeHandler`/
  `scrollHandler` triplet; the `z-50` literal is deleted — `popover="auto"` puts the
  content in the top layer, and the stack module's single fallback value covers
  browsers without `popover`.
- **Public API break.** None expected to the Ruby constructor (`kind`, `placement`,
  `offset`, `match_width`, `content_classes`). The three accessibility modes
  (menu/listbox/dialog) and their keyboard nav (`handleKeyNavigation`) either move
  into the group-navigation primitive (owned by `ui-positioning-and-navigation`, not
  this scope) or stay component-local — if `ui-positioning-and-navigation` hasn't
  shipped group nav by the time this scope executes, that's a real dependency-order
  question to flag at implementation time, not resolved here.
- **Test impact.** Low — `dropdown_component_test.rb` wasn't seen asserting
  hardcoded classes in the grep pass.

## Ui::ConfirmDialogComponent — handed off

Its tokens, `Ui::Base` adoption, class keywords and buttons moved to
`ui-confirm-dialog` on 2026-09-14, when the orchestrator ratified that scope. The notes
that stood here were deleted rather than left to contradict it. One example: that scope
keeps eight class keywords, merged instead of replacing (its `open-questions.md`), where
this file said all nine were deleted.

What stays here is already done: the dialog opens and closes through `ui--overlay`
(presence and overlay stack), with no positioning.

## Ui::ToastComponent / Ui::ToastContainerComponent — handed off

All of Toast moved to `ui-toast` on 2026-09-14, when the orchestrator ratified that
scope. That covers the tokens, including the `success`/`warning`/`info` kit extensions,
`Ui::Base`, Primitive D, the container's stacking (now `popover="manual"`, verify-first),
and the template-clone contract, which that scope deliberately changes. None of it is this
scope's work any more.

## Ui::PopoverComponent

- **Tokens.** `panel_wrapper_classes`'s `bg-white dark:bg-neutral-900` and
  `border-neutral-200 dark:border-neutral-700` → tokens (`bg-popover`/
  `border-border` are the shadcn-convention fits, confirmed at implementation).
- **`Ui::Base`.** `panel_wrapper_classes`'s array-join → variant/merge call, `panel_classes` passthrough becomes the caller-`class:` slot.
- **Primitives.** Positioning primitive replaces `popover_controller.js`'s direct
  `computePosition`/`flip`/`shift`/`offset` — **delete the `@floating-ui/dom`
  import**. Presence primitive replaces the manual `hidden`/`opacity-0`/`scale-95`
  toggling and `setTimeout(..., 100)`. Overlay-stack primitive replaces the
  hand-rolled `clickOutsideHandler`/`escapeHandler`/`scrollHandler`; the `z-50`
  literal is deleted, as for Dropdown.
- **Public API break.** None expected to the Ruby constructor (`placement`,
  `offset`, `panel_classes`).
- **Test impact.** `popover_component_test.rb` asserts caller-supplied
  `panel_classes` values (`w-64`, `p-4`) pass through — these are structural, not
  palette, classes, so they're unaffected by tokenization but must still resolve
  correctly through whatever `class:`-merge slot replaces `panel_classes`.

## Ui::TooltipComponent

- **Tokens.** `tooltip_classes`'s `bg-neutral-900 text-white dark:bg-white
  dark:text-neutral-900` and the arrow's `bg-neutral-900 dark:bg-white` → tokens
  (likely `bg-foreground text-background` or the inverse — a tooltip is
  conventionally the one place shadcn intentionally inverts foreground/background;
  confirm at implementation rather than assuming `popover`).
- **`Ui::Base`.** `tooltip_classes`'s array-join → variant/merge call.
- **Primitives.** Positioning primitive replaces `tooltip_controller.js`'s direct
  `computePosition`/`flip`/`shift`/`offset`/`arrow` — **delete the
  `@floating-ui/dom` import**, including the `arrow` middleware's manual
  `staticSide` placement math. Presence primitive replaces the manual
  `hidden`/`opacity-0` toggling and `setTimeout(..., 100)`. The overlay primitive is
  consumed in `hint` mode only, for top-layer placement. A tooltip isn't
  focus-trapped or part of nested dismiss order. It **is** dismissable by Escape
  without moving focus (WCAG 1.4.13). Consuming that Escape calls `preventDefault()`,
  so a surrounding native `<dialog>` doesn't close with it. This shipped in `78d4c64`
  and the retrofit keeps it. `z-50` is deleted rather than replaced by a scale value.
- **Public API break.** None expected to the Ruby constructor (`text`, `placement`,
  `offset`).
- **Test impact.** `tooltip_component_test.rb` asserts the tooltip does **not** carry
  `pointer-events-none`, so the pointer can move onto it (WCAG 1.4.13). `78d4c64`
  flipped the old assertion, which had protected the defect. The class is structural,
  so tokenization doesn't affect it.

## JS controller cleanup summary

- **Delete:** the `@floating-ui/dom` import and every `computePosition`/`flip`/
  `shift`/`offset`(/`arrow`) call in `dropdown_controller.js`, `popover_
  controller.js`, `tooltip_controller.js`.
- **Delete:** `modal_controller.js`'s `translateInClasses`/`translateOutClasses`
  switch statements and the `open`/`performClose` `setTimeout` choreography.
- **Delete:** the duplicated `clickOutsideHandler`/`escapeHandler`/`scrollHandler`
  triplet from `dropdown_controller.js` and `popover_controller.js` once overlay-
  stack owns outside-click/Escape/reflow.
- **Keep, untouched by this scope:** `form_change_controller.js`,
  `turbo_disable_with_controller.js`, `dark_mode_controller.js`. `dialog_controller.js`
  and `turbo_confirm_controller.js` change under `ui-confirm-dialog`, and
  `toast_controller.js` and `toast_container_controller.js` under `ui-toast`.

## Documentation debt checklist

- `README.md`: add Popover and Tooltip rows to the component table; audit the
  "Overriding" section's claim about CSS override-by-specificity against the new
  token/class names. "Confirm dialog theming" is `ui-confirm-dialog`'s to rewrite.
- `PLAN.md`: delete (see `spec.md` Behavior for the reasoning).
- `CHANGELOG.md`: new `[0.3.0]` entry — every rendered-class change, the
  `ui--modal` `dialog` target → `ui--overlay` `content` target rename (a public
  data-attribute break), the z-index/stacking change. Toast and Confirm Dialog entries
  belong to their own scopes.
- `examples/app/views/docs/{modal,dropdown,popover,tooltip}.html.erb`: audit
  for any inline reference to old class names; otherwise no content change required
  since the components' `renders_one`/content-block API is unaffected.
