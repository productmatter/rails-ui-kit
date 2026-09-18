---
slug: ui-control-sizing
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: medium
size: small
target_model: standard
created: 2026-09-14
loop_budget: 4
---

## Intent

The kit owns colour and radius as tokens (§ Business rules of ui-component-library,
rules 1 and 2). It doesn't own control *metrics*. Each control types its height as a
private literal, and the scales don't agree:

- `Ui::ButtonComponent` has a `size:` axis: `sm` is `h-8`, `default` is `h-9`, `lg` is
  `h-10`, `icon` is `size-9`.
- `Ui::InputComponent` has one size, `h-9`.
- `Ui::SelectComponent` has one size, `h-9` in `CONTROL_CLASSES`. Search mode's
  show-options button repeats that `h-9` in the template.
- `Ui::TextareaComponent` has one size, `min-h-16`.

The defaults line up at `h-9`, but only by coincidence. Put a `size: :sm` Button next
to an Input and you get 32px against 36px, with no way to ask the Input for 32. And a
host that wants a denser or roomier UI has to retype a height utility on every control
it renders.

The line this scope draws: **control metrics are functional and belong to the kit.
Density and brand scale belong to the app, which sets them once as a token instead of
retyping them on every control.** Heights come from three kit-extension tokens.
Input, Select and Textarea gain Button's `sm`/`default`/`lg` scale. A row of controls
at one step lines up because they read the same token, not because four literals
happen to agree.

**Appetite.** Three tokens, one size axis on three components, and Button's existing
heights moved onto the tokens. No new component, no new controller, and no visible
change to anything already rendered at its defaults.

## Goal

A row made of Button, Input, Select (native and enhanced) and Textarea's minimum, all
at one step, renders at one height taken from one token. Redefining that token in a
host theme retunes every control at that step. The scale is Tailwind's five button
steps, 24 to 40px, with `default` the middle one (amended 2026-09-18; until then there
were three steps, and every control rendered as v0.3.0 did at its defaults — see
§ Business rules, rule 3). Established when every agent-loopable check in
§ Acceptance checks passes.

## Non-goals

- **A general spacing or density system.** Only control height becomes a token.
  Padding, gap and font size stay utilities (§ Business rules, rule 1).
- **Moving a step's box by accident.** The defaults moved once, on 2026-09-18, on
  purpose (rule 3). From here a change to any step's box is a decision, not a side effect.
- **Icon Button sizes.** `icon` stays one square at the default step. No `icon-sm` or
  `icon-lg`.
- **Sizing the Select popup's option rows by step.** The popup follows the control's
  width, not its height (§ Behavior).
- **Clamping a host's token values.** How the 24px floor holds against a host theme is
  `open-questions.md`, not a mechanism this scope ships by default.

## Behavior

**The tokens.** Five kit extensions, per § Business rules of ui-design-tokens, rule 5.
They are defined once, under `:root` only (like `--radius`), in the kit's
`theme.rails-ui-kit` layer, and listed with the other kit extensions in `engine.css`:

| Token | Kit default | At Tailwind's default `--spacing` |
|---|---|---|
| `--control-height-xs` | `calc(var(--spacing) * 6)` | 24px |
| `--control-height-sm` | `calc(var(--spacing) * 7)` | 28px |
| `--control-height` | `calc(var(--spacing) * 8)` | 32px |
| `--control-height-lg` | `calc(var(--spacing) * 9)` | 36px |
| `--control-height-xl` | `calc(var(--spacing) * 10)` | 40px |

These are the heights of Tailwind's own five button sizes (decided 2026-09-18, Jonathan
Simmons). Until then there were three tokens, at 32, 36 and 40px: the top three of the
same ramp, adjacent steps 4px apart with nothing else changing on Input or Select, so
the sizes were nearly indistinguishable. The three existing names keep their names and
each drops one step: `--control-height-sm` from 32px to 28px, `--control-height` from
36px to 32px, `--control-height-lg` from 40px to 36px. A host that set any of them keeps
its own value.

The defaults are written in `--spacing` units, the lengths `h-6` to `h-10` compute to,
so a host that has retuned Tailwind's `--spacing` on `:root` sees the scale move with
it. The five tokens are independent plain values and
none is derived from another. A host sets one, two or all three, on `:root` or on any
subtree, and each is honoured wherever it lands. A derived scale, such as `-sm` defined
as `calc(var(--control-height) - …)` on `:root`, would compute once at the root. A
subtree that redefined `--control-height` would then move `default` and leave `sm` and
`lg` behind. Independent tokens have no such trap.

