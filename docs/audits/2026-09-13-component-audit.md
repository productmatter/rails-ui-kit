# Component audit, 2026-09-13

Four read-only audits covered every component, controller and the gem plumbing.
Behaviour was driven in headless Chrome against the `examples/` docs app.

- **CONFIRMED** means reproduced in the browser or by running code.
- **SUSPECTED** means reasoned from reading.
- Headline findings were re-checked against source before this was written.
- Issues already covered by a spec are left out unless the audit found a new trigger.

Tags on each finding:

- **Live** is on `main` today, so `rails_foundation` and `bonnie-rails` have it,
  since both track `main` unpinned. **Unreleased** exists only on `feature/ui-kit-foundation`.
- Severity: `breaks` (breaks users today), `a11y`, `latent`, `polish`.
- Fix size: S, M or L.

## Cross-cutting patterns

These explain most of the individual findings. Fixing them one component at a time,
without naming the pattern, is how they came back.

1. **Turbo's page cache and element removal are unhandled.** No controller listens for
   `turbo:before-cache`, and several leak state when their element is removed. Pressing
   Back breaks disable-with, Tooltip, Dropdown, Popover, Modal and ConfirmDialog in
   different ways. Closing a Modal with a Turbo Stream leaks the scroll lock and focus.
2. **The wrapper `<div>` is treated as the trigger.** Dropdown, Popover and Tooltip wrap the
   caller's control in a `<div>`, then put ARIA state, focus, event binding and
   positioning on that `<div>`. `f3b70e8` fixed Dropdown's ARIA and focus only. In any
   block layout the wrapper is full-width, so hit areas and `*-end` placements are wrong.
3. **Accessible names, descriptions and state are missing.** Modal has no name.
   ConfirmDialog's message is never read. Tooltip describes the wrong element. Dark mode
   never exposes whether it's on.
4. **Focus defaults are unsafe.** ConfirmDialog focuses the destructive button, so Enter
   submits; its tab order is reversed; Cancel has no focus ring. Button's ring is below
   3:1 contrast and disappears entirely in forced-colors mode.
5. **No browser tests exist.** Every CONFIRMED behavioural bug here would have been caught
   by one. Some unit tests assert a defect as correct (`pointer-events-none` on Tooltip).
6. **The install path is broken for new consumers.** The generator's CSS import cannot
   resolve, and its JS registration throws on a default `rails new` importmap app.
7. **Theme integration with host apps is unsolved.** Unlayered kit tokens override a
   host's theme, `dark:` and the tokens disagree about what dark means, and tokens don't
   reach Tailwind 3 or bundler setups.

## Findings by component

### Modal: Live

- **M1** An invisible backdrop blocks every click after close when the modal isn't inside a
  turbo-frame. `breaks` · CONFIRMED · S. On close, markup is removed only inside a frame
  (`modal_controller.js:109-114`), leaving `fixed inset-0 z-[60]` behind. bonnie renders
  modals this way (`account/overview_component.html.erb:121,144`).
- **M2** Closing via Turbo Stream leaves the page scroll-locked and focus on `<body>`.
  `breaks` · CONFIRMED · S. `disconnect()` releases nothing (`:24-39`).
- **M3** After Back, the modal comes back as a broken non-modal `<dialog open>`:
  `showModal()` throws, the stale backdrop blocks clicks, and scroll stays locked.
  `breaks` · CONFIRMED · S.
- **M4** An unsaved-changes modal traps the user open when the confirm dialog is missing or
  broken. `breaks` · CONFIRMED · S. The error isn't caught (`:75-92`); reachable via CD2.
- **M5** `trackChanges` doesn't guard Turbo visits, so the form is silently lost on Back.
  `latent` · CONFIRMED · M.
- **M6** Closing empties the whole enclosing turbo-frame, not just the modal.
  `latent` · CONFIRMED · S (`frame.innerHTML = ''`).
- **M7** No accessible name and no API to set one. `a11y` · CONFIRMED · S.
- **M8** Swapping modals within 300ms unlocks scroll under the second one. `latent` ·
  CONFIRMED. A new trigger for the scroll-lock reset already covered by
  `ui-presence-and-overlay-stack`.
