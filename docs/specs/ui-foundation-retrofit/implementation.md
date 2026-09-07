# Implementation notes — ui-foundation-retrofit

Per-component migration detail supporting `spec.md`. This file is not authoritative
over `spec.md` — where they disagree, `spec.md` wins. Nothing here is a new
Business rule or Acceptance check; it's the mechanical breakdown `spec.md`
deliberately deferred to stay readable in one sitting.

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

## Ui::ConfirmDialogComponent

- **Tokens.** `wrapper_class`'s `bg-white`/`dark:bg-gray-800`, `footer_class`'s
  `bg-gray-100`/`dark:bg-gray-700/25`, `title_class`'s `text-gray-900`/`dark:text-
  white`, `message_class`'s `text-gray-500`/`dark:text-gray-400`, `confirm_class`'s
  `bg-red-600`/`hover:bg-red-500`, `cancel_class`'s `bg-white`/`dark:bg-white/10`/
  `text-gray-900`, `icon_wrapper_class`'s `bg-red-100`/`dark:bg-red-500/10`,
  `icon_class`'s `text-red-600`/`dark:text-red-400` — every one of the nine
  `*_class` `DEFAULTS` entries is a hardcoded literal; all nine move to tokens
  (`confirm`/`icon` map to `destructive`, the rest to `popover`/`card`/`muted`
  family, decided at implementation).
- **`Ui::Base`/API break — the largest one in this scope.** `DEFAULTS` and
  `**overrides` are deleted. Replacement: each of the nine visual parts becomes a
  `Ui::Base`-derived class list, overridable by passing `class:` to that part
  (mechanism matches whatever slot API `ui-component-base` ships — this scope
  consumes it, doesn't invent it). **Old constructor calls break**:
  `Ui::ConfirmDialogComponent.new(confirm_class: "btn-danger", cancel_class:
  "btn-ghost", ...)` no longer works as written. `id`, `confirm_label`,
  `cancel_label` are unaffected (not classes). `README.md`'s "Confirm dialog
  theming" section documents the old shape verbatim and must be rewritten to the
  new one, not patched.
- **Primitives.** Presence + overlay-stack, same as Modal (native `<dialog>` +
  `showModal()`/`close()`). No positioning — it's centered, not trigger-relative.
- **Regression.** `turbo_confirm_controller.js` depends on `Ui::ConfirmDialogComponent`
  being rendered with `id="default-confirm"` and on `dialog_controller.js` installing
  `window.defaultConfirmDialog()`/`window.customConfirmDialog()` — none of that
  changes here; the id and the dialog controller's global-hook contract are the
  regression check, independent of the class-override break above.
- **Test impact.** `confirm_dialog_component_test.rb`'s "applies custom button
  classes and labels" and "title and message classes are applied" tests assert the
  exact keyword arguments this scope deletes — **full rewrite required**, not an
  update.

## Ui::ToastComponent / Ui::ToastContainerComponent

- **Tokens.** Toast shell: `bg-white dark:bg-gray-800` → token. Close button:
  `bg-white dark:bg-gray-800`/`text-gray-400`/`hover:text-gray-500`/`focus:outline-
  blue-500` → tokens. Per-type colors (`bg_light_class`/`bg_dark_class`/
  `text_color_class`, each a `case` over `success/error/notice-alert/info` returning
  `green/red/orange/blue` literals) → the semantic mapping decided in the Open
  question in `spec.md`/`open-questions.md`; **do not implement this ahead of that
  decision**. ToastContainer's `z-[70]` → the one static stacking value this scope
  documents (see spec.md Behavior — the container is not an overlay, joins no stack,
  and no z-index can put it above a top-layer `<dialog>`; whether it is promoted with
  `popover` is an open question).
- **`Ui::Base`.** `bg_light_class`/`bg_dark_class`/`text_color_class`'s `case`
  statements become a variant lookup keyed on `type`.
- **Primitives.** Toast's own enter/leave choreography
  (`enterFromValue`/`enterToValue`/`leaveFromValue`/`leaveToValue`, driven by
  `toast_controller.js`) is a presence-primitive candidate, but toasts self-dismiss
  on a timer independent of any trigger — confirm at implementation whether the
  presence primitive's open/closed/closing model fits a self-timed, container-
  appended element, or whether Toast keeps its own `self-destruct` timer logic
  alongside a thinner presence hook for the enter/exit classes only.
- **Regression — the tightest coupling in this scope.**
  `toast_container_controller.js` selects cloned template content by
  `[data-ui--toast-target="title"|"body"|"timer"]` and writes
  `data-ui--toast-self-destruct-value` directly onto the clone before insertion.
  **These `data-ui--toast-target` strings must not change** — they are the contract
  between `ToastComponent`'s markup (used both server-rendered and as the
  `<template>` source `ToastContainerComponent` clones) and
  `toast_container_controller.js`'s DOM queries, which are not aware of Stimulus
  target registration on cloned nodes. Same for `window.triggerToast(type, message)`
  and the `rails-ui-kit:toast` document event — both untouched by this scope,
  verified by the regression test in `spec.md`'s Acceptance checks.
- **Test impact.** `toast_container_component_test.rb` asserts the literal
  `bg-red-100` — breaks the moment the semantic-color decision lands and must be
  rewritten to assert a token class instead. `toast_component_test.rb` (spot-read in
  full) asserts only `data-*` attributes, `role`, `aria-live`, and text content — no
  hardcoded-class assertions found, low impact.

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
  consumed in `hint` mode only, for top-layer placement — a tooltip isn't
  focus-trapped, dismissed by Escape, or part of nested dismiss order — and `z-50` is
  deleted rather than replaced by a scale value.
- **Public API break.** None expected to the Ruby constructor (`text`, `placement`,
  `offset`).
- **Test impact.** `tooltip_component_test.rb` asserts `pointer-events-none` — a
  structural class, unaffected by tokenization.

## JS controller cleanup summary

- **Delete:** the `@floating-ui/dom` import and every `computePosition`/`flip`/
  `shift`/`offset`(/`arrow`) call in `dropdown_controller.js`, `popover_
  controller.js`, `tooltip_controller.js`.
- **Delete:** `modal_controller.js`'s `translateInClasses`/`translateOutClasses`
  switch statements and the `open`/`performClose` `setTimeout` choreography.
- **Delete:** the duplicated `clickOutsideHandler`/`escapeHandler`/`scrollHandler`
  triplet from `dropdown_controller.js` and `popover_controller.js` once overlay-
  stack owns outside-click/Escape/reflow.
- **Keep, untouched:** `dialog_controller.js`, `form_change_controller.js`,
  `turbo_confirm_controller.js`, `turbo_disable_with_controller.js`,
  `dark_mode_controller.js`, `toast_container_controller.js` (its template-clone and
  global-function logic is unchanged; only the markup it clones changes).

## Documentation debt checklist

- `README.md`: add Popover and Tooltip rows to the component table; rewrite
  "Confirm dialog theming" to the new per-part `class:`-slot API; audit the
  "Overriding" section's claim about CSS override-by-specificity against the new
  token/class names.
- `PLAN.md`: delete (see `spec.md` Behavior for the reasoning).
- `CHANGELOG.md`: new `[0.3.0]` entry — every rendered-class change, the
  `ConfirmDialogComponent` constructor break with a before/after snippet, the
  `ui--modal` `dialog` target → `ui--overlay` `content` target rename (a public
  data-attribute break), the z-index/stacking change, and a pointer to the rewritten
  README section.
- `examples/app/views/docs/confirm_dialog.html.erb`: almost certainly demonstrates
  the old `*_class` keyword API (README does) — update to the new one.
- `examples/app/views/docs/{modal,dropdown,popover,tooltip,toast}.html.erb`: audit
  for any inline reference to old class names; otherwise no content change required
  since the components' `renders_one`/content-block API is unaffected.
