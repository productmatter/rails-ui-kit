# Open questions — ui-stress-page

Both are promises no ratified scope makes yet, found while writing the sequences. Per § Business
rules, rule 2, their sequences follow the ruling, or the default if none arrives in time. They
aren't written from whatever the kit happens to do.

## What does one outside click do when a layer is open inside a Modal?

`ui-presence-and-overlay-stack` § Behavior, item 9 says Escape closes exactly one layer. Nothing
says what a click outside *both* layers does. Take a Dropdown open inside a Modal, and a click
on the Modal's backdrop:

- The browser's light dismiss closes the Dropdown's `popover="auto"` content, which is delegated
  to the platform (rule 1).
- The Modal's backdrop-click close is the kit's own.

So today one click may close two layers, or one, depending on event order. On the page, a click
outside a Select inside a dialog Dropdown already closes both, natively.

decider: Jonathan Simmons
options: (a) follow the platform: a click closes every layer it lands outside of, innermost first, and Escape stays one layer at a time; (b) one gesture, one layer: the kit suppresses the Modal's backdrop close when the same click light-dismissed a layer, and a click outside two page-level layers still closes both, because the browser does that and suppressing it means reimplementing light dismiss; (c) leave it unspecified and generate no outside-both sequence
default: (a) — it is what the browser already does for layers, it keeps rule 1's delegation intact, and reverse order (parent rule 7) still holds; (b) buys consistency with Escape at the cost of a special case in the Modal and an inconsistency between modal and page-level nesting; (c) leaves a real gesture untested
deadline: 2026-09-22

## Does an open layer stay open through a morphing page refresh?

A morphing refresh keeps matched elements and rewrites their attributes to the server's markup.
A Dropdown, Popover or Select open outside a `data-turbo-permanent` element has server markup
that says closed, with `hidden` and no `data-state="open"`. Its element and controller survive,
and the browser's popover-open state isn't an attribute. The likely result, unverified, is a
popover still in the top layer while its `hidden` and `data-state` say closed. Invariants 2 to 4
would catch that, but no scope says which honest state is right.

The refresh that matters is a broadcast (`broadcasts_refreshes`), which arrives while someone
else's user is mid-choice.

decider: Jonathan Simmons
options: (a) the layer stays open: `ui--overlay` guards its own open-state attributes during a morph, as `ui--field` already does for its swap (`ui-field-model-binding` § Behavior, item 22), and re-syncs its content; (b) the layer returns to its closed resting state with focus on its trigger, as on removal and page cache (`ui-presence-and-overlay-stack` § Behavior, items 18 and 19); (c) unspecified, and hosts mark anything that must survive `data-turbo-permanent`
default: (a) — a refresh another user caused shouldn't close the menu this user is choosing from, morphing exists to preserve exactly that state, and the kit already has the pattern in Field; the cost is a morph guard in `ui--overlay`, owned by `ui-presence-and-overlay-stack`, which this scope's build would implement as a defect fix once ruled
deadline: 2026-09-22
