# Open questions — ui-control-sizing

These bind this scope only, not any sibling. Both are decided; neither gates the build.

## Does the kit enforce the 24px target-size floor against a host's token values?

At the kit's defaults, the smallest step is 32px and the floor holds (§ Business rules,
rule 5). If a host sets `--control-height-sm: 1.25rem`, its `sm` controls drop to 20px
and fail WCAG 2.5.8. The kit could stop that by consuming each token through `max()`,
for example `h-[max(24px,var(--control-height-sm))]`. That would put the floor out of
reach of any theme. It would also mean the kit overruling a value the host set on
purpose, when ui-design-tokens rule 7 says the host's theme always wins. And it would
make every height class harder to read. A caller's `class:` could still go below the
floor either way (ui-component-library, rule 5).

decider: Jonathan Simmons
options: (a) no clamp: the floor holds at the kit's defaults and is asserted there, and the docs state that a host token below 24px is the host's accessibility defect; (b) clamp every token consumption with `max(24px, …)`, so no theme can break the floor, at the cost of overruling a host value and noisier classes; (c) no clamp, plus a development-only console warning when a rendered control measures under 24px
default: (a) — the host already owns every other token that can break WCAG, contrast included, and the kit doesn't clamp those either; one documented floor is consistent with that, where (b) singles out one metric and (c) adds a runtime check for a misconfiguration nobody has made
deadline: 2026-09-21
decided: (a), 2026-09-14, Jonathan Simmons — a host that sets a control height below the target minimum has made the same class of choice as one that sets an unreadable contrast pair, and the kit doesn't clamp that either. The kit's own defaults must pass, asserted directly in the browser, and the overriding documentation says plainly that a value under 24px breaks WCAG 2.5.8.

## What does `size:` mean for Textarea?

Textarea's height comes from its content, so a step can't fix it. This spec gives each
step a minimum of one control height plus seven spacing units: 60, 64 and 68px, with
`default` identical to today's `min-h-16` (§ Behavior). That keeps one vocabulary across
a form's fields and follows a host's density retune. The alternatives are defensible
too.

decider: Jonathan Simmons
options: (a) the step moves `min-height` in line with the control height, as specified; (b) Textarea takes no `size:` axis, and a caller sizes it with `rows:` or `class:`; (c) the step moves vertical padding as well as `min-height`, so a `sm` textarea's text sits denser
default: (a) — a form that passes `size: :sm` to every field shouldn't need to know which one is a textarea, and moving only the minimum is the smallest change that keeps Textarea on the shared token; (c) adds a second varying metric that rule 1 declines for every other control
deadline: 2026-09-21
decided: (a), 2026-09-14, Jonathan Simmons — as specified, on the default's reasoning.
