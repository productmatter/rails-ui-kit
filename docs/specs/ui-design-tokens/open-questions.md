# Open questions — ui-design-tokens

## Is the 33-token set genuinely closed, given Toast needs five semantic status colors?

This is the same question `ui-foundation-retrofit/open-questions.md` asks from the other
side, recorded here because it is *this* scope's claim that is at stake. § Business rules
rule 1 of this spec closes the set at 33 names, "no more, no fewer." § Business rules of
ui-component-library, rule 2 states the same set. `ui-foundation-retrofit` § Behavior needs
five visually distinct status colors for Toast — success, error, notice, alert, info — and
the closed set contains exactly one status-shaped token, `destructive`. `error`/`alert` map
onto it cleanly; `success`, `notice` and `info` have no home. Alert and Badge hit the
identical gap in Phase B, so this is not one component's problem.

Two ratified specs currently contradict each other on this and neither may resolve it
alone: extending the set reopens this scope, and improvising around it violates
§ Business rules of ui-component-library, rule 1. Both scopes hold the question open until
the decider answers.

decider: Jonathan Simmons
options: (a) extend the token contract with status tokens — `success`, `warning` (serving `notice`/`alert`), `info`, each with a `-foreground` pair — documented as kit extensions beyond the shadcn set rather than as shadcn names; (b) collapse the five types onto the existing set — `error`/`alert` → `destructive`, `success`/`notice`/`info` → `primary` or `accent` — accepting that Toast's five types are no longer visually distinct by color and documenting that as a deliberate, named regression; (c) three fixed, non-token `oklch()` literals scoped to Toast only, as a narrow, explicitly documented exception to Business rule 1 rather than a silent violation of it
default: (a) extend — shadcn/ui has this exact gap, so the vocabulary has to come from somewhere regardless of which component asks first; extension degrades gracefully, because an external theme redefines the 33 names it knows and the kit's extensions keep their defaults rather than breaking; and mapping status onto `chart-1`…`chart-5` is semantically wrong, since chart colors are categorical, not semantic
deadline: 2026-09-21
