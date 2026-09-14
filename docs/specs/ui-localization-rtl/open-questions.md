# Open questions — ui-localization-rtl

This one gates the scope. It is the only thing in either localization scope that changes
what the kit promises.

## Does the kit support RTL, and if so how much of it now?

Two scopes recorded a deferral — `ui-positioning-and-navigation` and `ui-select` both say
RTL waits "until a client product needs an RTL locale" — and no client product needs one
today. What has changed is the price. The mechanical half is sixteen classes across five
files, every one with a logical replacement Tailwind already compiles, and the existing
browser geometry checks prove LTR is unchanged for free. The rest is two small JavaScript
behaviours, a `dir` switch in the docs app, and one browser test file. The part that
genuinely cannot be bought is judgment: whether the kit *reads* right in Arabic or
Hebrew, which needs a person who reads one.

decider: Jonathan Simmons
options: (a) build the scope: conversion, the two behaviours, the RTL browser pass and a README statement that says what is machine-verified — with the native-reader gate deferred until a client build ships an RTL language; (b) direction-ready only: convert the sixteen classes and add the guard, make no promise, no RTL lane; (c) keep the deferral: build nothing, and let this spec sit as the costed plan for the day a client needs it
default: (a) — (b) costs nearly as much as (a) and leaves the conversion unobserved, which is exactly the kind of untested claim the browser lane exists to stop; (c) is defensible but the conversion is cheapest now, while the catalog is ten components, and rule 0 means it will not shrink again
deadline: 2026-09-21
