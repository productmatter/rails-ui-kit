depends_on:
  - ui-component-base: `Ui::Base`, the class-merge layer that makes `class:`, `container_class:` and an action's `class` win, and `raise_on_unknown_variant?`, the strict predicate every validation reads
  - ui-design-tokens: the popover, muted, border and destructive tokens, and rules 5 and 7 under which `--success`, `--warning` and `--info` land as kit extensions
  - ui-presentational-components: `Ui::ButtonComponent`, which renders every action and the close button in every entry point
  - ui-presence-and-overlay-stack: Primitive D replaces the controller's class-swap-and-timeout enter and exit
  - ui-localization: the `Ui::Chrome` override chain and the container-carries-chrome reasoning this scope extends with `region_label` and `actions_hint`
  - ui-test-harness: the browser lane every timing, focus, entry-point and URL check runs in
part_of:
  - ui-component-library: the parent-map this scope decomposes from
supersedes: []
conflicts_with: []
