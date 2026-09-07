depends_on:
  - ui-positioning-and-navigation: the last foundation scope to ship before the retrofit; this scope deletes the three duplicated `@floating-ui/dom` implementations only once `ui--anchor` exists to replace them, and reaches the token, `Ui::Base` and presence/overlay layers transitively through it
part_of:
  - ui-component-library: the parent-map this scope decomposes from
supersedes: []
conflicts_with: []
