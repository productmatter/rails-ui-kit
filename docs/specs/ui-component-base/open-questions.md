## Should `Ui::Base` auto-derive a component's root `data-slot` value from its class name, or require each component to declare it explicitly?

decider: Jonathan Simmons
options: auto-derive from the component class name (e.g. `ButtonComponent` -> `button`); require an explicit per-component declaration (e.g. `data_slot "button"`); no default at all, left to each component's template
default: require an explicit per-component declaration — auto-derivation mislabels silently on rename and breaks for components with more than one root-level concern
deadline: 2026-09-21