- **M9** Escape during IME composition closes the modal. `polish` · SUSPECTED · S.
- **M10** Unsaved-changes strings are hardcoded English; `h-screen`/`90vh` hide footers
  behind mobile Safari's toolbars. `polish` · S.

Improvements:

- **Cheap:** `title:`/`labelledby:` and `initial_focus:`; release scroll lock and restore
  focus on `disconnect`; a `turbo:before-cache` teardown; remove only the modal's own
  element; `dvh` units; `transition-[opacity,transform]`.
- **Real work:** a client-side open/close API with events, so a modal can render closed
  without a server round trip; a Turbo navigation guard for dirty forms; header, body and
  footer slots. The planned `ui--overlay` covers most of this.

### ConfirmDialog: Live

- **CD1** Confirm and Cancel do nothing under a Content Security Policy without
  `unsafe-inline`. `breaks` for CSP hosts · CONFIRMED · S. Inline `onclick`
  (`confirm_dialog_component.html.erb:25,28`); fix with `<form method="dialog">`.
- **CD2** After Back/Forward with the dialog open, every later confirm throws
  `InvalidStateError` until a full reload. `breaks` · CONFIRMED · S.
- **CD3** Focus lands on the destructive Confirm button, so Enter submits the action.
  `breaks`/`a11y` · CONFIRMED · S. bonnie routes every destructive `button_to` through it.
- **CD4** Tab order is the reverse of visual order (`sm:flex-row-reverse`).
  `a11y` · CONFIRMED · S (WCAG 2.4.3).
- **CD5** The message is never announced: no `aria-describedby`, no `role="alertdialog"`.
  `a11y` · CONFIRMED · S.
- **CD6** Cancel has no visible focus indicator; an always-on outline replaces the ring.
  `a11y` · CONFIRMED · S (WCAG 2.4.7).
- **CD7** Two concurrent callers share one dialog, and a single click resolves both.
  `latent` · CONFIRMED · M.
- **CD8** The controller overwrites text with hardcoded English defaults, and no
  `title:`/`message:` API exists. `polish` · CONFIRMED · S.
- **CD9** `customConfirmDialog('2fa-confirm')` throws on an id that isn't a valid selector.
  `latent` · CONFIRMED · S.
- **CD10** The promise never settles if the dialog is removed while open. `latent` · SUSPECTED.

Improvements:

- **Cheap:** per-call confirm/cancel labels; a neutral (non-destructive) variant, since
  today "Publish post" gets a red button and a warning icon.
- **Medium:** an options argument for `customConfirmDialog`; a Ruby helper for the
  `data-turbo-confirm-*` attributes.
- **Real work:** replace the `window` globals with a module export plus events.

### turbo_confirm controller: Live

- **TC1** `data-turbo-confirm-title` is ignored on links and forms, including the docs
  demo. `breaks` (documented feature) · CONFIRMED · S for forms, S–M for links.
- **TC2** Silently inert on Turbo versions without `Turbo.config.forms`; the gemspec
  doesn't constrain `turbo-rails`. `latent` · SUSPECTED · S.

Improvements: fold into `ui--dialog`, so one feature doesn't need two controllers mounted together.

### Dropdown: Live

- **DD1** Back after using a Turbo-link menu item shows the menu, pulls focus into it,
  then hides it and leaves focus on `<body>`. `breaks` · CONFIRMED · S. The open state
  persists in a data attribute that Stimulus replays before `connect()`.
- **DD2** Choosing a menu item doesn't close the menu. `breaks` · CONFIRMED · S.
- **DD3** Opening one dropdown or popover doesn't close another that's open.
  `breaks` · CONFIRMED · S. `stopPropagation()` in `toggle()` hides the click from other
  instances' outside-click listeners.
- **DD4** In a block layout, `bottom-end` and `match_width` measure the full-width wrapper:
  the menu lands 517px from its button, and `match_width` gives 598px for an 81px button.
  `breaks` · CONFIRMED · S (`dropdown_controller.js:92,95`).