External shadcn themes don't define these names, so they keep the kit's default, and a
theme loses nothing by not knowing about them.

**The scale, per component.** Every control takes `size:` with `:xs`, `:sm`,
`:default`, `:lg` and `:xl`, with `:default` as the default; the middle step keeps the
name it has always had, so no call site breaks. A step is more than a height. Tailwind's
ramp reads as five sizes because inline padding grows with it and the smallest drops its
text a size, and a control that changed height alone looked like the same control three
times. So at each step every control takes the same height token, the same inline
padding, the same text size and the same corner radius:

| Step | Height token | Height | Inline padding | Text | Radius |
|---|---|---|---|---|---|
| `xs` | `--control-height-xs` | 24px | `px-2` | `text-xs` | `rounded-sm` |
| `sm` | `--control-height-sm` | 28px | `px-2` | `text-sm` | `rounded-sm` |
| `default` | `--control-height` | 32px | `px-2.5` | `text-sm` | `rounded-md` |
| `lg` | `--control-height-lg` | 36px | `px-3` | `text-sm` | `rounded-md` |
| `xl` | `--control-height-xl` | 40px | `px-3.5` | `text-sm` | `rounded-md` |

Only the height is a token (rule 1); the rest are classes on the component, per step.
Button, Input and Select's one shared box (native select, combobox and search trigger)
take the row as it stands; Select keeps whatever inline-end room its chevron needs on
top of it. Textarea takes the padding, text and radius, and its `min-height` is the
step's token plus `--spacing` × 7. A Button whose first child is an icon tightens its
inline padding by half a step at every size, as its `has-[>svg]:` forms did before, and
keeps its per-step `gap`. `icon` stays a single square that follows the default step, so
an icon Button beside a default Input still lines up when a host retunes. Choices
accepts the same five names and reads none of the tokens (ui-choices § Behavior,
item 17).

