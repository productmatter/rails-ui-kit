---
slug: ui-presence-and-overlay-stack
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: high
size: large
target_model: frontier
created: 2026-09-07
loop_budget: 8
---

## Intent

Two of the six cross-cutting behaviors named in `ui-component-library` § Scopes:
**presence** (D) and the **overlay stack** (B). They come first because everything
after them is cheap only if they exist, and expensive forever if they don't.

Rails has no Radix. Every overlay in this repo currently ships its own answer to the
same four questions — how do I animate out, where do I sit in the paint order, who
gets Escape, who is allowed to scroll — and every answer is different. Three of them
are wrong in the same place. The bug the parent names ("a Dropdown opened inside a
Modal misbehaves") is not one bug; reading the source, it is three, and they share a
root cause:

1. `dropdown_controller` and `popover_controller` bind Escape and outside-click to
   `document` with no notion of who is on top. Open a Dropdown inside a Modal, press
   Escape, and both close — `modal_component`'s `keydown->ui--modal#closeOnEscape`
   fires on the wrapper at the same time the Dropdown's `document` listener does.
2. A modal `<dialog>` is promoted to the browser's **top layer**. The Dropdown's
   content is `absolute z-50` inside that dialog's `overflow-y-auto` box, so it is
   clipped by its own ancestor. No z-index value can fix this — the layers are not
   comparable.
3. `modal_controller.open()` sets `document.body.style.overflow = 'hidden'` and
   `performClose()` resets it to `''` unconditionally. Two overlays, and the first one
   to close unlocks the page underneath the second.

The `z-[61]` / `z-50` / `z-[70]` literals the parent flags are the *symptom*. The
disease is that a stacking order was invented in CSS when the browser already
maintains one.

That is the second half of the intent. **The platform got here first.** `<dialog>`
already gives a real, inert-based focus trap and top-layer placement — which is why
`Ui::ModalComponent` and `Ui::ConfirmDialogComponent` have working focus management
today without anyone having written a focus trap. The `popover` attribute gives
top-layer placement, light-dismiss and Escape-closes-the-top-one to *non-modal*
overlays, natively, with the correct LIFO ordering built in. This scope's central
call is therefore not "what shall we build" but "how little can we build" — see
§ Business rules, rule 1. The cheapest overlay stack is the one the browser is
already maintaining.

Presence (D) is the part the platform does *not* give. `<dialog>.close()` and
popover hide are both immediate; there is no native "hold this element until its exit
animation finishes." The repo hand-rolls it today with a hardcoded
`setTimeout(…, 300)` and sixteen `modal-*-hidden` / `modal-*-visible` CSS classes.
That is the thing to subsume.

## Goal

Every overlay in the kit — including one opened inside another — is placed,
dismissed and focus-managed by a single `ui--overlay` controller that delegates paint
order and dismiss ordering to the browser's top layer, and animates out through a
single `ui--presence` controller, established when a Dropdown opened inside a Modal
passes the nesting, focus-return and scroll-lock system tests with no z-index literal,
no `document`-level Escape listener and no hand-written focus trap left anywhere in
the two primitives.

## Non-goals

- **Not a Radix port.** Radix splits this into five packages because React's tree and
  the DOM's are different objects. Ours are the same object. One presence controller
  and one overlay controller, not five.
- **Not a `popover` polyfill.** A polyfill reimplements the top layer in JavaScript,
  which is precisely the code this scope exists to delete — and it would do so for the
  ~12% of browsers without native support, on a permanent basis, with light-dismiss and
  focus semantics that inevitably diverge from the native ones the other ~88% get. That
  is a second overlay implementation to maintain and two behaviors to debug under two
  live client consumers, bought against a shrinking minority. The feature-detected
  fallback in Behavior 16 costs one small module and loses only the top-layer
  guarantee. Non-supporting browsers degrade; see § Assumptions.
- **Not a general portal.** A portal exists to escape clipping and transformed
  ancestors. Top-layer elements already escape both — their containing block is the
  viewport, and no ancestor `overflow` or `transform` reaches them. Building a portal
  on top of that would be a second stacking system. Dropped deliberately;
  see § Out of scope / deferred.
- **Not the components themselves.** No `.rb` or `.html.erb` under `app/components/`
  changes in this scope.

## Behavior

Observable from outside. `ui--presence` (D) ships and passes first; `ui--overlay` (B)
consumes it.

### `ui--presence` — Stimulus identifier `ui--presence`

1. The controlled element carries `data-state` with exactly one of `open`, `closing`,
   `closed`. Tailwind's `animate-in` / `animate-out` utilities and any consumer CSS key
   off that attribute; the controller never adds or removes a class. It has **no
   `static classes` API** — a class-swap primitive is what the current
   `modal-*-visible` / `opacity-0` code is, and reproducing it would defeat the point.
2. Opening: the element becomes visible (the `hidden` **attribute** is removed — not a
   `.hidden` class, so a caller's `class:` override cannot collide with it, per
   `ui-component-library` § Business rules rule 5), then `data-state` becomes `open` on
   the next frame so the entry transition has a start state to run from.
3. Closing: `data-state` becomes `closing` **and the element stays visible and laid
   out** until the exit animation reports done, at which point `data-state` becomes
   `closed` and `hidden` is reapplied. Done means the element's own `animationend` or
   `transitionend` — events bubbled from descendants are ignored.
4. An element with no declared animation or transition closes in the same frame. It
   never waits, and never hangs waiting for an event that will not fire. A declared
   animation that is interrupted or never fires is bounded by a safety timer derived
   from the element's computed duration, ceilinged by the `timeout` value.
5. Interruption is settled state, not a race: close → open → close, or any faster
   sequence, ends in the state of the last request, with no orphaned timer and no
   element left `closing` forever.
6. Under `prefers-reduced-motion: reduce` the wait is skipped entirely and closing is
   immediate. The media query is read at transition time, not at connect, so a user
   changing the setting mid-session is honoured.
7. It announces `ui--presence:opened` and `ui--presence:closed` after the respective
   transition settles, and `ui--presence:closing` when the exit begins. These are what
   a consumer waits on; nothing polls a duration.

Public API: targets — none (operates on `this.element`). Values — `open` (Boolean),
`timeout` (Number, ms ceiling). Classes — none, by design (item 1).

### `ui--overlay` — Stimulus identifier `ui--overlay`

8. It has three modes, each mapping to a real platform primitive rather than to a
   component name:
   - `modal` → the `content` target is a `<dialog>`, opened with `showModal()`. Focus
     trap, top layer, focus restore and Escape are the browser's.
   - `layer` → the `content` target carries `popover="auto"`. Top layer, light-dismiss
     and Escape-closes-the-topmost are the browser's. It does **not** trap focus, which
     is correct for a menu or listbox.
   - `hint` → `popover="manual"`. Top layer, no light-dismiss, and critically it does
     not dismiss an open `layer` — a tooltip appearing must not close the menu the
     pointer is inside. `popover="manual"` opts out of the browser's own Escape
     handling, so `hint` content has none to inherit; Escape dismisses it through the
     one named exception to rule 3 — a capture-phase `document` `keydown` listener
     that, only while the content is visible, hides it and calls both
     `preventDefault()` and `stopPropagation()` so an ancestor's own Escape handling
     (a native `<dialog>`, or another layer's top-layer dismissal) never also fires
     (shipped for Tooltip in `78d4c64`).
9. **Escape closes exactly one layer: the top one.** Neither primitive registers a
   `document`-level `keydown` listener. Ordering is the top layer's, which is LIFO by
   construction. A Dropdown open inside a Modal takes the first Escape; the Modal takes
   the second.
10. **A Dropdown opened inside a Modal renders above the dialog and is not clipped by
    it** — because it is in the top layer too, not because a larger number was chosen.
11. Outside-click dismiss does not fire for a gesture that began inside the overlay.
    Drag-selecting text from inside the overlay to outside it leaves the overlay open.
12. Focus moves into the overlay on open — to `initialFocus` if given, else the content
    element itself — and **returns to the trigger on close**, including when the close
    came from Escape or an outside click. An overlay with no focusable children still
    receives focus and still returns it. `moveFocus: false` opts a `layer` out of that
    move, the way `hint` mode always is out of it: focus stays where the gesture left
    it, and it is not moved in later either, so focus that falls to `<body>` while the
    content changes is left there. A combobox needs exactly that, since its DOM focus
    has to stay on its own input while its listbox is open. Focus return is unaffected.
13. Body scroll lock is **reference-counted across every open overlay**. Opening a
    second lock-requesting overlay and closing it again leaves the page locked while
    the first is still open; releasing the last lock restores the exact prior scroll
    position. Locking and unlocking produce **no horizontal layout shift** from the
    scrollbar appearing or disappearing.
14. Dismissal is vetoable: `ui--overlay:dismiss` is dispatched cancelable before any
    Escape- or outside-click-initiated close. Calling `preventDefault()` on it keeps the
    overlay open. This is the seam `Ui::ModalComponent`'s existing dirty-form
    confirmation hooks into; without it the retrofit silently loses that behavior.
15. Opening and closing route through `ui--presence` on the content element, so an
    overlay's exit animation completes before `close()` / `hidePopover()` runs. This is
    the only reason a `<dialog>` can animate out at all.
16. Where `popover` is unsupported, the `layer` and `hint` modes still open, close,
    dismiss and manage focus correctly. What is lost is the top-layer guarantee, and
    the fallback is a single stacking value applied by the stack module — never a
    literal in a component. Feature detection is `HTMLElement.prototype.hasOwnProperty("popover")`.

Public API: targets — `content` (required), `trigger`, `backdrop`. Values — `open`
(Boolean), `mode` (String: `modal` | `layer` | `hint`, default `layer`), `dismissible`
(Boolean, default `true`), `scrollLock` (Boolean, default `false`), `restoreFocus`
(Boolean, default `true`), `initialFocus` (String selector, default `""`), `moveFocus`
(Boolean, default `true`). Methods — `open`, `close`, `toggle`, `dismiss` (the vetoable
close a gesture gets), and `closeNow`, added by `ui-foundation-retrofit` on 2026-09-15: a
close with no exit animation that still dispatches `ui--overlay:closed`, for a component
whose next step needs the content gone in the same task (Dropdown's Tab). Classes —
none. Events — `ui--overlay:opened`, `ui--overlay:closed`, `ui--overlay:dismiss`
(cancelable). Both controllers are exported and registered from
`app/javascript/rails_ui_kit/index.js` under those identifiers, matching the existing
`ui--` prefix.

17. Both primitives are consumable standalone. `ui--presence` on an Accordion panel or
    Collapsible, with no overlay involved, is a supported first-class use — it is the
    reason presence is a separate controller rather than a private method of the
    overlay.

### Element removal and Turbo's page cache — both primitives

18. **Removal without a close is a close.** When an open overlay's element leaves the
    document without `close()` running, the overlay's scroll lock is released and
    focus is restored as if it had closed. A Turbo Stream that empties or replaces its
    container, or a frame swap, are examples. The lock follows the reference count
    (item 13), so another open overlay keeps the page locked. Nothing is left on
    `<body>`: no `overflow`, no stale backdrop, no focus stranded on `<body>`.
19. **The Turbo-cache contract.** This is the convention the component audit's shipped
    fixes use (`6a07152`, `ed7fbcb`, `78d4c64`), adopted here as the primitives'
    contract:
    - On `connect`, `disconnect` and `turbo:before-cache`, each primitive returns
      immediately to its closed resting state, with no exit animation. A snapshot is
      never cached open.
    - Pending timers and animation frames are cleared at the same points.
    - A stored `open` value is ignored until the controller is connected. A page
      restored from cache doesn't replay an open overlay or pull focus into it. An
      overlay rendered to open on arrival, like a Modal delivered by a Turbo Stream
      (`ui-modal-turbo`), still opens after connecting, from the closed resting state
      through the normal enter path.
    - `showModal()` is never called on a `<dialog>` restored with a stale `open`
      attribute. The stale attribute is cleared first.

20. **A morphing refresh leaves an open `layer` or `hint` open.** A refresh another user's
    write triggered must not close the menu this user is choosing from, which is what morphing
    exists to preserve (ruled 2026-09-15 in `ui-stress-page/open-questions.md`). `modal` mode is
    excluded: whether a Modal survives a refresh is the host's own decision, taken by marking its
    container `data-turbo-permanent`, and one that isn't marked is morphed away
    (`ui-modal-turbo`). While such an overlay is open, `ui--overlay` keeps the morph off its own element and its content: the
    server's markup says closed, has no id on a Dropdown's panel or a Select's root -- so the
    morph would replace those elements and disconnect the controller -- and carries none of the
    inline position the anchor computed. Both morph normally again as soon as it closes. After
    any morph, open or closed, it puts back what it writes into markup it was given: the
    generated content id (the same one, remembered), `popover`, the `aria-controls` it gave a
    trigger, and `aria-expanded` for the state it is actually in. Pinned in
    `ui_overlay_morph_test.rb`.


## Business rules

**Must**

1. **Delegate to the platform; reimplement only what the platform does not provide.**
   Concretely, and this is the rule the whole scope turns on:
   - Top-layer placement and paint order — **delegated** (`showModal()` / `popover`).
   - Escape ordering across nested layers — **delegated** (top layer is LIFO).
   - Light-dismiss on outside click for non-modal layers — **delegated**
     (`popover="auto"`).
   - Focus trap for modal overlays — **delegated** (`<dialog>` inerts the rest of the
     document; a JS trap cannot correctly inert browser chrome and is strictly worse).
   - Focus restore — **delegated**, but verified by system test rather than trusted;
     this is where cross-browser variance actually lives.
   - Backdrop-click dismiss for `<dialog>` — **ours** (not native).
   - Body scroll lock — **ours**. `showModal()` blocks *interaction* with the page
     behind it; it does not block *scrolling*, and on mobile it does not block touch
     scrolling at all.
   - Presence / exit animation — **ours** (Primitive D).
   - Positioning — neither; out of scope.
2. **No z-index literal in either primitive, and no stack-depth counter.** The only
   stacking value that may exist is the single `popover`-unsupported fallback in the
   stack module, applied once, not per depth.
3. **No `document`-level `keydown` or `click` listener for dismissal, with one named
   exception.** A listener that cannot tell whether it is on top is the nesting bug,
   restated — except a capture-phase `document` `keydown` listener that dismisses
   visible `hint`-mode content on Escape, consuming the key with `preventDefault()`
   and `stopPropagation()` so it never reaches, and never closes, an ancestor's own
   Escape handling. `hint` content has no top-layer Escape ordering to inherit
   (`popover="manual"` opts out of the browser's light-dismiss and Escape handling
   entirely), so this listener is what gives it Escape at all — not a second
   implementation of the ordering `layer` and `modal` already get from the platform.
4. **No hand-written focus trap.** `modal` mode uses `<dialog>`; `layer` and `hint`
   modes must not trap at all.
5. **Presence never guesses a duration.** No `setTimeout` with a literal animation
   length. Waits are event-driven; timers exist only as a bounded safety net derived
   from computed style.
6. **Keyboard operation and ARIA are in this scope's definition of done**, per
   `ui-component-library` § Business rules rule 6. Focus entry, focus return, Escape
   ordering and `aria-expanded` / `aria-controls` on the trigger ship with the
   primitive, and are asserted in a real browser — not in a unit test that reads
   attributes. `aria-controls` names the content element only where the trigger has
   none of its own: markup that already says what it controls is the author's, and a
   combobox trigger names the listbox inside the popup rather than the wrapper around
   it, which also holds its empty state and status region.
7. **Nested behaves as standalone**, per `ui-component-library` § Business rules
   rule 7. The nesting case is a required system test, not a caveat in a README.

**Should**

8. **Hold the scroll-lock gutter as body padding.** The lock takes `<body>` out of
   flow, and a fixed element's containing block is the viewport *including* a gutter
   reserved by `scrollbar-gutter: stable`, so that rule lays the body out one scrollbar
   wider than it is unlocked and every centred or right-aligned element jumps on open.
   The scrollbar's width is measured once and added to the body's own `padding-right`
   instead. This corrects an earlier "prefer CSS over measurement" rule
   (`359aa75`; status.md § Corrections).
9. **Two controllers and two plain modules, not five controllers.** Cross-instance
   state (the scroll-lock refcount, the fallback stacking value) lives in an ES module
   singleton, not in a Stimulus controller — there is no element it belongs to.
10. **Keep the working `<dialog>`.** `Ui::ModalComponent` and
    `Ui::ConfirmDialogComponent` chose `<dialog>` and that choice was right. This scope
    builds around it; it does not replace it for symmetry with the popover path.

**May**

11. A component may opt out of scroll lock (`scrollLock: false`) — a right-side Sheet
    that is meant to scroll with the page is legitimate. A `layer` may also opt out of
    the focus move on open (`moveFocus: false`), which is what a combobox that must
    keep DOM focus on its input needs. Neither may opt out of focus return or Escape
    ordering.

## Assumptions

What this scope takes as given, and what to do when one contradicts the plan.
Inherits `ui-component-library` § Assumptions in full; these are additional.

- **`popover` is Baseline but not universal.** It reached Baseline in January 2025
  (Chrome/Edge 2023, Safari 17.4, Firefox 125) at roughly 88% global support. Treat
  that number as a decision input, not as a certainty: **re-check current support at
  build time** rather than inheriting this figure. The ~12% is the whole cost of the
  platform bet, and it is bounded — it only affects `layer` and `hint` modes, because
  `<dialog>` support is effectively universal. **At a contradiction** — support
  materially worse than assumed, or a target client browser missing it — that is a
  decider call, not an implementer workaround; see `open-questions.md`.
- **`dialog.show()` is not a substitute for `popover`.** Only `showModal()` promotes
  to the top layer; non-modal `show()` does not. There is no 100%-supported route to
  top-layer placement for a non-modal overlay. This is why the fallback in Behavior 16
  exists at all.
- **Modal `<dialog>` does not lock scroll.** Verified: `showModal()` inerts the
  document behind it but does not prevent wheel or touch scrolling, and `overflow:
  hidden` on `<body>` is insufficient on iOS Safari — that case needs
  `position: fixed` plus explicit scroll-position restore. Budget for it; it is the
  single fiddliest mechanic in this scope.
- **CSS anchor positioning is not available.** It remains effectively Chromium-only, so
  `popover` buys top layer and dismiss but buys **nothing** for positioning.
  `@floating-ui/dom` stays, owned by `ui-positioning-and-navigation`. Do not attempt to
  drop it here.
- **The browser lane is a precondition, not part of this scope.** Every
  `agent-loopable` check here runs in the system-test lane `ui-test-harness` owns and
  ships first: the `ApplicationSystemTestCase` base class on headless Chrome driving
  `examples/`, the `test:system` rake task that keeps Capybara out of the five-Ruby unit
  lane, and the `assert_accessible` helper on that base class. This scope writes test
  files that inherit it and stands up no harness of its own (§ Business rules of
  ui-test-harness, rule 5; `relations.md` carries the edge). The accessibility stack is
  settled there as `axe-core-capybara` + `axe-core-api` asserted directly from Minitest —
  which corrects `ui-component-library` § Assumptions' `axe-core-rspec`, unusable in a
  repository with no RSpec. **At a contradiction** — if a behavior this scope needs
  cannot be asserted in that lane — escalate rather than downgrading to
  attribute-reading unit tests and calling accessibility done.
- **`@starting-style` / `transition-behavior: allow-discrete` are not relied on.**
  Primitive D holds the element open until its animation settles and only then closes
  it, which sidesteps the top-layer discrete-property problem entirely and works
  identically for non-top-layer consumers like Accordion. This is deliberate; a CSS-only
  presence solution would not serve Accordion or Collapsible and would not produce the
  `data-state` attribute Tailwind's utilities key off.
- **`ui-component-base` lands first.** Per the parent's Phase A build order. If it has
  not, these primitives still build — they are JavaScript, not variants — but the
  retrofit that consumes them cannot start.

## Critical files

Pointers. The code is the source of truth for what they do.

- `app/javascript/rails_ui_kit/controllers/modal_controller.js` — the `<dialog>` usage
  worth keeping, wrapped in the three bugs named in § Intent. Its `translateInClasses` /
  `translateOutClasses` pair and its `setTimeout(…, 300)` are hand-rolled presence.
- `app/javascript/rails_ui_kit/controllers/dropdown_controller.js`,
  `popover_controller.js`, `tooltip_controller.js` — three near-identical
  `show`/`hide`/`setupListeners`/`cleanup` implementations. The `document`-level Escape
  and click handlers in the first two are the nesting bug.
- `app/javascript/rails_ui_kit/controllers/dialog_controller.js` — the `window.
  defaultConfirmDialog` promise bridge. Not replaced here, but it opens a `<dialog>`
  directly and will need to route through the stack once retrofitted; note the seam.
- `app/javascript/rails_ui_kit/index.js` — the registration surface. Both new
  identifiers must appear in the `export` block and in `registerControllers`.
- `app/assets/stylesheets/rails_ui_kit/components.css` — the sixteen
  `modal-*-hidden`/`-visible` classes Primitive D subsumes. They are not deleted here
  (the retrofit owns that) but nothing new may be added to them.
- `app/components/ui/modal_component.rb` and `modal_component.html.erb` — where
  `z-[61]` and `z-[60]` live, and where the separate backdrop `<div>` sits. Read-only
  in this scope; its `click->ui--modal#closeOnBackdropClick` binding is dead code
  (`showModal()` inerts that div) and the retrofit should know.
- `test/application_system_test_case.rb`, `examples/` — the base class every system
  test here inherits from (shipped by `ui-test-harness`) and the dummy host it drives.
- `lib/generators/rails_ui_kit/install/install_generator.rb` — any CSS this scope ships
  has to be reflected here or host apps half-install. It ships none: the scroll lock's
  gutter is body padding written by `overlay_stack.js` (rule 8), not a stylesheet rule.

## Acceptance checks

### agent-loopable

- `ui--presence` moves an element through `open` → `closing` → `closed`, holds it
  visible until `transitionend` fires on the element itself, closes in the same frame
  when no transition is declared, and settles correctly under an interrupted
  close→open→close — run: `bundle exec rake test:system TEST=test/system/ui_presence_test.rb`
- A Dropdown opened inside a Modal paints above the dialog, is not clipped by the
  dialog's scroll container, and the first Escape closes only the Dropdown while the
  second closes the Modal — run: `bundle exec rake test:system TEST=test/system/ui_overlay_nesting_test.rb`
- Focus enters the overlay on open and returns to the trigger on close for `modal` and
  `layer` modes, via Escape, outside click and programmatic close, including an overlay
  with no focusable children; a `moveFocus: false` layer takes no focus on open and
  pulls none in when its content changes; and a trigger that already names what it
  controls keeps its `aria-controls` — run: `bundle exec rake test:system TEST=test/system/ui_overlay_focus_test.rb`
- Scroll lock is reference-counted: a second overlay opening and closing leaves the
  body locked while the first is open, the last release restores the exact scroll
  position, and neither transition shifts layout horizontally — run: `bundle exec rake test:system TEST=test/system/ui_scroll_lock_test.rb`
- A pointer gesture starting inside the overlay and ending outside it does not dismiss
  the overlay, while a click wholly outside does — run: `bundle exec rake test:system TEST=test/system/ui_overlay_dismiss_test.rb`
- Removing an open overlay's element without closing it releases the scroll lock and restores focus, while another open overlay keeps the page locked — run: `bundle exec rake test:system TEST=test/system/ui_overlay_removal_test.rb`
- On `turbo:before-cache`, an open overlay and a mid-transition presence element both return to the closed resting state with no pending timer or frame, and Back to that page restores them closed, with focus not pulled in and no `showModal()` error on a stale `open` dialog — run: `bundle exec rake test:system TEST=test/system/ui_overlay_turbo_cache_test.rb`
- Automated accessibility scan reports no violations on the overlay and nested-overlay
  demo states — run: `bundle exec rake test:system TEST=test/system/ui_overlay_accessibility_test.rb`
- The unit lane stays green with both primitives registered in `index.js` and no
  z-index literal, no `document`-level Escape listener and no focus-trap
  implementation in either primitive source — run: `bundle exec rake test`

### judgeable

- The shipped code honours the delegation table in § Business rules rule 1 of this
  spec — specifically that top-layer placement, Escape ordering and light-dismiss are
  delegated rather than reimplemented — and satisfies rules 4 ("exactly one
  implementation") and 7 ("nesting is not a special case") in the § Business rules
  section of `ui-component-library`. A reviewer that finds a stack-depth counter, a
  `document` Escape listener or a JS focus trap fails this regardless of green tests.
- The `ui--presence` and `ui--overlay` public APIs stated in § Behavior are sufficient
  for all seven existing components and for the Phase C overlay family listed in the
  § Scopes section of `ui-component-library`, without either primitive growing a
  component-specific branch. Judged by walking the Phase C list against the API, not by
  running anything.
- Keyboard operation and ARIA meet rule 6 in the § Business rules section of
  `ui-component-library`. The axe pass is necessary and not sufficient — a reviewer
  drives the overlays by keyboard alone and judges whether the experience is correct,
  not merely unflagged.

### human-gate

- Exit animations read as deliberate motion rather than as a delay: Jonathan closes a
  Modal at each of its eight positions, a Dropdown and a Tooltip in the docs app and
  accepts the feel — and with `prefers-reduced-motion: reduce` set, the same
  interactions feel instant rather than broken.
- Jonathan accepts the platform bet: he exercises the `popover`-unsupported fallback
  path in a non-supporting browser and either accepts the degradation for client work
  or rules the bet off, which reopens this scope's central decision.

## Out of scope / deferred

- **Anchored / floating positioning — owned by `ui-positioning-and-navigation`**
  (Primitive A). This scope does not touch `@floating-ui/dom`, does not emit
  `data-side` / `data-align`, and does not position anything. An overlay in the top
  layer is *placed* by this scope and *positioned* by that one.
- **Roving tabindex and group navigation — owned by `ui-positioning-and-navigation`**
  (Primitive C). Arrow keys, Home/End, typeahead and `aria-activedescendant` are not
  here. `ui--overlay` moves focus *in* and *back*; it does not move focus *within*.
  The arrow-key handling currently in `dropdown_controller` stays where it is until
  that scope claims it.
- **Migrating the seven existing components onto these primitives — owned by
  `ui-foundation-retrofit`.** No `app/components/` file changes here, the
  `modal-*-hidden`/`-visible` CSS is not deleted here, and the three duplicated
  positioning implementations are not removed here. This scope ships the primitives
  and the demo surface that exercises them; the retrofit moves the components onto
  them. Note for that scope: `ui--modal`'s `dialog` target becomes `ui--overlay`'s
  `content` target, which is a breaking rename of a public data attribute.
- **A general portal primitive — dropped, not deferred.** Reason in § Non-goals: the
  top layer already escapes clipping and transformed ancestors, so a portal would be a
  second stacking system competing with the browser's. If a future need appears that
  the top layer genuinely cannot serve — a persistent region like the toast container,
  which is not an overlay — it is a targeted addition to that component, not a
  resurrection of this primitive.
- **`popover="hint"` — not used.** It is the semantically correct value for tooltips
  and hover cards but is Chromium-only. `hint` mode uses `popover="manual"` plus the
  component's own show/hide, which is behaviourally equivalent for our purposes.
  Revisit when `hint` is Baseline.
- **CSS anchor positioning — not used.** Chromium-only; see § Assumptions.
- **A `popover` polyfill — declined.** See § Non-goals and `open-questions.md`.
