## State

building

Nothing blocking. Spec is ratified and the build has not started. First unit is
Primitive D (`ui--presence`); Primitive B (`ui--overlay`) consumes it and follows.
The one precondition is the system-test lane, which `ui-test-harness` owns and ships
first (`relations.md` carries the edge): every acceptance check in the `agent-loopable`
partition runs in a real browser, so this build starts once that lane exists.

## Done

Nothing built. Shaping complete: the parent's Primitives D and B are decomposed into
two Stimulus identifiers (`ui--presence`, `ui--overlay`) plus two ES-module singletons,
with the platform-delegation boundary decided and recorded in § Business rules rule 1.

## In progress

None. Suggested first unit once `ui-test-harness` has shipped the lane: build
`ui--presence` against `test/system/ui_presence_test.rb`, inheriting that scope's
`ApplicationSystemTestCase`. Presence is the smaller primitive and the one with no open
questions attached, so it is the cheapest first consumer of the harness before the
overlay work depends on it.

## Last green checkpoint

none — build has not started; no primitive source exists yet and `test/system/` does not exist

## Dead ends

Recorded pre-emptively from the shaping pass so a fresh context does not re-walk them:

- CSS `z-index` stack ordering by depth — cannot work at all; a modal `<dialog>` is in the browser's top layer and no z-index value in the normal layer is comparable to it
- Non-modal `<dialog>.show()` as a route to the top layer — only `showModal()` promotes to the top layer, so this does not solve the non-modal case
- CSS-only presence via `@starting-style` / `transition-behavior: allow-discrete` — does not serve non-top-layer consumers (Accordion, Collapsible) and produces no `data-state` attribute for Tailwind's `animate-in`/`animate-out`
- A `popover` polyfill — it reimplements the top layer in JavaScript, which is exactly the code this scope exists to delete, and its light-dismiss and focus semantics would diverge from the native ones the ~88% of browsers get; a permanent maintenance and correctness liability bought for the remaining ~12%
- CSS anchor positioning to replace `@floating-ui/dom` — effectively Chromium-only; also out of scope, owned by `ui-positioning-and-navigation`

## Corrections

None yet. This build has not started, so no correction has been caught by an implementer, a reviewer or the decider.
