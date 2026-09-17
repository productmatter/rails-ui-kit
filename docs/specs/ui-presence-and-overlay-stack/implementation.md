# Implementation notes — presence and the overlay stack

Advisory build-scratch, not contract. `spec.md` is the contract; this is the "how"
B6 keeps out of it. Where the two disagree, `spec.md` wins.

## Module layout

```
app/javascript/rails_ui_kit/
├── controllers/
│   ├── presence_controller.js      → registers as "ui--presence"
│   └── overlay_controller.js       → registers as "ui--overlay"
└── overlay/
    ├── presence.js                 → enter(el, opts) / exit(el, opts); no Stimulus
    ├── overlay_stack.js            → module singleton: push/pop/top, scroll-lock refcount
    └── scroll_lock.js              → lock()/unlock(), refcounted by overlay_stack
```

Why two of these are plain modules and not controllers: the scroll-lock refcount and
the `popover`-unsupported fallback are properties of *the page*, not of any element, so
there is nothing for Stimulus to bind them to. Why `presence.js` is separate from
`presence_controller.js`: `ui--overlay` needs the behavior, not the controller, and
reaching across controllers via outlets to get it would couple two primitives that
should compose by import.

Both controllers go into the `export { … }` block **and** `registerControllers()` in
`app/javascript/rails_ui_kit/index.js`.

## Primitive D — presence

Enter:
1. remove the `hidden` attribute; set `data-state="closed"` if not already set
2. force layout read (`element.offsetHeight`) so the browser has a start state
3. `requestAnimationFrame` → `data-state="open"`, dispatch `ui--presence:opened` once
   the entry transition settles (same waiting mechanism as exit)

Exit:
1. `data-state="closing"`, dispatch `ui--presence:closing`
2. wait (below)
3. `data-state="closed"`, set the `hidden` attribute, dispatch `ui--presence:closed`

The wait, which is the whole primitive:

- **Reduced motion first.** `matchMedia("(prefers-reduced-motion: reduce)").matches`,
  read at transition time. True → resolve synchronously, no listeners, no timer.
  Deliberately not routed through Primitive F (media-query watcher): F lives in
  `ui-positioning-and-navigation` and builds *after* this scope, so a dependency would
  invert the parent's build order. A single `matchMedia` read is not a competing
  implementation of a watcher, but flag it for `ui-foundation-retrofit` to fold in once
  F exists.
- **Zero-duration short-circuit.** Read `getComputedStyle`: sum
  `animation-duration + animation-delay` and `transition-duration + transition-delay`,
  take the max. If it is 0, resolve in the same frame. This is the
  "element with no transition must not hang" case, and handling it by *measurement*
  rather than by *timeout* is what makes it same-frame rather than
  `timeout`-milliseconds-later.
- **Event listeners.** `transitionend` and `animationend` on the element, both with the
  guard `if (event.target !== this.element) return` — descendants bubble these and an
  unguarded listener resolves early. Also listen for `transitioncancel` /
  `animationcancel` and treat them as done.
- **Safety timer.** `computedDuration * 1.5 + 50`, ceilinged at `timeoutValue`
  (default 1000ms). Fires only if no event arrives.
- **Interruption.** A monotonically increasing `this.generation` counter. Every wait
  captures the generation it started in; on resolution it returns early if
  `this.generation` has moved. Each new enter/exit increments it, clears the pending
  timer, and removes pending listeners. `disconnect()` does the same. This is what makes
  close→open→close settle on `open` instead of on a stale `closed`.

Consumers wait on the dispatched events. Nothing anywhere polls or sleeps a duration.

## Primitive B — the overlay

### Open

1. `overlayStack.push(entry)` — assigns the fallback stacking value if `popover` is
   unsupported, and increments the scroll-lock refcount if `scrollLockValue`
2. record `document.activeElement` as the return target
3. `modal` → `content.showModal()`; `layer`/`hint` → `content.showPopover()`
   (guarded by feature detection; the fallback path just removes `hidden`)
4. `presence.enter(content)`
5. move focus: `initialFocusValue` selector within content, else the content element
   itself (add `tabindex="-1"` if it has none, so the no-focusable-children case still
   receives focus)
6. `trigger.setAttribute("aria-expanded", "true")`; wire `aria-controls` to the
   content's id (generate one if absent, as `tooltip_controller` already does)
7. dispatch `ui--overlay:opened`

### Close

1. dispatch `ui--overlay:dismiss` **cancelable** if the close originated from Escape or
   an outside click; bail if defaultPrevented. Programmatic `close()` skips this.
