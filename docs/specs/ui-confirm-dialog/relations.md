depends_on:
  - ui-component-base: `Ui::Base`, the merge layer the surviving class keywords and `class:` use, and `raise_on_unknown_variant?`, the strict predicate
  - ui-design-tokens: the popover, muted, border and destructive tokens the panel, footer and confirm button read
  - ui-presentational-components: `Ui::ButtonComponent`, which renders Cancel, Confirm and every confirm-variant template
  - ui-presence-and-overlay-stack: `ui--overlay`, which the dialog already opens and closes through, unchanged
  - ui-localization: the four `chrome_string` text keywords this scope renders into `data-default-*` without renaming
  - ui-toast: the shared payload, button, validation and iconography convention (its § Business rules, rules 1 to 5), which this scope adopts rather than restates; nothing here waits on Toast's code
  - ui-test-harness: the browser lane the regression, variant, Turbo and validation checks run in
part_of:
  - ui-component-library: the parent-map this scope decomposes from
supersedes: []
conflicts_with: []
