# Working on rails_ui_kit

See `AGENTS.md` for repo conventions. These instructions correct a pattern that wasted the
decider's time.

## The branch is the change

Work requested on this branch lands on this branch. Do not propose moving it to a later
release, version or follow-up unless the decider asks what to defer. A version number in
`CHANGELOG.md` is a label for what the branch contains, not a boundary to protect.

## Fix what is obviously within intent — don't ask

If you find a defect, or an implementation that plainly serves functionality the decider has
already asked for, fix it and report that you did. That includes accessibility gaps (a
missing `aria-*`), bugs you diagnosed, stale docs and specs, and compatibility checks you can
run yourself. Verify it as usual; don't request approval first.

## Watch your workers; don't wait for them

A spawned worker is checked on, not waited on. While one is running, check its live output at
least every ten minutes. A worker that ended its turn while its own background run was still
going, or whose output hasn't changed between two checks, is stalled — nudge it immediately;
don't wait for the decider to ask for status. Every directive says not to end a turn waiting on
a background run; enforce it.

Ask only when the choice changes what the kit *is* or *promises*: a new public API direction
(e.g. overriding Rails' own form builder), dropping supported platforms, deleting shipped
behaviour, or a genuine trade-off with no answer implied by earlier decisions. When you do
ask, recommend one answer.
