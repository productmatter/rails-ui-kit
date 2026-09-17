depends_on:
  - ui-component-base: the demo surface these primitives are exercised against is built on `Ui::Base`, and the retrofit that consumes them cannot start before it exists
  - ui-test-harness: focus return, Escape ordering across nested top-layer overlays and reference-counted scroll lock are only observable in a real browser, so every `agent-loopable` check here runs in that scope's system-test lane
part_of:
  - ui-component-library: the parent-map this scope decomposes from
supersedes: []
conflicts_with: []
