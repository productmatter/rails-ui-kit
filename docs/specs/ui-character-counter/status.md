## State

ratified

Shaped and ratified 2026-09-18 by Jonathan Simmons, who decided the four design
questions the shape turned on: a soft `limit:` rather than `maxlength`; the count on the
description's line at the inline-end; destructive text and nothing else past the limit;
announcements at thresholds only. One consequence was flagged rather than assumed — the
counter needs a Field to render in (§ Behavior, item 3) — and was ratified with the
rest. Built 2026-09-18 (`88c9b26`): every agent-loopable check passes on its own run
line, and the build corrected one thing the shaping got wrong, the line-break count
(§ Corrections). What remains is the judgeable review and Jonathan's human gate, the
VoiceOver pass on the docs demo.

## Done

None.

## In progress

None until ratified. Build order once it is: the two Textarea keywords and their
misuse errors; the count rendered by Field at the end of the description part, and the
part rendered when only a count is present; `ui--character-count` with the code-point
and line-break counting and the three thresholds; locale keys in `en` and the `fr`
fixture; the docs page under Utilities; the browser test that proves the counter and a
posted param agree.

## Last green checkpoint

None yet.

## Dead ends

None yet.

## Corrections

- § Behavior, item 7 and the matching assumption said a line break reaches Rails as two characters, `CRLF`, so the counter should count two. The spec asked for that to be verified at build time, and the builder's browser check, posting a value with line breaks through the docs demo, found Rails receiving one: Turbo's default submission re-encodes the form's fields itself and sends a bare `LF`. The shaping had reasoned from a native browser submission, which is not the path the kit's forms take. The counter counts one, on both sides, following the assumption's own contradiction clause; item 7, rule 2 and the assumption now say so, and say that native and multipart submissions do send `CRLF`, with the one-line normalisation a host uses. Caught by the builder's `/agree/` browser test — provable — implementer
- § Behavior, item 9 says the count reads in `text-destructive` past the limit. As built, it did so only when the server rendered a value already past it: the colour class was chosen once, at render, and `ui--character-count` only ever set `data-over`, which no style rule read, so a person typing past the limit saw the count stay grey. The browser check asserted `data-over` and never the painted colour, so it passed, and the orchestrator's audit passed it too. The count now always carries `data-[over=true]:text-destructive`, the server sets `data-over` at render and the controller toggles it, one rule for both; the browser check measures the painted colour before, past and back under the limit, and its contrast. Caught by Jonathan, typing in the docs demo — provable — implementer
