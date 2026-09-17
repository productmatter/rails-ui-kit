# Open questions — ui-choices

Scope-level only. Each binds this scope; none binds a sibling.

## Does a required checkbox group get the one controller, or stay JavaScript-free?

The platform can't say "at least one of these checkboxes". `required` on a checkbox
means that box must be checked, and ARIA's `group` role has no required state. So the
group is either enforced by `ui--choices`, which calls `setCustomValidity` on the first
checkbox while none is checked (§ Behavior, item 14), or not enforced in the browser at
all.

decider: Jonathan Simmons
options: (a) ship `ui--choices` for required checkbox groups only, enforcing at least one with the chrome string as the message; (b) no JavaScript at all — a required checkbox group shows the marker and the screen-reader hint, and the server's validation is the only enforcement; (c) ship `ui--choices` with `min:`/`max:` as well, since the count check is the same code
default: (a) — a required Select, Input and radio group all block an empty submission in the browser, and a required checkbox group that alone doesn't would be the kit's one inconsistent control; Field derives `required` from the model, so this arrives without the caller asking. (c) builds counts no client form needs yet
deadline: 2026-09-21
decided: (a), 2026-09-14, Jonathan Simmons, relayed by the orchestrator — "every other required control in the kit blocks an empty submit; a group that doesn't would be the inconsistency. Min/max stays out of v1." Recorded in § Behavior, item 14 and § Business rules, rule 4. The controller passes the decider's lean-on-the-platform test, the one the media-query primitive was removed under, only because the browser has no native "at least one checked" constraint. It is not redundant, and it must not be removed as if it were.

## Should a checked, disabled checkbox keep its value on save?

A disabled input is never submitted. So a role that's checked and disabled (say "Owner",
which this user may not remove) disappears from `role_ids` the moment the form is saved.
Rails' own `collection_check_boxes(disabled: [...])` markup behaves the same.

decider: Jonathan Simmons
options: (a) follow the platform and Rails — disabled values don't submit; the guide warns and shows the server-side merge that keeps a locked value; (b) render one hidden input per checked disabled value, so a locked choice survives the save, as a deliberate deviation from Rails recorded under § Business rules, rule 3; (c) raise in development and test when a value is both in `checked:` and `disabled_values:` on a checkbox group, forcing the caller to choose
default: (a) — it matches Rails and Select exactly, and the server has to enforce a locked value anyway
deadline: 2026-09-21
decided: (b), 2026-09-14, Jonathan Simmons, relayed by the orchestrator, overriding the default — "saving deletes a value the form showed the user as checked and locked: data loss that contradicts what was on screen. Carry locked checked values in hidden inputs, following the same reasoning as the `<fieldset disabled>` deviation." It applies to both variants (§ Behavior, item 7). The docs page and the guide must say plainly that **a locked checkbox is not authorization**: a hidden input can be removed or edited in the browser, so the server still decides what a user may change.