- **DD5** Tab while open leaves the menu open, and every item is a tab stop.
  `a11y` · CONFIRMED · S to close on Tab; a single tab stop is already specced.
- **DD6** `kind: :dialog` moves no focus and has no accessible name. `a11y` · CONFIRMED · S.
- **DD7** The document-level Escape handler pulls focus back to the trigger even after
  focus has left; it ignores `isComposing` and `defaultPrevented`. `a11y` · CONFIRMED · S.
- **DD8** Close then reopen within 100ms leaves `aria-expanded="true"` with the menu hidden.
  `breaks` · CONFIRMED · S. Already specced (presence), but live until then.
- **DD9** Arrow keys on the closed trigger don't open it. `polish` · CONFIRMED · S.

Improvements:

- **Cheap:**
  - The component wires `click->ui--dropdown#toggle` itself.
  - Validate `placement`; `kind: nil` currently raises.
  - Cancel the pending `focusFirstItem` timer on close.
  - Make the docs claim match the keyboard support.
  - Drop `href="#"` in the demo.
- **Hide or build:** `:listbox` has no selection model at all. S to hide until Select
  ships, L to do properly.

### Popover: Live

- **PO1** Same wrapper defect as the Dropdown fix in `f3b70e8`: ARIA sits on the wrapper,
  and Escape from inside the panel drops focus to `<body>`. `aria-haspopup="true"` means
  "menu" and should be `"dialog"`; `aria-controls` is missing. `a11y` · CONFIRMED · S.
- **PO2** Opening one popover doesn't close another (see DD3). `breaks` · CONFIRMED · S.
- **PO3** Block-layout geometry and hit area measure the full-width wrapper (see DD4);
  clicking empty space beside the button toggles it. `breaks` · SUSPECTED · S.
- **PO4** `preventDefault()` on any click inside the wrapper cancels the default action of
  link, checkbox or submit triggers. `latent` · SUSPECTED · S.
- **PO5** Stale open state after Back. `polish` · SUSPECTED · S.

Improvements: `role="dialog"` with a `label:` keyword; document `ui--popover#close`; wire
the trigger the same way in Popover and Dropdown.

### Tooltip: Live

- **TT1** Screen readers never hear the tooltip: `aria-describedby` goes on the wrapper,
  not the control (`tooltip_controller.js:16`). `a11y` · CONFIRMED · S.
- **TT2** Escape can't dismiss it (WCAG 1.4.13). `a11y` · CONFIRMED · S.
- **TT3** The pointer can't move onto the tooltip without it hiding (1.4.13).
  `a11y` · CONFIRMED · M. `tooltip_component_test.rb:61` asserts the cause,
  `pointer-events-none`.
- **TT4** It hides while the trigger still has focus, because hover and focus aren't tracked
  separately (1.4.13). `a11y` · CONFIRMED · S.
- **TT5** In a block layout it centres on the full row and shows when hovering empty space
  500px from the button. `breaks` · CONFIRMED · S.
- **TT6** After Back it can come back visible with the pointer elsewhere.
  `breaks` · CONFIRMED (timing-dependent) · S.
- **TT7** Close then reopen within 100ms leaves it hidden while hovered. `breaks` ·
  CONFIRMED · S. Already specced (presence).
- **TT8** Shows on a disabled button in Chrome, but a keyboard user can never reach it.
  Document `aria-disabled`. `a11y` · CONFIRMED in Chrome · S.
- **TT9** A tap on touch both activates the button and pins the tooltip over nearby
  content. `polish` · CONFIRMED (emulated) · S.

Improvements: a ~300ms show delay, instant between adjacent tooltips; a `delay:` option;
`max-w-xs` instead of `whitespace-nowrap`; guidance on `aria-label` vs tooltip for
icon-only buttons.

**Spec correction:** `ui-foundation-retrofit/implementation.md:171-172` says a tooltip
"isn't … dismissed by Escape". That writes a WCAG 1.4.13 failure into the plan.

### Toast / ToastContainer: Live

