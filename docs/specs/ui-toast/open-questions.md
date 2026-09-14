# Open questions — ui-toast

## Must a toast appear over an open Modal, given a z-index cannot put it there?

Moved from `ui-foundation-retrofit`, which asked it first, because this scope now owns the
container. `showModal()` puts a `<dialog>` in the browser's top layer, and no z-index on a
normal-flow element can paint above it. So a toast fired while a Modal is open paints behind
the dialog. A form inside a Modal saving successfully is the ordinary case. The modal also
makes everything outside it inert, so the toast's actions can't be reached until it closes.
That's why an action toast persists by default (spec.md § Behavior, item 10). Whether a
top-layer `popover` container escapes inertness as well as occlusion is unverified
(§ Assumptions).

decider: Jonathan Simmons
options: (a) render the container with `popover="manual"` and show it with `showPopover()` after any modal opens, so toasts paint above the dialog; the static stacking value stays as the fallback where `popover` is unsupported; (b) accept the occlusion; toasts are hidden behind an open Modal in every browser, and a Modal's own feedback is rendered inside it; (c) as (b), and the docs say toasts are page-level only
default: (a) — it's the platform mechanism the rest of Phase A already uses, it costs one attribute and one call, and it degrades to (b) where `popover` is missing; the browser check that decides it must also record whether a promoted toast's action is focusable while the modal is open, and if not, the docs say so instead of the kit adding a focus exception
deadline: 2026-09-21
decided: (a), verify-first, 2026-09-14, the orchestrator's ruling that ratified this scope. A toast action a user can see but can't reach is worse than one hidden behind the modal. So promotion ships only if the top-layer reachability probe, the first agent-loopable check in spec.md, passes before anything is built on it. The probe covers four things: while a real kit Modal is open, an action in a `popover="manual"` element is hit-testable, clickable and focusable; the Modal's focus trap doesn't reclaim that focus; Escape handled inside it leaves the Modal open; and closing it can return focus into the dialog. **If it fails, the fallback is (b):** the container isn't promoted and keeps one static stacking value. Toasts are occluded while a Modal is open, and an action toast, which persists by default, becomes reachable when the Modal closes. The probe's result goes in status.md, and spec.md § Behavior item 12 is edited to whichever branch holds.

## Should an action's `class` work through JavaScript?

In Ruby and a Turbo Stream, an action's `class` merges onto Button's classes with
`tailwind_merge`, so the caller wins (parent rule 5). A browser has no `tailwind_merge`.
Appending the classes unmerged would leave two conflicting utilities on one element, where
Tailwind's stylesheet order decides the winner, not the caller. That's rule 5 broken
silently, and the three entry points would no longer render the same markup.

decider: Jonathan Simmons
options: (a) `class` is a Ruby and Turbo Stream key; a JavaScript action carrying it is invalid (loud in development, dropped with a warning in production); a JavaScript caller styles an action with `variant`; (b) pin the npm `tailwind-merge` package for the JavaScript path, a second merge implementation whose output can differ from the gem's, one more importmap pin for every host, against parent rule 8; (c) append unmerged and document that conflicts are unpredictable
default: (a) — `variant` covers what a toast action needs, the loud failure tells a developer at once, and it keeps one merge implementation and identical markup; revisit if a client build needs per-action styling from JavaScript
deadline: 2026-09-21
decided: (a), 2026-09-14, the orchestrator's ruling that ratified this scope. Shipping a second merge library whose output could differ from the gem's is worse than the limit. A JavaScript action carrying `class` errors in development and test, and is dropped with a warning in production.
