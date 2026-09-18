depends_on:
  - ui-field-model-binding: the help-text row, its swap with the error (§ Behavior, items 19 and 22) and the computed description (item 20) are where the count renders and what it must never fight
  - ui-presentational-components: Textarea's constructor shape and forwarding (§ Business rules, rule 1) — `counter:` and `limit:` are consumed keywords, like `size:`
  - ui-localization: every counter string is chrome under `rails_ui_kit.character_counter.*`, pluralised the way `select.results` is, with the call-site override
  - ui-localization-rtl: the count sits at the inline-end through logical utilities
  - ui-test-harness: the browser lane every acceptance check runs in
part_of:
  - ui-component-library: the parent-map this scope decomposes from
supersedes: []
conflicts_with: []
