depends_on:
  - ui-test-harness: the browser lane, `ApplicationSystemTestCase`, `assert_accessible`, the CDP session and `SLOW=1`, all of which the stress files and the shared invariant helper build on
  - ui-presence-and-overlay-stack: the open-state, focus-return, scroll-lock, removal and page-cache contracts most invariants and every dismissal expectation cite
  - ui-foundation-retrofit: Modal, Dropdown, Popover and Tooltip on the primitives, the surface the overlay cluster renders
  - ui-modal-turbo: the frame-target Modal, replace-while-open, focus return after a replacement, and the permanent container a morph keeps open
  - ui-select: both Select modes, nesting over a dialog, page-cache resting state and morph behaviour
  - ui-choices: the list and card variants and the required checkbox group's controller in the form
  - ui-field-model-binding: Field over an ActiveModel record, the enum-backed Select and the help-to-error swap the form re-renders
  - ui-toast: the occluded action toast over a Modal, F8 and Escape reach, and `turbo_stream.ui_toast`
  - ui-confirm-dialog: the self-contained shared dialog and `data-turbo-confirm` opened from inside a Modal
  - ui-control-sizing: the size steps the size row renders
  - ui-localization: the pseudo-locale and the `?locale=` parameter one condition uses
  - ui-localization-rtl: the logical classes the RTL smoke runs over, and the deferral that keeps it a smoke
  - ui-design-tokens: the `.dark` contract the theme condition proves
part_of:
  - ui-component-library: the parent-map this scope decomposes from, and whose rule 7 it turns into a checked property
supersedes: []
conflicts_with: []
