depends_on:
  - ui-select: `Ui::Select::OptionSet` is the option model this scope moves to `Ui::OptionSet` and shares, and Select's `selected:`/`disabled_values:` and Field routing are the precedents Choices' keywords follow
  - ui-field-model-binding: Field's `label_id`, `control_attributes` and model-bound value are what a group is wired through; both prerequisites in § Assumptions land under that spec
  - ui-presentational-components: the control fill rule (its rule 6(a), amended 2026-09-14), Input's boundary, focus and invalid classes, and Label, all of which the indicator and card follow
  - ui-control-sizing: `size:` accepts that scale's step names, so a form can give every control one size, but Choices reads none of its tokens (decided 2026-09-18)
  - ui-localization: the chrome/content boundary and the call site → host locale → kit default chain for `rails_ui_kit.choices.required_message`, and item 12's "lists wrap" rule
  - ui-localization-rtl: every directional class is logical, held by its `logical_direction_test.rb`
  - ui-test-harness: every submission, keyboard, validation, no-JavaScript, accessibility-tree, appearance and layout check runs in its browser lane
part_of:
  - ui-component-library: the parent-map this scope decomposes from
supersedes: []
conflicts_with: []
