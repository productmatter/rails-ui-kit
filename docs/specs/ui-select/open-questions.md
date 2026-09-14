# Open questions — ui-select

Scope-level only. Each binds this scope; none binds a sibling.

## On a phone, does select-only mode keep the native picker?

A native `<select>` on iOS and Android opens the platform picker: a wheel or sheet that
is large, familiar and reachable by thumb. Select-only mode replaces it with a popup
listbox built for keyboard and pointer. For search mode the answer is obviously the
custom popup, since no native picker searches. For select-only mode on a coarse pointer,
the custom popup is arguably worse than what the phone already does well.

Keeping the native picker there is cheap, because the unenhanced native select is
already the no-JavaScript path (§ Behavior, item 2), and the swap itself is one media
query in the component's own CSS. The cost is a second enhanced/unenhanced branch to test.

decider: Jonathan Simmons
options: (a) select-only mode stays unenhanced — the styled native select and its platform picker — when `(pointer: coarse)` matches, and search mode always enhances; (b) enhance everywhere, so there is one behaviour on every device; (c) a per-instance `native_on_touch:` option, defaulting to (a)
default: (a) — the platform picker is the better phone experience, the unenhanced path is already built and tested for no-JS, and it keeps the custom popup where it adds something (search, keyboard, desktop styling)
deadline: 2026-09-21

## Does v1 ship a Capybara helper for host system tests?

Enhanced, the native select is `opacity: 0`, so Capybara's `select "Pending", from:
"Status"` no longer finds a visible select. Every host system test that picks a value
from a field this component renders would break on upgrade. A kit helper
(`ui_select "Pending", from: "Status"`) that opens the combobox and chooses the option
the way a user does would fix that. It would live in `lib/rails_ui_kit/test_helpers`,
for host test suites to include.

decider: Jonathan Simmons
options: (a) ship the helper in v1, with its own system test, and document it in the guide; (b) defer it and document `select "Pending", from: "Status", visible: :all` as the workaround, which sets the value without exercising the widget; (c) defer it with no workaround documented
default: (a) — it is a few lines, and without it the first host to adopt Select finds its test suite red on upgrade
deadline: 2026-09-21
