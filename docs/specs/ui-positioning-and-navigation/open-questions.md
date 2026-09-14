# Open questions — ui-positioning-and-navigation

Scope-level only. Each binds this scope; none binds a sibling.

## Do Radio Group and Toggle Group use `ui--roving-focus`, or their own semantics?

Tabs, Menubar, the menus, Navigation Menu, the listboxes and Accordion headers are
settled consumers. Radio Group and Toggle Group are the ambiguous pair: a native radio
group already has browser-provided arrow-key behavior and a roving tab stop, so wrapping
it can mean reimplementing something the platform does correctly, while a
`role="radiogroup"` built from buttons needs exactly this primitive. The answer changes
whether `ui--roving-focus` needs a selection-follows-focus mode, which native radios
have and menus must not.

decider: Jonathan Simmons
options: (a) native `input[type=radio]` for Radio Group with no primitive, and `ui--roving-focus` for Toggle Group only — no selection-follows-focus mode is needed and the platform keeps the behavior it already gets right; (b) both groups consume the primitive, which gains a `selectionFollowsFocus` value — one consistent mechanism, and a mode that is a bug in every other consumer; (c) defer both to `ui-presentational-components` and decide when the components are actually built
default: (a) — it avoids adding a mode whose correct value is false for every other consumer, and reimplementing native radio keyboard behavior is the kind of build-over-adopt that `ui-component-library` § Business rules 8 warns against
deadline: 2026-09-21