**Textarea** grows with its content, so its steps set a *minimum*, not a height. That
minimum is one control height at the step plus a fixed seven spacing units: 52, 56, 60,
64 and 68px from `xs` to `xl`. (At the old default it was `--spacing` × 16, 64px, which
is now the `lg` step's.) The textarea keeps the same one-line allowance above a
single-line control at every step, and it tracks a host's density retune the way the
other controls do.

**Select** applies the step to the one box its native select and combobox share, so
the swap still shifts nothing at any step (ui-select § Behavior, item 26). Its popup already
takes the control's width through `ui--anchor`'s width matching, and keeps doing that at
every step, while its option rows keep one height at every step: a list's density is its
own, and at 32px a row already clears the target-size floor. Search mode's trigger is the
control itself, so it takes the step by construction (ui-select § Behavior, item 17,
amended 2026-09-18 — the show-options button this paragraph once sized is gone with the
shape that needed it), and the popup's search row keeps one height at every step, like
the option rows: a flat `h-8`, their own 32px (it was `h-9` while the default control was
36px).

**How the tokens reach a class.** Each height is a complete literal class that uses
Tailwind's arbitrary-value syntax, such as `h-(--control-height-sm)`. It is never a
named theme key like `h-control` mapped through `@theme inline`. The reason is rule 4.

## Business rules

These refine § Business rules of ui-component-library, rules 1, 2, 5 and 6,
ui-design-tokens rule 5, and ui-presentational-components rules 1–3. They don't weaken
any of them.

1. **Height is the one control metric the kit tokenises.** Height is what decides
   whether controls of different kinds line up in a row, so it is a cross-component
   contract. Horizontal padding and gap are each control's internal proportion.
   Font size is typography, and Tailwind's own `--text-*` variables already make that
   the host's to retune. The kit adds no padding or font-size token, and no single
   density multiplier (§ Assumptions records why each lost).
2. **One scale, one vocabulary.** Button, Input, Select and Textarea take the same
   `size:` values, `:xs`, `:sm`, `:default`, `:lg` and `:xl`. At a given step every one
   of them reads the same token and takes the same inline padding, text size and radius. An unknown value fails the way every variant axis does
   (`Ui::Base::UnknownVariantError` in development and test). Button's `icon` size is
   kept, bound to the default step.
3. **Every step's box is pinned, and the defaults moved once, on purpose.** Until
   2026-09-18 this rule read "no visual change at the defaults": every control without
   `size:`, and every Button size, rendered v0.3.0's box, proven by a browser check
   written against the unmodified components. Jonathan Simmons then decided the scale
   should be Tailwind's five steps, because three adjacent heights with nothing else
   changing were nearly indistinguishable. That deliberately changes what a host on the
   kit's defaults sees: the default control is 32px where it was 36px, `sm` is 28px
   where it was 32px, `lg` is 36px where it was 40px, and Button's inline padding at
   each step is Tailwind's rather than v0.3.0's. The v0.3.0 check is retired with the
   promise it proved. In its place a browser check pins each of the five steps' boxes
   to the table in § Behavior — rendered height, `min-height`, inline padding, font
   size, line height, radius and, for `icon`, width — under Tailwind's default
   `--spacing` and under a `--spacing` redefined on `:root`. From here a change to any
   step's box is a decision recorded in this rule, never a side effect.
4. **The caller still wins, through `tailwind_merge`.** A caller's `class:` overrides
   a size default exactly as it overrides any other default (ui-component-library,
   rule 5). Tokens make this easy to break in one specific way.
   `tailwind_merge` 1.5.5 recognises an arbitrary-value height as a height:
   `h-(--control-height)` followed by `h-12` merges to `h-12`. It does not recognise a
   named theme key: `h-control h-12` survives the merge as both classes, and CSS source
   order then picks the winner (verified 2026-09-14). So tokens are consumed only
   through arbitrary-value syntax. Teaching `Ui::Base::MERGER` a custom theme key
   instead is rejected, because it creates a second list that must track every token
   name. `size-(--control-height)` followed by `h-8` keeps both classes, which is
   exactly what `size-9 h-8` does today and is correct, since `size` also sets width.
5. **The target-size floor holds at the smallest step.** At the kit's default token
   values, every control at `xs`, an `xs` Button whose only content is an icon, and
   the `icon` Button each measure at least 24×24 CSS px. The `xs` step is exactly the
   floor, with no margin, so its kit default never goes lower (WCAG 2.5.8;
   ui-presentational-components, rule 3). `assert_accessible` doesn't cover this:
   axe-core 4.13's `target-size` rule ships `enabled: false`. So the floor is measured
   directly in the browser. A host token or caller class below the floor is the host's
   choice under rule 4 and ui-design-tokens rule 7, and the docs say so
   (`open-questions.md`).
6. **No height literal survives in the four controls.** `h-6` to `h-10`, `size-8`,
   `size-9` and `min-h-16` don't appear in Button, Input, Select, including its
   template, or Textarea. A control height typed as a literal is the defect this scope
   removes.

## Assumptions

- **Tailwind emits `--spacing` on `:root`** whenever the kit is compiled. The kit's own
  spacing utilities reference it, and a 2026-09-14 compile with `tailwindcss-ruby`
  4.3.1 emitted it. **At a contradiction**, where a host build prunes it, the tokens
  resolve to invalid values and heights fall back to `auto`. Check 1 then fails on
  height. Give the token defaults a `var(--spacing, 0.25rem)` fallback. Don't switch
  to `rem` literals, which would break rule 3 for hosts that have retuned `--spacing`.
- **A host `--spacing` redefined on a subtree** (not `:root`) moves today's `h-9` but
  not a token computed at `:root`. That is taken to be rare enough that rule 3 is
  stated for `:root` only. **At a contradiction**, where a consumer does this, escalate
  to the decider rather than deriving the tokens per element.
- **The alternatives lost on these grounds.** A single density multiplier can't express
  "roomier default, same `sm`", and it produces fractional pixels. Height, padding and
  font size per step is nine tokens, and two of those three properties aren't
  alignment contracts (rule 1). One base token with derived steps, the `--radius`
  pattern, either computes at the root and breaks subtree overrides (§ Behavior), or
  computes in the utility through `@theme inline` and needs named keys, which break
  rule 4. If `tailwind_merge` later learns custom spacing keys without configuration,
  that last objection lapses. Reopening the choice is then the decider's call, not the
  implementer's.
- **`tailwind_merge` 1.5.5's arbitrary-value handling** is what rule 4 relies on. It
  was verified 2026-09-14 for `h-`, `size-` and `min-h-` against plain-utility
  callers. **At a contradiction**, such as a gem upgrade that stops merging these,
  escalate. Don't fork the gem (ui-component-library, § Assumptions).
- **The v0.3.0 box metrics** are what the classes compute to under Tailwind 4's
  defaults. Button: `default` is 36px tall with 16px horizontal padding, `sm` 32px with
  12px, `lg` 40px with 24px, `icon` 36×36. Input and Select: 36px tall. Textarea: a
  64px `min-height`. All use 14px text. These were read from the classes, not measured.
  Rule 3's ordering (check first, green on v0.3.0) is what turns them into
  measurements. **At a contradiction**, where the check measures something else on
  unmodified v0.3.0, the measured value is the baseline and this list is corrected.

## Critical files

- `app/assets/tailwind/rails_ui_kit/engine.css`: the kit-extension block where the
  three tokens are defined.
- `app/components/ui/button_component.rb`: the `size:` axis moved onto the tokens.
- `app/components/ui/input_component.rb`, `app/components/ui/textarea_component.rb`:
  gain the `size:` axis.
- `app/components/ui/select_component.rb` and `select_component.html.erb`:
  `CONTROL_CLASSES`. (The show-options button this line once named left on 2026-09-18,
  ui-select § Behavior, item 17.)
- `app/javascript/rails_ui_kit/controllers/anchor_controller.js`: the width matching
  the popup relies on. Not modified.
- `test/system/select_enhancement_test.rb`: SE2 (same box) and SE3 (popup width), the
  existing geometry checks at the default step. `test/system/control_sizing_test.rb` makes
  the same two measurements at every step.
- `examples/app/views/docs/field.html.erb`: the `#control-sizes-preview` mixed row, with
  every control at each step, which the browser checks and the human gate both use.

## Acceptance checks

### agent-loopable

- Each of the five steps renders the box in § Behavior's table on Button, Input, the native Select, the select-only combobox, search mode's trigger and Textarea: rendered height or `min-height`, inline padding, font size, line height and radius, and the `icon` Button's width at the default step. This holds under the default `--spacing` and a `:root` `--spacing` retune (§ Business rules, rule 3) — run: `bundle exec rake test:system TEST=test/system/control_sizing_test.rb TESTOPTS="--name=/box/"`
- At each step, Button, Input, the native Select, the select-only combobox and search mode's trigger button all measure the step token's height, and search mode's popup search row keeps one height, the option rows' 32px, across steps. Textarea's `min-height` is that height plus seven spacing units. The enhanced popup matches the control's width. Redefining `--control-height-sm` on `:root`, and separately on a wrapping element, moves every `sm` control inside it together (§ Behavior) — run: `bundle exec rake test:system TEST=test/system/control_sizing_test.rb TESTOPTS="--name=/align/"`
- At the kit's default tokens, every control at `xs`, an icon-only `xs` Button and the `icon` Button each measure at least 24×24 CSS px in the browser (§ Business rules, rule 5) — run: `bundle exec rake test:system TEST=test/system/control_sizing_test.rb TESTOPTS="--name=/target/"`
- No height literal is left in the four controls. For each of them at each step, a caller's `class:` height (`h-12`, or `min-h-24` on Textarea, or `size-12` on `icon`) is the only height class rendered. An unknown `size:` raises (§ Business rules, rules 2, 4 and 6) — run: `! grep -nE '(^|[^-])\b(h-6|h-7|h-8|h-9|h-10|size-8|size-9|min-h-16)\b' app/components/ui/button_component.rb app/components/ui/input_component.rb app/components/ui/textarea_component.rb app/components/ui/select_component.rb app/components/ui/select_component.html.erb && bundle exec rake test TEST=test/components/ui/control_size_test.rb`

### judgeable

- The token surface is exactly the five `--control-height*` names. Each is documented in `engine.css`'s kit-extension block with a default that an external shadcn theme leaves in place. No padding, font-size or density token has crept in. Every class that consumes a token uses arbitrary-value syntax, never a named theme key. Judged against § Business rules, rules 1 and 4, and ui-design-tokens rule 5.

### human-gate

- Jonathan looks at the five steps side by side on the Button, Input, Select and Textarea docs pages and judges that each reads as a different size at a glance, which is what the 2026-09-18 amendment was for; accepts the more compact 32px default on a real form; and looks at a mixed row of controls at each step, once at the kit's tokens and once with a denser host value, and accepts the scale.

## Out of scope / deferred

- **`icon-sm` and `icon-lg` Button sizes: not planned.** Add them when a client build
  needs a small or large icon Button, not before.
- **Padding, gap and font-size tokens: declined** (§ Business rules, rule 1). Hosts
  retune text through Tailwind's `--text-*`.
- **Sizing Label, Field description and error text, or other components by step: not
  planned.** They aren't controls that sit in a row.
- **Dropdown, Popover and Tooltip triggers:** they size through the Button they render,
  so they follow this scope with no work of their own.
- **Changing ui-component-library's rule 1 to name control height beside colour and
  radius** is a parent reshape and the decider's call. This scope states the rule for
  itself and doesn't edit the parent's.
