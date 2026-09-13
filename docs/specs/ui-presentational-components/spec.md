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

Phase B of ui-component-library: twenty presentational components — markup, variants
and tokens, no controller of their own — built in parallel batches on the foundation
Phase A shipped. Button and Card already shipped under this scope's name without a
written convention. Twenty more built that way come out as twenty dialects. This spec
exists to fix one convention, derived from what Button and Card actually do, so every
batch worker builds the same kind of component. It sets conventions and a variant
axis per component. It does not write each component's full API; the batch worker
does that against these rules.

## Goal

Every component in § Behavior ships on `Ui::Base` with its unit test, browser
accessibility test and docs page, and a reader moving between any two of them finds
the same constructor shape, class conventions, slot anatomy and test idiom.

## Non-goals

- Not full per-component APIs. § Behavior names each component's variant axes only.
- Not new tokens. Colour comes from the existing token set (§ Business rules of
  ui-component-library, rule 2); `--success`/`--warning`/`--info` stay unbuilt, see
  `open-questions.md`.
- Not behaviour. Nothing here adds or consumes a Stimulus controller (rule 8).
- Not a retrofit of the seven legacy components. That's `ui-foundation-retrofit`.

## Behavior

**Precedents.** `Ui::ButtonComponent` is the reference for a single-element component
with variant axes. `Ui::CardComponent` and `app/components/ui/card/*` are the reference
for a compound one. When this spec is silent, do what those two do.

**The components.** One line each: what it is, and its variant axes. `—` means no axis;
size and shape come from the caller's `class:`.

| Component | What it is | Variant axes |
|---|---|---|
| Input | A native `<input>` styled as a form control. | — |
| Label | A native `<label>`, dimmed when its peer control or group is disabled. | — |
| Textarea | A native `<textarea>`, same control styling as Input. | — |
| Native Select | A native `<select>` with a decorative chevron; options take `bg-popover text-popover-foreground`. | `size`: default, sm |
| Input Group | A control with inline or block addons (text, icon, Button); the focus indicator sits on the group. | addon `align`: inline-start, inline-end, block-start, block-end |
| Badge | An inline status label; renders `<a>` when given `href:`, as Button does. | `variant`: default, secondary, destructive, outline |
| Alert | A callout with optional icon, title and description. No live-region role by default; a caller injecting one dynamically passes `role: "alert"`. | `variant`: default, destructive |
| Avatar | An image with a fallback (initials) layered beneath it. No load-detection controller. | — |
| Separator | A rule between content. Decorative by default (`role="none"`); non-decorative gets `role="separator"` and `aria-orientation`. | `orientation`: horizontal, vertical |
| Skeleton | A decorative loading placeholder that stops pulsing under `motion-reduce`. | — |
| Spinner | An inline SVG loading indicator with `role="status"` and an accessible name. | — |
| Progress | A determinate progress bar, native `<progress>` first, with a required accessible name. | — |
| Table | A semantic `<table>` in a scroll container, with caption, header, body, footer, row, head and cell parts. | — |
| Breadcrumb | `nav` › `ol` of links; the current page is `aria-current="page"`, separators are `aria-hidden`, a collapsed ellipsis has a name. | — |
| Pagination | `nav` › `ul` of page links rendered through `Ui::ButtonComponent`; the current page is `aria-current="page"`, previous and next have names. No `pagy` adapter. | link `active`: true, false |
| Button Group | `role="group"` around Buttons, with separator and text parts. | `orientation`: horizontal, vertical |
| Kbd | A `<kbd>` key cap, plus a group part for chords. | — |
| Empty | An empty state with header, media, title, description and body parts. | media `variant`: default, icon |
| Item | A flexible row (media, title, description, actions, header, footer), plus group and separator parts. | `variant`: default, outline, muted; `size`: default, sm; media `variant`: default, icon, image |
| Aspect Ratio | A box that holds its child at a fixed ratio. | `ratio`: square, video, and a small fixed set; any other ratio by caller `class:` |

**Build order.** Input, Label and Textarea ship in the first batch, since Field and
`Ui::FormBuilder` build on them (`open-questions.md`). The remaining seventeen have
no dependencies on each other beyond the parts they reuse (Pagination and Button Group
render Button; Button Group renders Separator; Input Group renders Input, Textarea and
Button).

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
   `border` is for decoration and `input` is for control boundaries. Every class is a
   complete literal string in the component's source, because Tailwind only compiles
   what it finds there. Never interpolate into a class name (`"aspect-[#{ratio}]"`). A
   runtime value goes through an element attribute (`<progress value>`) or a fixed
   variant set.