2. `presence.exit(content)` and **await it** — this is the only reason a `<dialog>` can
   animate out; calling `.close()` first removes it from the top layer immediately and
   nothing renders
3. `content.close()` / `content.hidePopover()`
4. restore focus to the recorded trigger if `restoreFocusValue`
5. `overlayStack.pop(entry)` — releases the scroll lock only if this was the last holder
6. `aria-expanded="false"`; dispatch `ui--overlay:closed`

### Escape

Nothing. Genuinely nothing — no listener at all. `<dialog>` fires `cancel`,
`popover="auto"` light-dismisses, and both are top-layer LIFO. What the controller does
listen for is `cancel` (on the dialog element, not `document`) and `beforetoggle` /
`toggle` (on the popover element) so it can run step 1 above — `cancel` is
preventable, which is exactly the veto seam Behavior 14 needs.

### Outside click

- `layer`/`hint` with `popover` support: the browser's light-dismiss. The
  drag-out-of-overlay case is handled by the platform's algorithm keying on the
  `pointerdown` target — **verify this empirically in
  `test/system/ui_overlay_dismiss_test.rb` across the browser matrix rather than
  trusting it**, since it is the one delegated behavior with a plausible
  implementation gap.
- `modal`: `<dialog>` has no native backdrop dismiss, so this is ours. Record the
  `pointerdown` target; on `click`, dismiss only if **both** the `pointerdown` and the
  `click` target are the `<dialog>` element itself (a click on the `::backdrop` targets
  the dialog). Comparing only the click target is the current
  `closeOnBackdropClick` behavior and is what produces the drag-select bug.

### Scroll lock

Ships one CSS rule in the kit's stylesheet, which must be reflected in the install
generator:

```css
html { scrollbar-gutter: stable; }
```

That reserves the gutter permanently, so `overflow: hidden` on `<body>` causes zero
horizontal shift and nothing needs measuring. Behind `CSS.supports("scrollbar-gutter",
"stable")` being false, fall back to measuring
`window.innerWidth - document.documentElement.clientWidth` and applying it as
`padding-right` on `<body>`.

iOS Safari ignores `overflow: hidden` on `<body>` for touch scrolling. That path needs
`position: fixed; top: -${scrollY}px; width: 100%` on `<body>`, and on unlock the
**exact** scroll position restored via `window.scrollTo(0, savedY)` before the styles
are removed — restoring after produces a visible jump. Detect the iOS case by
capability, not by user-agent string, if a capability test can be found; otherwise
apply the `position: fixed` technique universally, since it is correct everywhere and
only the desktop path is cheaper.

Also set `overscroll-behavior: contain` on the overlay content so a scrollable overlay
does not chain its scroll to the page behind it.

Refcounting lives in `overlay_stack.js`: `lock()` on 0→1, `unlock()` on 1→0, nothing in
between. This is what fixes `modal_controller`'s unconditional
`document.body.style.overflow = ''`.

## Test harness

Not built here. `ui-test-harness` ships `test/application_system_test_case.rb` (headless
Chrome against the `examples/` dummy host), the `test:system` rake task that keeps the
browser out of the five-Ruby unit lane, and the `assert_accessible` helper on that base
class. Every check in `spec.md` § Acceptance checks runs as
`bundle exec rake test:system TEST=test/system/<name>_test.rb`, flat under
`test/system/`, inheriting that base class.

What this scope does add is the demo surface those checks drive: a page in `examples/`
rendering the nested Modal + Dropdown case, which does not exist today.

## Traps found in the current source, for whoever builds this

- `modal_component.html.erb` binds `click->ui--modal#closeOnBackdropClick` to a separate
  backdrop `<div>` at `z-[60]`. That handler is **dead**: `showModal()` inerts
  everything outside the dialog, so the div is unclickable. The dismiss that actually
  works is the wrapper-level handler comparing against the dialog element. Do not
  reproduce the div.
- `modal_component.rb` sets `z-[61]` on a `<dialog>` that is in the top layer. The value
  has no effect and never did.
- `dropdown_controller` and `popover_controller` both `setTimeout(…, 10)` before
  attaching their outside-click listener, to dodge the opening click. With the platform
  light-dismiss this hack disappears; do not port it.
- `dropdown_controller.getFocusableItems()` filters on `item.offsetParent !== null`,
  which is `null` for any `position: fixed` element and for top-layer content in some
  engines. If any of that logic migrates later, this filter will silently return an
  empty list.