- **TO1** `timeout: 0` means "persist" in Ruby (`toast_component.rb:55`) but "use the
  default" via `window.triggerToast` (`toast_container_controller.js:78`, `||` treats 0 as
  falsy). `breaks` · CONFIRMED · S.
- **TO2** Auto-dismiss never pauses on hover or focus (WCAG 2.2.1).
  `a11y` · CONFIRMED · S.
- **TO3** Each toast is inserted with its live-region role and text in one DOM mutation,
  which is often not announced. `a11y` · mechanism CONFIRMED, screen-reader outcome
  SUSPECTED · M.
- **TO4** `type: :alert` gets `role="status"`, not `role="alert"`. Defensible, but
  undocumented. `polish` · S.
- **TO5** `window.triggerToast` called before the container connects throws `TypeError`.
  `latent` · SUSPECTED · S.
- Clean: XSS (uses `textContent`), timer and listener cleanup, unknown types.

Improvements: `motion-reduce`; a cap or dedupe for toast floods; queue early
`triggerToast` calls; delete the redundant `sr-only` "Close" span.

### turbo_disable_with: Live

- **DW1** Back after submitting leaves the button permanently disabled on "Saving…".
  `breaks` · CONFIRMED · S. No `turbo:before-cache` handler, and the docs say to mount it
  in the layout, so it covers every form.
- **DW2** Mounting twice double-announces to screen readers. `latent` · SUSPECTED · S.
- Clean: re-enables on every `turbo:submit-end` outcome, including 422 and network errors.

### dark_mode: Live

