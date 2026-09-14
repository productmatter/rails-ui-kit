depends_on:
  - ui-localization: the `examples/` locale switch this scope extends with `dir`, and the frame that separates what the kit translates from what it lays out
  - ui-positioning-and-navigation: owns `ui--anchor` (whose Floating UI wrapper resolves `-start`/`-end`) and `ui--roving-focus` (whose horizontal key table this scope reverses); its § Out of scope is where the RTL deferral this scope reopens is recorded
  - ui-presence-and-overlay-stack: the scroll lock's scrollbar gutter, which sits on the wrong side in an RTL document
  - ui-select: four of the sixteen physical classes are Select's, and its popup geometry checks are the LTR baseline
  - ui-control-sizing: its browser measurements (CS3, CS4) are half the proof that LTR rendering did not change
  - ui-test-harness: the RTL browser pass, the accessibility assertions and the LTR regression runs all live in its lane
part_of:
  - ui-component-library: the parent-map this scope decomposes from
supersedes: []
conflicts_with: []
