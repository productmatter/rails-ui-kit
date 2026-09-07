# Open questions — ui-foundation-retrofit

## Toast's semantic type colors: extend the token set or map onto the existing five?

Toast has five status types — success, error, notice, alert, info — each needing a
visually distinct color today (`bg-green-100`/`bg-red-100`/`bg-orange-100`/
`bg-blue-100` and their `-400`/`-500` icon variants). The closed 33-token set this
phase ships (`ui-component-library` spec.md § Business rules, rule 2; `ui-design-
tokens` spec.md § Business rules, rule 1, "no more, no fewer") has exactly one
status-shaped token: `destructive`. That covers `error`/`alert` cleanly. `success`,
`notice` and `info` have no natural home in the shipped set without either extending
it — which reopens an already-ratified sibling scope — or reusing an unrelated token
(`primary`, `accent`, one of `chart-1`…`chart-5`) by resemblance, which is the
"arbitrary pick" this directive explicitly warned against.

decider: Jonathan Simmons
options: (a) extend the token contract with status tokens — `success`, `warning` (serving `notice`/`alert`), `info`, each with a `-foreground` pair — reopening `ui-design-tokens`; shadcn/ui itself has no canonical status-color tokens either, so this is new vocabulary under that contract regardless of which component asks first, and Alert/Badge in Phase B will hit the identical gap; (b) collapse the five types onto the existing set — `error`/`alert` → `destructive`, `success`/`notice`/`info` → `primary` or `accent` — accepting that Toast's five types are no longer visually distinct by color and documenting that as a deliberate, named regression rather than an accident; (c) three fixed, non-token `oklch()` literals scoped to Toast only, as a narrow, explicitly documented exception to Business rule 1 rather than a silent violation of it
default: (a) — a notification/status component needing colors beyond "destructive" is a predictable, recurring need this kit will hit again before Phase B is done (Alert, Badge), so solving it once at the token layer is cheaper than three components independently improvising exceptions to rule 1
deadline: 2026-09-21

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
