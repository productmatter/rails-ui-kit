depends_on:
  - ui-select: owns the two chrome surfaces this scope changes most — the result-count announcement (its § Behavior, item 21) and the search field's placeholder (item 17, amended 2026-09-18) — and its rule 12 already requires every user-facing string to go through i18n
  - ui-control-sizing: the fixed `--control-height*` steps are what text expansion pushes against; its § Business rules, rule 3 is the guarantee this scope must not break
  - ui-presentational-components: Button's `whitespace-nowrap` and the control conventions § Behavior, item 12 states guarantees for
  - ui-presence-and-overlay-stack: Modal and Toast render their chrome through the overlay lifecycle, and the unsaved-changes prompt runs on its dismiss event
  - ui-field-model-binding: the worked example of content the host translates — `human_attribute_name` and `helpers.label` — which this scope's rule 1 generalises
  - ui-test-harness: the locale-switch, plural, pseudo-locale and escaping checks all run in its browser lane
part_of:
  - ui-component-library: the parent-map this scope decomposes from
supersedes: []
conflicts_with: []
