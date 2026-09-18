---
slug: ui-presentational-components
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: medium
size: large
target_model: standard
created: 2026-09-13
loop_budget: 8
---

## Intent

Phase B of ui-component-library: presentational components — markup, variants and
tokens, no controller of their own — built on the foundation Phase A shipped. Button
already shipped under this scope's name without a written convention. This spec exists
to fix one convention, derived from what Button actually does, so every batch worker
builds the same kind of component. It sets conventions and a variant axis per
component. It does not write each component's full API; the batch worker does that
against these rules. The scope originally covered twenty components; sixteen,
including Card, were cut against ui-component-library's rule 0 on 2026-09-13 (§ Out of
scope / deferred, `status.md`). What remains is Button, Input, Label and Textarea.

## Goal

Every component in § Behavior ships on `Ui::Base` with its unit test, browser
accessibility test and docs page, and a reader moving between any two of them finds
the same constructor shape, class conventions and test idiom.

## Non-goals

- Not full per-component APIs. § Behavior names each component's variant axes only.
- Not new tokens. Colour comes from the existing token set (§ Business rules of
  ui-component-library, rule 2); `--success`/`--warning`/`--info` stay unbuilt, see
  `open-questions.md`.
- Not behaviour. Nothing here adds or consumes a Stimulus controller (rule 7).
- Not a retrofit of the seven legacy components. That's `ui-foundation-retrofit`.

## Behavior

**Precedents.** `Ui::ButtonComponent` is the reference for a single-element component
with variant axes. When this spec is silent, do what it does.

**The components.** One line each: what it is, and its variant axes. `—` means no axis;
size and shape come from the caller's `class:`.

| Component | What it is | Variant axes |
|---|---|---|
| Input | A native `<input>` styled as a form control. | — |
| Label | A native `<label>`, dimmed when its peer control or group is disabled. | — |
| Textarea | A native `<textarea>`, same control styling as Input. | — |

**Build order.** Input, Label and Textarea ship in the first batch, since Field and
`Ui::FormBuilder` build on them (`open-questions.md`). They have no dependencies on
each other.

## Business rules

These refine § Business rules of ui-component-library, rules 1, 5, 6 and 9, and
§ Business rules of ui-component-base, rules 1–5. They don't weaken any of them.

