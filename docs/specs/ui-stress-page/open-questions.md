# Open questions — ui-stress-page

Both are promises no ratified scope makes yet, found while writing the sequences. Per § Business
rules, rule 2, their sequences follow the ruling. They aren't written from whatever the kit
happens to do. Both were decided on 2026-09-15 in the orchestrator's build directive, which also
settled two things that weren't open questions:

- **CI time.** Up to 15 minutes added to the `test-system` job is accepted. The number in
  spec.md § Behavior, item 14 is an estimate, and the build measures it. If the measured lane
  goes over, the CI system job is sharded by directory rather than coverage being trimmed:
  P0's cross is not taken to the diagonal to fit.
- **RTL as a smoke, and the page hidden.** Both confirmed as spec.md § Behavior, items 1 and 7
  author them.

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
decided: (a), 2026-09-15, the orchestrator's build directive. One click outside two layers follows the browser: both close, innermost first. Escape still closes exactly one layer at a time (`ui-presence-and-overlay-stack` § Behavior, item 9). The outside-both sequence declares nothing open and focus per the outer layer's outside-click dismissal.

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
decided: (a), 2026-09-15, the orchestrator's build directive. An open Dropdown, Popover or Select survives a morphing refresh: a refresh another user triggered must not close the menu this user is in. The guard is built in `ui--overlay`, in the shape `ui--field` already has for its swap, pinned in `ui_overlay_turbo_cache_test.rb` or a sibling, and recorded in `ui-presence-and-overlay-stack`'s spec as a Correction. It is built after the `ui-foundation-retrofit` build commits, since that build is moving Dropdown onto `ui--overlay` in the same files.

## Where does focus belong after a Turbo form submission?

Found building the form sequences, 2026-09-15. Turbo disables a form's submitter while its
request runs (`config.forms.submitter.beforeSubmit`, turbo-rails 2.0.23), and Chrome's focus
fixup moves focus off an element that becomes disabled. So after any Turbo submission, focus is
on `<body>`, in every host, whatever the kit does. A toast the response fires is then reached
by F8 from `<body>`, and Escape returns focus there (`ui-toast` § Behavior, item 12, as written).
Invariant 5 was authored to allow `<body>` only after a document render, so the valid-submit
sequence declares `<body>` and cites this question.

decider: Jonathan Simmons
options: (a) accept it as Turbo's and the platform's: the sequence declares `<body>`, and invariant 5 allows `<body>` wherever the element focus returns to was `<body>`; (b) the kit fixes it: `ui--turbo-disable-with`, which every host renders, puts focus back on the submitter when the submission ends if focus fell to `<body>` while it ran, a new promise for every Turbo form in a host; (c) document it in the forms guide and leave behaviour alone
recommendation: (b) — a keyboard user who submits a form and lands on `<body>` has lost their place, an accessibility gap the kit's always-rendered controller is positioned to close; it changes what every Turbo form does, which is why it's asked rather than done
default: (a) until ruled — the sequence as built follows `ui-toast` § Behavior, item 12 from where focus actually was; under (b) its declared focus becomes the Save button
deadline: 2026-09-22
decided: (b), 2026-09-15, the orchestrator's ruling on the Phase 1 report. When a Turbo submission ends and focus has fallen to `<body>` because Turbo disabled the button, `ui--turbo-disable-with` puts focus back on the button, but only if the button is still on the page and nothing else has taken focus: a `422` that focuses an error, or a stream that moved focus, wins. It's pinned in `turbo_disable_with_test.rb` (TDW3, TDW4) and noted on the Turbo Disable With page. The valid-submit sequence with Turbo on now expects the Save button. With Turbo off, the redirect is a full page load, so it still expects `<body>`.
