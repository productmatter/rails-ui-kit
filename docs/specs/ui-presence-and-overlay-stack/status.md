## State

ready-for-review

Both primitives are built, every component in the kit consumes them, and all nine
agent-loopable checks pass. What remains is the judgeable review and Jonathan's two
human gates (exit-animation feel, and the `popover`-unsupported fallback). See
§ Corrections for the spec statements the build overturned.

## Done

- Built both primitives and the two module singletons in `39e7dd8`:
  `ui--presence` (`open` → `closing` → `closed`, waiting for a real animation rather
  than guessing a duration, interruption treated as a settled state), `ui--overlay`
  (the platform top layer in `modal`, `layer` and `hint` modes, a reference-counted
  scroll lock, focus return and a cancelable dismiss), `overlay/presence.js` and
  `overlay/overlay_stack.js`. No component consumed them yet at that commit.
- Retrofitted every consumer, which is what took the second implementation out of the
  kit: Modal and ConfirmDialog in `6116cbd` (Modal 236 lines to 112; its own scroll
  lock, 300 ms timers, backdrop `div`, both `z-index` literals and its capture-phase
  backdrop workaround all deleted; ConfirmDialog gained a scroll lock it never had),
  then Dropdown, Popover and Tooltip in `144d104` (Popover 213 to 74, Tooltip 210 to
  144).
- Fixed what the retrofit exposed, in `6116cbd` and `8446865`: Escape is taken as a
  keydown on the content rather than relying on `<dialog>`'s `cancel`, which Chrome
  only makes cancelable with fresh user activation, so a dirty-form veto could be lost
  silently; `ui--overlay:dismiss` carries `detail.reason`; and `openValue` is cleared
  when hiding starts, so `open()` during an exit animation is no longer ignored.
- Added the primitive support `ui-select` needs, in `11d71a9`: the `moveFocus` value,
  and `aria-controls` left alone when the trigger already carries one. Both are
  recorded in § Behavior item 12, the Public API paragraph and § Business rules rules 6
  and 11 (`8f606c4`).
- Fixed the scroll lock's horizontal shift in `359aa75` — see § Corrections, which is
  where § Business rules rule 8 went.
- Nine system test files cover the scope: `ui_presence`, `ui_overlay_focus`,
  `ui_overlay_dismiss`, `ui_overlay_nesting`, `ui_overlay_removal`,
  `ui_overlay_turbo_cache`, `ui_overlay_accessibility`, `ui_overlay_fallback` and
  `ui_scroll_lock`, with the shared probes in `test/system/ui_overlay_helpers.rb`.

## In progress

None. The next work that touches this scope is `ui-select`, which consumes `layer`
mode with `moveFocus: false` and the `aria-controls` carve-out; it adds nothing further
to either primitive.

## Last green checkpoint

2026-09-14, at `359aa75` plus the uncommitted `ui-select` Phase 1 work, every
agent-loopable check run on its own: `bundle exec rake test` 300 runs / 827 assertions;
`ui_presence` 7, `ui_overlay_nesting` 6, `ui_overlay_focus` 11, `ui_scroll_lock` 6,
`ui_overlay_dismiss` 14, `ui_overlay_removal` 4, `ui_overlay_turbo_cache` 7,
`ui_overlay_accessibility` 4 and `ui_overlay_fallback` 2 runs — 0 failures throughout.

## Dead ends

Recorded pre-emptively from the shaping pass so a fresh context does not re-walk them:

- CSS `z-index` stack ordering by depth — cannot work at all; a modal `<dialog>` is in the browser's top layer and no z-index value in the normal layer is comparable to it
- Non-modal `<dialog>.show()` as a route to the top layer — only `showModal()` promotes to the top layer, so this does not solve the non-modal case
- CSS-only presence via `@starting-style` / `transition-behavior: allow-discrete` — does not serve non-top-layer consumers (Accordion, Collapsible) and produces no `data-state` attribute for Tailwind's `animate-in`/`animate-out`
- A `popover` polyfill — it reimplements the top layer in JavaScript, which is exactly the code this scope exists to delete, and its light-dismiss and focus semantics would diverge from the native ones the ~88% of browsers get; a permanent maintenance and correctness liability bought for the remaining ~12%
- CSS anchor positioning to replace `@floating-ui/dom` — effectively Chromium-only; also out of scope, owned by `ui-positioning-and-navigation`
- `scrollbar-gutter: stable` for the scroll lock's gutter — see § Corrections; it cannot hold the gutter for a body taken out of flow

