# Open questions — ui-foundation-retrofit

## Must a toast appear over an open Modal, given a z-index cannot put it there?

ToastContainer's `z-[70]` is replaced by one static stacking value this scope owns
(§ Behavior). That value settles ordering against ordinary page content and settles
nothing against a Modal: `showModal()` promotes a `<dialog>` to the browser's top
layer, and no z-index on a normal-flow element is comparable to it. So a toast fired
while a Modal is open — a form inside a Modal saving successfully is the ordinary
case — is painted behind the dialog unless the container is itself promoted. The
overlay primitives deliberately do not solve this: the toast container is not an
overlay and `ui-presence-and-overlay-stack` § Out of scope / deferred names any need
here "a targeted addition to that component."

decider: Jonathan Simmons
options: (a) render `ToastContainerComponent` with `popover="manual"` and show it via `showPopover()`, putting the container in the top layer alongside the dialog so later-promoted elements paint above it — the static stacking value stays as the fallback for browsers without `popover`, where toasts are occluded by modals; (b) accept the occlusion — the container keeps one static stacking value, toasts are hidden behind an open Modal in every browser, and the components that need to confirm something inside a Modal do it inside the Modal; (c) keep the toast container out of `<dialog>`'s way by having Modal-scoped confirmations render their own inline feedback, and document toasts as page-level-only
default: (a) — it uses the platform mechanism the rest of Phase A already bets on, costs a `popover` attribute and one `showPopover()` call rather than a new stacking system, and degrades to exactly option (b) where `popover` is unsupported; but it is a rendered-markup change to a shipped component under two live consumers, which is the decider's call
deadline: 2026-09-21
