# Open questions — ui-confirm-dialog

## Do the class keywords survive, merged, or go as `ui-foundation-retrofit` ratified?

The retrofit ratified deleting all nine `*_class:` keywords, and replacing them with per-part
`class:` overrides through `Ui::Base`. Its reason was that the `DEFAULTS` hash replaces
classes wholesale, which exists only because there was no merge layer. `Ui::Base` still
ships no per-part API (`ui-component-base` § Assumptions: slots are content-only), so "a
per-part `class:`" would be a new mechanism for one component. It would also be named
exactly like the keywords it replaces. And the decider's 2026-09-14 ruling makes the icon
content, so `icon_class:` has nothing left to style.

decider: Jonathan Simmons
options: (a) keep eight keywords (`wrapper_class` … `icon_wrapper_class`) with merge semantics onto the token defaults, remove `icon_class:`, and give UPGRADING a "now merged, not replaced" entry; (b) delete all nine as ratified, and invent a per-part `class:` mechanism for this component; (c) delete all nine and offer no per-part styling beyond the root `class:` and the slots
default: (a) — merging removes the defect the retrofit named (replacement) without breaking a single call site: a Tailwind class string that used to replace the defaults now mostly reproduces itself on top of them, so the two unpinned consumers get a visual near-no-op, not an `ArgumentError`; (b) is new API surface for one component with the same names in a different shape; (c) leaves a caller no way to restyle the footer or buttons, which parent rule 5 promises
deadline: 2026-09-21
decided: (a), 2026-09-14, the orchestrator's ruling that ratified this scope. Eight keywords stay, merged onto the token defaults with `tailwind_merge`, and `icon_class:` is removed. Deleting all nine would break every 0.2.0 app that styles its dialog, and merging fixes what the retrofit named without that break. This reverses `ui-foundation-retrofit`'s ratified deletion, and that scope's text was trimmed to match. UPGRADING states the one behaviour difference: a caller who relied on replacing a default wholesale now gets the default utilities that don't conflict with their classes.
