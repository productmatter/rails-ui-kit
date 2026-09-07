depends_on:
  - ui-presence-and-overlay-stack: `ui--anchor` positions content the overlay stack places, and `strategy: fixed` is required once that scope moves content to the top layer
  - ui-test-harness: roving focus, `aria-activedescendant` and anchor repositioning on scroll and resize cannot be asserted by rendering markup, so this scope's checks run in that scope's system-test lane
part_of:
  - ui-component-library: the parent-map this scope decomposes from
supersedes: []
conflicts_with: []
