# Open questions — ui-positioning-and-navigation

Scope-level only. Each binds this scope; none binds a sibling.

## Does the Floating UI pin collapse to one CDN pin, now that the four pins are known to work?

`ui-component-library` § Assumptions previously stated that the raw npm package's
"extensionless internal imports do not resolve under importmap." That was not true of
the pinned version: `@floating-ui/dom@1.6.1`'s `.mjs` dist has no relative imports at
all, only three bare specifiers, and `config/importmap.rb` pins every one of them. The
current pins work, and the parent has since been corrected to say so. What is real is
the maintenance exposure — four hand-maintained pins whose versions must stay mutually
compatible, shipped by an engine whose own header invites hosts to override any single
one. This needs the decider because it moves a runtime dependency under two live
consumers, not because anything is broken.

decider: Jonathan Simmons
options: (a) collapse to one `cdn.jsdelivr.net/npm/@floating-ui/dom@<version>/+esm` pin and delete the `core` and `utils` pins — the version set moves and is overridden atomically, and the transitive `/npm/…/+esm` specifiers self-resolve against the CDN with no importmap entry (verified reachable); (b) keep the four jspm pins and add a test that asserts the graph closes and the versions satisfy dom's declared ranges — no dependency movement under the two consumers, burden stays but becomes enforced; (c) vendor a bundled build into the engine's asset path — no third-party CDN at runtime at all, at the cost of a build step in the gem and a departure from the peer-dependency model in `package.json`
default: (a) — it removes the version-skew failure mode by construction rather than policing it, and the one-pin surface is strictly simpler than four; but note this is a maintainability change, not a repair, so it should not be scheduled as if something were on fire
deadline: 2026-09-21

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
