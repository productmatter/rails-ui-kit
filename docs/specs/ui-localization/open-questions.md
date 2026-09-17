# Open questions — ui-localization

These bind this scope only, not any sibling.

## What does the kit guarantee when translated text outgrows its box?

A German label runs roughly 30% longer than its English source, and a pseudo-locale pass
runs 40% longer. Controls are now a fixed height on one token scale (`ui-control-sizing`),
so the height cannot absorb it. § Behavior, item 12 states the answer this spec assumes:
controls hold their height, a closed Select truncates like a native select, the open list
and tooltips wrap. That last part changes what ships today — Select's options and the
Tooltip both have their text clipped or held on one line — and Select has not had its
human gate yet, so it is worth the decider seeing the choice rather than finding it.

decider: Jonathan Simmons
options: (a) controls hold their height; a closed Select truncates; the open list and Tooltip wrap, so no text is unreadable; (b) truncate everywhere and add a `title` attribute where text is cut, so the box never changes shape; (c) let a long option or tooltip grow the popup wider than its anchor
default: (a) — a truncated option in a popup that matches the control's width is text a sighted user has no way to reach, which is the one case where truncation removes information rather than deferring it; (b)'s `title` is mouse-only and duplicates what a screen reader already gets; (c) breaks the width match `ui--anchor` gives Select and the alignment `ui-control-sizing` exists for
deadline: 2026-09-21
decided: (a), 2026-09-14, Jonathan Simmons — "closed Select truncates like a native select; the open list and Tooltip wrap. A truncated option in a width-matched popup is unreadable."

## Does the kit ship translations, or only English chrome?

Sixteen strings. The kit could ship `fr`, `de`, `es` and `ar` files and every host would
get them free. It would also mean the studio shipping strings nobody here can review,
that a client inherits silently, in a kit whose whole value is that someone cared.

decider: Jonathan Simmons
options: (a) English only, with the 16 strings documented in one table for a host to translate; (b) ship a reviewed set of locales and accept ownership of them; (c) ship them as commented examples in the docs page rather than as loaded locale files
default: (a) — the cost of a wrong accessible name in a language nobody here reads is paid by the client's users, and the host's own locale files already win by load order, so translating 16 strings is a ten-minute job in the app that knows the language
deadline: 2026-09-21
decided: (a), 2026-09-14, Jonathan Simmons — "we can't maintain quality in languages nobody here reads, and a wrong translation is worse than an obvious gap. French stays a test fixture proving the mechanism." The kit ships `en` only; `fr` and `ar` live in `test/fixtures/locales/` and are never packaged.
