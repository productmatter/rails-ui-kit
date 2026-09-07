# Open questions — ui-component-library

Parent-level only. A question that binds a single scope belongs in that scope's own
`open-questions.md`.

## How does the breaking Phase A foundation reach `main`?

Phase A changes every rendered class, and two consumers track this gem unpinned on
`main`. The pinning precondition (spec.md § Assumptions) removes the danger, but not
the choice of integration shape — and the choice determines whether `main` is
consumable mid-phase.

decider: Jonathan Simmons
options: (a) each Phase A scope merges to `main` on its own, after both consumers are pinned to v0.2.0 — `main` is knowingly mid-migration until the retrofit lands, and v0.3.0 is tagged when it does; (b) Phase A accumulates on a long-lived integration branch and merges to `main` once, as a single v0.3.0 release — `main` stays consumable throughout, at the cost of a large merge and delayed integration signal
default: (a) — the pin makes a mid-migration `main` harmless, and scope-by-scope merges keep the integration signal early and the diffs reviewable, which is worth more than a consumable `main` nobody is consuming
deadline: 2026-09-21

## Are the four non-component utility Stimulus controllers in scope for the retrofit?

Four of the eleven shipped controllers back no component: `dark_mode`,
`form_change`, `turbo_confirm`, `turbo_disable_with`. The foundation work is defined
against components, so their fate is unstated. `dark_mode` is the sharpest case — the
token layer's `.dark` class toggle (Business rule 3) is presumably the thing that
controller already drives, so it may need to change even under a "leave it alone"
answer.

decider: Jonathan Simmons
options: (a) leave all four untouched as utility controllers, explicitly outside the retrofit, and have `ui-design-tokens` confirm `dark_mode_controller` already toggles the `.dark` class the token layer expects; (b) bring all four into `ui-foundation-retrofit` and hold them to the same primitive-consumption rules as components; (c) split them into a separate scope with its own decision per controller
default: (a) — they solve unrelated problems and consume none of the six primitives; the only real coupling is `dark_mode` ↔ the `.dark` toggle, which is cheap to verify inside the token scope
deadline: 2026-09-21

## What does "v1" mean, and when is the eject generator revisited?

The eject generator is deferred "to v2" (spec.md § Out of scope / deferred), and
Phase A targets v0.3.0. Nothing states what version the phases add up to, so "v2"
has no anchor and the deferral has no trigger date.

decider: Jonathan Simmons
options: (a) v1.0.0 = Phases A, B and C shipped and Phase D decided; the eject generator is the headline of the v2 line and is revisited when a consumer first needs to fork a component's markup, whichever comes first; (b) v1.0.0 is declared as soon as Phase A ships, treating breadth as additive minor releases; (c) leave the version line unstated and track the eject deferral against consumer demand alone
default: (a) — it gives the deferral a concrete trigger and matches the phasing already committed to
deadline: 2026-09-21
