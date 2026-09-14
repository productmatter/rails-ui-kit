depends_on:
  - ui-positioning-and-navigation: `ui--roving-focus`'s `activedescendant` mode and editable-input carve-out carry both key tables, `ui--anchor` positions the popup, and Field binding carries label, description and error; prerequisites 3 and 4 in § Assumptions land there
  - ui-presence-and-overlay-stack: the popup is a `ui--overlay` `layer` in the top layer, animated by `ui--presence`, under that scope's Turbo-cache contract; prerequisites 1 and 2 in § Assumptions land there
  - ui-test-harness: every keyboard, submission, no-JavaScript, Turbo and accessibility check runs in its system-test lane
part_of:
  - ui-component-library: the parent-map this scope decomposes from
supersedes: []
conflicts_with: []