- **DM1** Flash of the wrong theme on every load: the class is set only after Stimulus
  connects. `polish` · CONFIRMED · S (inline `<head>` script; the controller doesn't change).
- **DM2** The toggle never exposes state (`aria-pressed`); only its label changes.
  `a11y` · CONFIRMED · S.
- **DM3** Doesn't follow an OS theme change when the user has no saved preference.
  `polish` · SUSPECTED · S.
- **DM4** `localStorage` calls are unguarded; some private or embedded contexts throw.
  `latent` · SUSPECTED · S.

### form_change: Live

Clean. The 422 vs success handling is correct, and dynamically added fields are picked up.
Document that `contenteditable` isn't tracked, since `FormData` can't see it.

### Install generator, engine, gemspec: Live

- **GEN1** The generated CSS import `../../app/assets/builds/tailwind/rails_ui_kit.css`
  resolves to `app/app/assets/…`, so the host's Tailwind build fails on every v4 version
  tested. `breaks` · CONFIRMED · S (`install_generator.rb:13`, `README.md:70,273`). The
  generator test only checks the string.
- **GEN2** On a default `rails new` importmap app, the generator appends
  `registerControllers(application)` with `application` undefined, so it throws and no
  controller registers. `breaks` · CONFIRMED · S–M (`install_generator.rb:75-80`).
- **GEN3** The gemspec and CI claim Ruby ≥ 3.1, but `tailwind_merge` 1.5.5 needs ≥ 3.2.
  `latent`, but lands with this branch · CONFIRMED · S.
- **GEN4** ViewComponent 3 support is claimed but never exercised in CI.
  `latent` · SUSPECTED · S.
- **GEN5** `class_variants`' railtie adds a helper to every host view. `polish` · CONFIRMED.
- **Docs app:** no `csrf_meta_tags`, so the Turbo Confirm demo returns 422; the right-panel
  demo's icon-only close button has no accessible name.

Improvements: a generator integration test that builds real CSS and loads the JS in a
scratch app; CI for the Ruby 3.2 floor, ViewComponent 3 and Rails 7.x.

### Ui::Base: Unreleased

- **BASE1** `data: nil` or `aria: nil` wipes the component's own `data-slot`,
  `data-controller` or `aria-disabled`. `latent` · CONFIRMED · S (`base.rb:80-84`).
- **BASE2** String keys (`"class"`, `"data-slot"`, `data: {"slot" => …}`) emit duplicate
  attributes, and the wrong one wins. `latent` · CONFIRMED · S (normalise keys).
- **BASE3** Caller-wins fails against modifier-scoped defaults: a caller's `px-2` loses to
  `has-[>svg]:px-3`, and `pt-2` loses to Card's `[.border-t]:pt-6`. `latent` · CONFIRMED · M.
  Design decision.
- **BASE4** `class: ["a", {"b" => true}]` renders the hash as literal text.
  `latent` · CONFIRMED · S (`token_list`).
- **BASE5** Unknown variant values render silently broken output. `latent` · CONFIRMED · S
  (raise in development and test).
- Clean: thread safety (16 threads, 240k merges, 0 mismatches), memoization under
  inheritance, and attribute escaping.

### Button: Unreleased

- **BTN1** No focus indicator at all in forced-colors / High Contrast mode: `outline-none`
  plus a box-shadow ring. `a11y` · CONFIRMED · S (`outline-hidden`).
- **BTN2** `link` variant text is 3.83:1 in dark mode. `a11y` · CONFIRMED · S.
- **BTN3** Outline variant sets no text colour, so its text can be invisible depending on
  host context. `a11y` · CONFIRMED · S (`text-foreground`).
- **BTN4** Focus ring contrast is 2.17 light and 1.82 dark; destructive's is 1.47 in dark.
  `a11y` · CONFIRMED · S.
- **BTN5** `variant: nil` or `size: nil` raises `NoMethodError`. `latent` · CONFIRMED · S.
- **BTN6** Icon sizing overrides SVGs sized with `h-*`/`w-*` and reaches nested SVGs.
  `polish` · CONFIRMED · S.
- **BTN7** `"disabled" => true` (string key) leaves a link live; `disabled: "false"`
  disables. `polish` · CONFIRMED · S.
- Clean: disabled `<a>` is inert, target sizes pass WCAG 2.2, and other variants pass
  contrast.

Improvements: `icon-sm`/`icon-lg`; a loading state with `aria-busy`; a development warning
for icon-only buttons with no name.

### Card: Unreleased

- **CARD1** A long unbroken title (an email address) pushes the action outside the card.
  `latent` · CONFIRMED · S (`minmax(0,1fr)`, `min-w-0 break-words`).
- **CARD2** With a multi-line title, the action centres on the whole block, not the first
  line. `polish` · CONFIRMED. Known tradeoff; revisit if it bites.
- **CARD3** A title-only header gets 8px of phantom space from the empty second row.
  `polish` · CONFIRMED · S.
- **CARD4** An action-only header is 8px tall, so the button spills into the padding.
  `polish` · CONFIRMED · S.
- **CARD5** Setting a slot twice silently keeps the last one. `polish` · CONFIRMED.
- **CARD6** `[data-slot]` recolours bare borders on host elements that use `data-slot`
  (shadcn- or Headless-UI-style markup). `latent` · CONFIRMED.

Improvements: `as:` for heading level on the title; optional `aria-labelledby` from the title.

### Tokens, engine.css: Unreleased tokens, live engine

- **TOK1** Kit tokens are unlayered and imported last, so they silently override a host's
  existing `@theme` or `:root` values. `latent` · CONFIRMED · M. Decision.
- **TOK2** No `@custom-variant dark` ships, so a host's `dark:` follows the OS while the
  tokens follow `.dark`. `breaks` for affected hosts · CONFIRMED · S. Decision.
- **TOK3** Tokens don't reach Tailwind 3/Sprockets setups (`components.css` holds only the
  modal classes), and `package.json` `files` ships only JS. `latent` · CONFIRMED · S–M.
- Clean: every token Button and Card use has a `@theme inline` mapping, and the `[data-slot]`
  rule stays in the base layer whatever the host's import order.

## Spec corrections this audit requires

- `ui-foundation-retrofit/implementation.md:171-172`: tooltips must be dismissable by Escape.
- `ui-presence-and-overlay-stack`: acceptance checks for element removal without close
  (lock released, focus restored) and for `turbo:before-cache`.
- `ui-design-tokens` § Assumptions: `components.css` does not carry tokens to Tailwind 3 or
  Sprockets.
- `ui-test-harness`: move from first-in-order to first-priority. Every behavioural bug
  above would have been caught by it.
