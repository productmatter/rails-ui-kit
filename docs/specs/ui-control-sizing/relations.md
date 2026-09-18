depends_on:
  - ui-design-tokens: the three `--control-height*` tokens are kit extensions under its rule 5, defined in its low-priority `theme.rails-ui-kit` layer so a host's value wins (its rule 7)
  - ui-presentational-components: Button, Input and Textarea, whose conventions (its rules 1–3) the new `size:` axis follows
  - ui-select: the shared native/control box — the select-only combobox, or search mode's trigger button — and the popup's width matching take the step; the popup's search field keeps one height
  - ui-test-harness: every geometry, alignment and target-size check runs in its browser lane
part_of:
  - ui-component-library: the parent-map this scope decomposes from
supersedes: []
conflicts_with: []