## Corrections

- Acceptance checks didn't cover an overlay element removed without closing (the component audit's M2: a Turbo Stream close leaked the scroll lock and focus); added § Behavior item 18 and `ui_overlay_removal_test.rb` — provable — reviewer
- Acceptance checks didn't cover `turbo:before-cache` (the audit's cross-cutting pattern 1: Back restored open or broken overlays); added the Turbo-cache contract the shipped fixes use as § Behavior item 19, with `ui_overlay_turbo_cache_test.rb` — provable — reviewer
- Rule 3 ("no `document`-level keydown/click listener for dismissal") and the `hint`-mode description didn't account for the shipped Tooltip's WCAG 1.4.13 fix (`78d4c64`), a capture-phase `document` keydown listener that dismisses visible `hint` content on Escape via `preventDefault()` + `stopPropagation()`; both are amended to name it as the one exception, since `popover="manual"` gives `hint` no native Escape handling to delegate to — provable — reviewer
- Rule 8 preferred `scrollbar-gutter: stable` on the root over measuring the scrollbar, with the measured `padding-right` only as a `CSS.supports` fallback. It cannot work here: the lock takes `<body>` out of flow, and a fixed element's containing block is the viewport *including* the reserved gutter, so the body laid out one scrollbar wider than it does unlocked and every centred or right-aligned element jumped by the scrollbar width on every modal open. The gutter is now always held as body padding (`359aa75`), and rule 8 says so — provable — implementer
- The horizontal-shift assertion in `ui_scroll_lock_test.rb` measured `#fade-panel`, which is `hidden` until its own demo opens, so it compared two 0×0 rects and could not fail. Geometry assertions in this scope's lane now assert their reference is actually laid out before comparing (`359aa75`) — provable — implementer
- § Behavior said nothing about a morphing refresh, and a morph closed every open Dropdown, Popover and Select and left dangling ARIA behind: the server's markup has no id on a panel or a Select's root, so the morph replaced those elements and disconnected the controller. Added as § Behavior item 20, the ruling in `ui-stress-page/open-questions.md`, with the guard and re-sync in `ui--overlay` and `ui_overlay_morph_test.rb` — provable — implementer
- That guard is `layer` and `hint` modes only, confirmed by the orchestrator on 2026-09-15: a Modal the server's markup no longer contains is closed by the host's own intent, expressed by `data-turbo-permanent` on the container the Modal + Turbo guide teaches, and `modal_turbo_morph_refresh_test.rb` pins both sides of it; a menu the user has open is not the host's intent, and is what the guard is for. A first cut guarded every mode and morphed an unmarked Modal back into existence — provable — implementer
- Item 12's focus return didn't hold in two cases the stress page drove: focus the browser parks on an ancestor `<dialog>` after a click on non-focusable content was read as "the user focused something else", and a gesture that closed one layer while opening another restored focus before the browser's own focus of the clicked trigger, which then became the new overlay's return target. `ui--overlay` now treats parked focus as lost, takes its trigger as the return target, and defers the restore to the next frame — provable — implementer
- Item 12's focus return silently declined when its target could not take focus yet. ui-select's rebuilt search mode exposed it on 2026-09-18: DOM focus now sits inside the popup, so when a Turbo Stream replaced an open Select inside a Modal, the old overlay restored onto a control the new component had not yet revealed, `focus()` did nothing, and the Modal parked focus on its `<dialog>` — six stress-page failures. The old shape had only survived because Turbo's own id-keyed focus preservation re-focused the control. The return now retries once on the next frame, only while focus is still stranded, and `closeWithoutFocusReturn()` was added beside it for a Tab-close. Both have their own test in `ui_overlay_focus_test.rb`; item 12 records them. The retry changes existing behaviour and was ratified by Jonathan Simmons the same day. Caught by the stress page, through ui-select's builder — provable — implementer
