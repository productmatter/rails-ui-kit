depends_on:
  - ui-component-base: every component in this scope inherits `Ui::Base` and declares its axes through its `class_variants` and `data_slot`
  - ui-design-tokens: every colour class names a token, and two token values (`--input`, dark `--destructive`) must change before the form controls and destructive text can meet § Business rules, rule 4
part_of:
  - ui-component-library: the parent-map this scope decomposes from (Phase B)
supersedes: []
conflicts_with: []
