## How do the ~12% of browsers without the `popover` attribute degrade?

decider: Jonathan Simmons
options: (a) feature-detect and degrade — `layer`/`hint` overlays still open, close, dismiss and manage focus, losing only the top-layer guarantee, with one stacking value applied by the stack module as fallback; (b) ship the `@oddbird/popover-polyfill` and treat the top layer as universal; (c) require `popover` support and let non-supporting browsers render the overlay inline and unlayered
default: (a) feature-detect and degrade — the fallback costs roughly one small module, while the polyfill buys the remaining ~12% at the price of a JS reimplementation of the top layer, which is precisely the class of code this scope exists to delete, plus a permanent maintenance and correctness liability (polyfilled light-dismiss and focus semantics diverge from the native ones the other 88% get) under two live client consumers
deadline: 2026-09-21

## Does `<dialog>` keep its own dismiss path, or route everything through `ui--overlay`?

decider: Jonathan Simmons
options: (a) `ui--overlay` owns every open and close, and `ui--dialog`'s `window.defaultConfirmDialog` bridge calls into it; (b) `ui--dialog` keeps calling `showModal()` directly and simply never participates in scroll-lock refcounting or presence; (c) leave the decision to `ui-foundation-retrofit`
default: (a) `ui--overlay` owns it — a confirm dialog opened from inside an already-open Modal is exactly the nesting case this scope exists to fix, and (b) reintroduces a second overlay implementation, breaking `ui-component-library` § Business rules rule 4
deadline: 2026-09-21