1. **Built on `Ui::Base`, shaped like Button.** Each component declares `data_slot`
   explicitly and its axes through `class_variants`, with `defaults:` naming `:default`
   where an axis has one. `initialize` takes one keyword per variant axis, defaulted,
   plus `**html_attributes` passed to `super`. A keyword exists only when the component
   does something with the value: a default, a derived attribute, a switched element
   (Button's `href:`, `type:`, `disabled:`). Anything else — `name:`, `value:`,
   `placeholder:`, `id:` — flows through forwarding. Invalid and disabled states are
   styled from the attribute (`aria-invalid:`, `disabled:`), never a Ruby keyword, so
   field binding can set them later. A part that looks like a Button renders
   `Ui::ButtonComponent`; it never copies Button's class table. The caller's `class:`
   wins, except over a modifier-scoped default, where the caller passes the same
   modifier (ui-component-library, rule 5); a component documents each such default
   it has.
2. **Tokens only, and literal class strings.** No palette literal — `white`, `black`,
   `neutral-*`, `gray-*`, `red-*` or any other Tailwind palette colour — appears
   anywhere under `app/components`, comments included. Colour comes from `background`,
   `foreground`, `card`, `popover`, `muted`, `accent`, `secondary`, `primary`,
   `destructive` and their `-foreground` pairs, plus `border`, `input` and `ring`.
   A border that *identifies* a component — reads as the edge of a distinct shape the
   way a form control's outline does, not just a rule between content — uses `input`
   and meets the same 3:1 rule 3 sets for a control's boundary. A border that is
   purely decorative uses `border` and is exempt from 3:1. "Border is for decoration"
   is too loose on its own: the test is whether the border *identifies*, not whether
   the element happens to be a form control. Every class is a
   complete literal string in the component's source, because Tailwind only compiles
   what it finds there. Never interpolate into a class name (`"aspect-[#{ratio}]"`). A
   runtime value goes through an element attribute or a fixed variant set.
3. **Accessibility is part of done** (ui-component-library, rule 6). Use the semantic
   element: a native control, and never `role="button"` on a `<div>`. Every docs
   snippet with caller-supplied icon-only content shows the `aria-label`. Text reaches
   4.5:1 and a non-text indicator that carries meaning (a control's boundary, a focus
   indicator) reaches 3:1, on every token surface, in light and in dark. Focus is
   drawn with an outline, never a box-shadow ring, because forced-colors mode drops
   box-shadows, and in one of two forms (decided 2026-09-18, Jonathan Simmons; before
   then every control drew the second). **A control with a border and a plain fill** —
   Input, Textarea, Select's control, the outline Button, a Choices card — draws one
   fused line: its border takes `--ring` and a 2px `--ring` outline sits flush against
   it, `focus-visible:border-ring focus-visible:outline-2 focus-visible:outline-ring`
   with no offset, so the eye sees a single solid line and nothing in the layout moves.
   A border, a gap and a ring read as two lines where one would do. **A control that
   can be filled with the focus colour** — a filled Button, a Choices indicator, which
   is `--primary` when checked — keeps the stand-off form,
   `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring`,
   because a line pressed against its own colour would disappear. Either way the line
   reaches 3:1 against what it touches: the surface outside it and, for the fused form,
   the control's fill inside it. An invalid control's fused line is `--destructive`,
   border and outline both. One field has no border of its own to fuse with, the search
   field inside Select's popup: its row draws the line instead, inset so the popup cannot
   clip it (ui-select § Behavior, item 17). Pointer
   targets meet WCAG 2.2's 24×24 CSS px minimum, except inline text links. Where a
   token value makes a rule unmeetable, the worker stops and escalates. Never paint
   around it with a literal (§ Assumptions).
4. **Two test files per component, in the shipped idiom.**
   `test/components/ui/<name>_component_test.rb` (`ViewComponent::TestCase`) covers the
   element and markup, every value of every axis (looped, as Button's test does),
   `data-slot` on the root, attribute forwarding including `data:`/
   `aria:` merge, and caller-class-wins against a variant class. `test/system/<name>_test.rb`
   (`ApplicationSystemTestCase`) visits the component's docs page and runs
   `assert_accessible(within: '#<name>-preview')` in light mode, then again after adding
   `.dark`. A focusable component also asserts that its focus outline survives emulated
   forced colours and reaches 3:1. A form control also asserts that its boundary
   reaches 3:1. These measurements use one shared colour-probe helper extracted from
   `test/system/button_test.rb`, never a copy of it.
5. **One docs page per component.** One entry in the docs registry plus one view file
   under `examples/app/views/docs/`. The page shows every variant value, a usage
   snippet, and a props table, with every
   rendered example inside a single `id="<name>-preview"` element the browser test
   scopes to. Every usage snippet renders through
   `examples/app/helpers/code_examples_helper.rb`, never an inline ERB block written
   directly in the docs view: a snippet that itself contains `%>` breaks ERB's
   scanner, which matches the *first* `%>` it finds and cuts the snippet away from the
   surrounding template. Three workers hit this independently before it was pinned
   down here.
6. **Two defaults learned from a real mismatch.** (a) Form controls (Input, Textarea,
   and Select's box) and anything that reads as one (Button's outline variant)
   are `bg-background` in light mode and `dark:bg-muted/50` in dark. **Amended
   2026-09-14, Jonathan Simmons:** the light fill was `bg-transparent`, on the argument
   that a translucent fill takes the tint of whatever surface it sits on. In practice a
   transparent control inside a muted card read as a sunken grey panel rather than as an
   input, so controls now carry an explicit fill in both modes and read as controls on any
   surface; the cost, accepted, is that on a host surface other than `--background` the
   light fill is a visible patch. And the
   fill comes from a *surface* token, never from `--input`: `--input` is the control's
   boundary and is tuned light enough to reach 3:1 (§ Assumptions), so deriving the fill
   from it makes the fill track the border and washes the control out — measured, it
   drove `--muted-foreground` placeholder text on a dark filled control down to 3.47:1
   (decided 2026-09-13, Jonathan Simmons). `--muted` at 50% keeps the fill's shipped
   visual weight and leaves every text pair on it above 5.8:1. (b) The kit paints
   no page colour, so a host whose `<body>` has none shows the browser's white under
   dark-mode components. The install guide tells hosts to put
   `bg-background text-foreground` on `<body>`.
7. **No new Stimulus controllers.** A component that turns out to need one — to open,
   toggle, detect an image failure or measure — leaves this scope and is recorded in
   `status.md`. Behaviour is never smuggled in through inline script, a `data-action`
   on a legacy controller, or a CSS hack that fakes state.

## Assumptions

- **Phase A's layers exist and are stable.** `Ui::Base` (ui-component-base), the token
  layer with its `@theme inline` mapping and the host-wins layering (ui-design-tokens,
  rules 6 and 7), and the browser lane with `assert_accessible` (ui-test-harness) are
  all on this branch. A component that needs a change to any of them escalates instead
  of working around it locally.
- **`dark:` means `.dark`.** Rule 7(a) uses the `dark:` variant. It agrees with the
  tokens only because the install generator writes `@custom-variant dark` for `.dark`
  into the host (ui-design-tokens, rule 8).
- **The two token values that contradicted rule 3 are retuned** (decided 2026-09-13,
  Jonathan Simmons; values in `ui-design-tokens`). `--input` was 1.27–1.29:1 against
  `--background`/`--card` in light and 1.52–1.64:1 in dark; it is now
  `oklch(0.62 0.012 75)` light and `oklch(0.69 0.011 75)` dark, so a control's boundary
  reaches at least 3:1 on `--background`, `--card`, `--popover`, `--muted` and `--accent`,
  and in dark also against the translucent fill of rule 6(a). `--border` is unchanged:
  decoration is exempt. Dark `--destructive` was 3.49:1 as text on `--background` and
  3.22:1 on `--card`; it is now `oklch(0.71 0.14 27)` with `--destructive-foreground`
  `oklch(0.2 0.02 27)`, mirroring dark `--primary`, so destructive text reaches at least
  4.5:1 on every dark surface. Light destructive was already 6.8:1 and is unchanged.
  Control boundaries and destructive text are therefore no longer blocked for Input,
  Textarea and outline Button. A batch worker still
  builds with the token names: never a literal or an alpha tweak to pass the check.
- **The retune is why a control's fill no longer comes from `--input`** (rule 6(a)).
  While the dark fill was `bg-input/30`, lightening `--input` lightened the fill with it
  and `--muted-foreground` placeholder text on a filled control fell to 3.47–4.47:1.
  `--muted-foreground` itself is unchanged: weakening "muted" for every component in the
  kit to fix one control's fill treats the symptom. The fill moved to `dark:bg-muted/50`
  instead, which restores 5.86–6.70:1 for that pair.
- **The palette is Tailwind's slate and indigo** (decided 2026-09-17, Jonathan Simmons;
  values in `ui-design-tokens`). Every token is a verbatim Tailwind v4 step, so the
  2026-09-13 values above are superseded. `--input` is slate-500
  `oklch(0.554 0.046 257.417)` light and slate-400 `oklch(0.704 0.04 256.788)` dark:
  Tailwind's own slate-300 input border is about 2.6:1, under rule 3, so the kit steps
  darker, to 4.35–4.77:1 light and 5.58–7.68:1 dark against every surface and the
  `dark:bg-muted/50` fill. Light `--destructive` is red-700 `oklch(0.505 0.213 27.518)`,
  not Tailwind's red-600 button step: red-600 is 4.35:1 as text on `--muted`, which
  `field_test.rb` caught in the browser; red-700 is 5.86–6.42:1 on every light surface
  and carries a white label at 6.42:1. Dark `--destructive` is red-400 with a slate-950
  label (5.07–6.97:1 as text) and dark `--primary` is indigo-400 with the same dark
  label (indigo-500 is 3.2–4.4:1 as link text), both by the 2026-09-13 precedent.
  `--border` is still decoration, slate-200 and slate-800. The ratios are computed
  (oklch to sRGB), then held in the browser by `field_test.rb`, `tokens_test.rb` and the
  per-component contrast checks. The rule stands: token names, never a literal or an
  alpha tweak, to pass the check.
- **The docs registry lands first.** Another in-flight unit on this branch replaces
  per-page controller actions and routes with a registry. Rule 6 assumes it. Until it
  exists, no docs page in this scope is added.

## Critical files

- `app/components/ui/base.rb` — the foundation every component inherits; not modified here.
- `app/components/ui/button_component.rb`, `button_component.html.erb` — single-element precedent.
- `app/assets/tailwind/rails_ui_kit/engine.css` — the tokens rule 2 limits colour to.
- `test/components/ui/button_component_test.rb` — unit test idiom.
- `test/system/button_test.rb` — browser test idiom and the colour probe to extract.
- `examples/app/views/docs/` and the docs registry — where each page lands.
- `examples/app/views/docs/installation.html.erb`, `README.md` — the install guide rule 6(b) amends.

## Acceptance checks

### agent-loopable

- The unit lane is green — run: `bundle exec rake test`
- The browser lane, including every component's accessibility audit in light and dark, is green — run: `bundle exec rake test:system`
- No palette literal appears in any kit component outside the seven legacy components `ui-foundation-retrofit` owns (§ Business rules, rule 2) — run: `! grep -rnE -- '-(white|black)\b|-(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-[0-9]{2,3}\b' app/components | grep -vE '^app/components/ui/(confirm_dialog|dropdown|modal|popover|toast|toast_container|tooltip)_component\.'`
- Every docs registry entry has its view and every docs view has its entry (§ Business rules, rule 5) — run: `bundle exec rake test TEST=test/docs_pages_test.rb`
- Every component in § Behavior has both test files (§ Business rules, rule 4) — run: `bash -c 'for c in input label textarea; do test -f test/components/ui/${c}_component_test.rb && test -f test/system/${c}_test.rb || { echo "missing tests: $c"; exit 1; }; done'`

### judgeable

- Input, Label and Textarea read as one family with Button: the same constructor shape and forwarding (§ Business rules, rule 1), and the same test layout (rule 4). No component has a local dialect a reader has to learn separately.
- The accessibility guarantees axe cannot see hold: semantic elements, names on kit-rendered icon-only affordances, 3:1 non-text indicators and forced-colors focus, per § Business rules, rule 3.
- No component carries behaviour, per § Business rules, rule 7; anything that needed it is recorded as moved out of scope in `status.md`.

### human-gate

- Jonathan reviews every rendered docs page in light and in dark mode, on both `--background` and `--card` surfaces, before this scope ships.

## Out of scope / deferred

- **Button** — shipped. It's this spec's precedent, not its work. Where it contradicts
  a rule here, the conflict goes to Jonathan (`status.md`), not a silent change.
- **Card, plus fifteen of the original eighteen § Behavior rows — cut against
  ui-component-library's rule 0 on 2026-09-13.** Native Select, Input Group, Badge,
  Alert, Avatar, Separator, Skeleton, Spinner, Progress, Table, Breadcrumb, Pagination,
  Button Group, Empty and Item, plus Card (this spec's former compound precedent),
  owned neither a Rails/Turbo concept nor a genuinely hard browser behaviour. Deleted
  rather than kept as docs recipes; none had shipped on `main`. See
  ui-component-library § Out of scope / deferred and this scope's `status.md`.
- **Field and the light-behaviour group** — Field, Checkbox, Switch, Toggle, Toggle
  Group, Radio Group, Accordion, Collapsible and Scroll Area each need field binding or
  a Stimulus primitive (`ui-positioning-and-navigation`).
- **The overlay family** — `ui-overlay-components`.
- **`Ui::FormBuilder`** — builds on Input, Label and Textarea; not part of this scope.
- **Anything needing the shared Stimulus primitives** — rule 7.
- **New status tokens and variants** (`--success`, `--warning`, `--info`) — see
  `open-questions.md`.
- **Typography** — a docs style-guide page, not a component (ui-component-library
  § Out of scope / deferred).