3. **Compound components follow Card.** Parts are `Ui::Base` subclasses namespaced under
   the parent (`Ui::Item::TitleComponent`), each accepting `class:` and forwarded
   attributes, each with `data-slot="<component>-<part>"` (`item-title`). A fixed
   anatomy uses `renders_one` in a fixed template order, whatever order the caller
   sets them in (Card, Empty, Item). A repeating sequence uses `renders_many` in call
   order, with polymorphic `types:` where different kinds of part interleave (Table rows,
   Breadcrumb items, Pagination items, Button Group children). A structural separator
   the pattern always needs is drawn by the component, not the caller (Breadcrumb). A
   part shadcn calls `Content` is exposed as the `body` slot, since `content` is
   ViewComponent's block; its class and `data-slot` keep the name `content`. A part
   with no slots of its own renders from `call`, not a template. This applies to Table,
   Breadcrumb, Pagination, Item, Empty, Input Group and Button Group.
4. **Accessibility is part of done** (ui-component-library, rule 6). Use the semantic
   element: a native control, `<table>`, `<nav>` with a list, `<kbd>`, `<progress>`,
   and never `role="button"` on a `<div>`. Anything the kit itself renders icon-only
   (pagination previous/next, breadcrumb ellipsis, Spinner) carries an accessible
   name. Every docs snippet with caller-supplied icon-only content shows the
   `aria-label`. Text reaches 4.5:1 and a non-text indicator that carries meaning
   (a control's boundary, a progress fill, a focus indicator) reaches 3:1, on every
   token surface, in light and in dark. Decoration (Separator, Skeleton, a card
   border) is exempt. Focus is drawn as Button draws it,
   `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring`,
   never a box-shadow ring, because forced-colors mode drops box-shadows. A group
   draws it with `has-[:focus-visible]:`. Pointer targets meet WCAG 2.2's 24×24 CSS px
   minimum, except inline text links. Where a token value makes a rule unmeetable, the
   worker stops and escalates. Never paint around it with a literal (§ Assumptions).
5. **Two test files per component, in the shipped idiom.**
   `test/components/ui/<name>_component_test.rb` (`ViewComponent::TestCase`) covers the
   element and markup, every value of every axis (looped, as Button's test does),
   `data-slot` on the root and on every part, attribute forwarding including `data:`/
   `aria:` merge, and caller-class-wins against a variant class. Compound components
   add one test that renders a real ERB template through `render_in_view_context`
   (Card's `nested parts compose from an erb template`), since nested slot capture
   breaks there and nowhere else. `test/system/<name>_test.rb`
   (`ApplicationSystemTestCase`) visits the component's docs page and runs
   `assert_accessible(within: '#<name>-preview')` in light mode, then again after adding
   `.dark`. A focusable component also asserts that its focus outline survives emulated
   forced colours and reaches 3:1. A form control also asserts that its boundary
   reaches 3:1. These measurements use one shared colour-probe helper extracted from
   `test/system/button_test.rb`, never a copy of it.
6. **One docs page per component.** One entry in the docs registry plus one view file
   under `examples/app/views/docs/`. The page shows every variant value, a usage
   snippet, and a props table (or a slots table for a compound component), with every
   rendered example inside a single `id="<name>-preview"` element the browser test
   scopes to.
7. **Two defaults learned from a real mismatch.** (a) Form controls (Input, Textarea,
   Native Select, Input Group) are `bg-transparent` in light mode and `dark:bg-input/30`
   in dark. A translucent fill takes the tint of whatever surface the control sits on,
   whether that's `--background`, `--card` or a host's own panel. A fixed neutral fill
   is right on exactly one surface and a visible patch on every other. (b) The kit paints
   no page colour, so a host whose `<body>` has none shows the browser's white under
   dark-mode components. The install guide tells hosts to put
   `bg-background text-foreground` on `<body>`.
8. **No new Stimulus controllers.** A component that turns out to need one — to open,
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
- **Two token values contradict rule 4 today**, measured from `engine.css`:
  - `--input` against `--background`/`--card` is 1.27–1.29:1 in light and
    1.52–1.64:1 in dark, below the 3:1 a control's boundary needs.
  - Dark `--destructive` as text is 3.49:1 on `--background` and 3.22:1 on `--card`,
    below 4.5:1. Light passes at 6.8:1.

  That blocks the control boundaries of Input, Textarea, Native Select and Input Group,
  and destructive text in Alert and outline Badge. The values are
  owned by `ui-design-tokens`, and the defaults in `open-questions.md` resolve them
  there. **At the contradiction**, a batch worker builds with the token names and does
  not substitute a literal or an alpha tweak to pass the check.
- **The docs registry lands first.** Another in-flight unit on this branch replaces
  per-page controller actions and routes with a registry. Rule 6 assumes it. Until it
  exists, no docs page in this scope is added.

## Critical files

- `app/components/ui/base.rb` — the foundation every component inherits; not modified here.
- `app/components/ui/button_component.rb`, `button_component.html.erb` — single-element precedent.
- `app/components/ui/card_component.rb`, `app/components/ui/card/*` — compound precedent.
- `app/assets/tailwind/rails_ui_kit/engine.css` — the tokens rule 2 limits colour to.
- `test/components/ui/button_component_test.rb`, `card_component_test.rb` — unit test idiom.
- `test/system/button_test.rb`, `card_test.rb` — browser test idiom and the colour probe to extract.
- `examples/app/views/docs/` and the docs registry — where each page lands.
- `examples/app/views/docs/installation.html.erb`, `README.md` — the install guide rule 7(b) amends.

## Acceptance checks

### agent-loopable

- The unit lane is green — run: `bundle exec rake test`
- The browser lane, including every component's accessibility audit in light and dark, is green — run: `bundle exec rake test:system`
- No palette literal appears in any kit component outside the seven legacy components `ui-foundation-retrofit` owns (§ Business rules, rule 2) — run: `! grep -rnE -- '-(white|black)\b|-(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-[0-9]{2,3}\b' app/components | grep -vE '^app/components/ui/(confirm_dialog|dropdown|modal|popover|toast|toast_container|tooltip)_component\.'`
- Every docs registry entry has its view and every docs view has its entry (§ Business rules, rule 6) — run: `bundle exec rake test TEST=test/docs_pages_test.rb`
- Every component in § Behavior has both test files (§ Business rules, rule 5) — run: `bash -c 'for c in input label textarea native_select input_group badge alert avatar separator skeleton spinner progress table breadcrumb pagination button_group kbd empty item aspect_ratio; do test -f test/components/ui/${c}_component_test.rb && test -f test/system/${c}_test.rb || { echo "missing tests: $c"; exit 1; }; done'`

### judgeable

- The twenty components read as one family with Button and Card: the same constructor shape and forwarding (§ Business rules, rule 1), the same slot anatomy, part naming and `data-slot` scheme (rule 3), and the same test layout (rule 5). No component has a local dialect a reader has to learn separately.
- The accessibility guarantees axe cannot see hold: semantic elements, names on kit-rendered icon-only affordances, 3:1 non-text indicators and forced-colors focus, per § Business rules, rule 4.
- No component carries behaviour, per § Business rules, rule 8; anything that needed it is recorded as moved out of scope in `status.md`.

### human-gate

- Jonathan reviews every rendered docs page in light and in dark mode, on both `--background` and `--card` surfaces, before this scope ships.

## Out of scope / deferred

- **Button and Card** — shipped. They're this spec's precedents, not its work. Where
  they contradict a rule here, the conflict goes to Jonathan (`status.md`), not a
  silent change.
- **Field and the light-behaviour group** — Field, Checkbox, Switch, Toggle, Toggle
  Group, Radio Group, Accordion, Collapsible and Scroll Area each need field binding or
  a Stimulus primitive (`ui-positioning-and-navigation`).
- **The overlay family** — `ui-overlay-components`.
- **`Ui::FormBuilder`** — builds on Input, Label and Textarea; not part of this scope.
- **Anything needing the shared Stimulus primitives** — rule 8.
- **New status tokens and variants** (`--success`, `--warning`, `--info`) — see
  `open-questions.md`.
- **A `pagy` adapter for Pagination** — Pagination is markup; wiring it to a paginator
  is host code.
- **Typography** — a docs style-guide page, not a component (ui-component-library
  § Out of scope / deferred).
