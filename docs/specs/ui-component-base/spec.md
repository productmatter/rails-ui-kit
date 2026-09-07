---
slug: ui-component-base
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: high
size: small
target_model: standard
created: 2026-09-07
loop_budget: 5
---

## Intent

`Ui::Base` is the shared foundation every `Ui::*Component` inherits from: the Ruby
equivalent of shadcn's `cva` + `cn()`. It resolves a component's declared variant
axes to a class string and guarantees that a caller-passed `class:` wins over that
string through Tailwind-aware merging, plus a generic attribute-forwarding
convention and the `data-slot` styling-hook convention. Every component in Phase B
and Phase C composes on top of it, so its shape here is close to permanent once
those phases start consuming it.

## Goal

A component inheriting from `Ui::Base` that receives a `class:` string conflicting
with one of its variant-computed utility classes renders the caller's utility in
place of the conflicting default, in every component built on `Ui::Base`.

## Non-goals

- Not a new variant DSL — `class_variants` is adopted verbatim, per § Business
  rules of ui-component-library, rule 8.
- Not a new class-merge algorithm — `tailwind_merge` is adopted verbatim, same rule.
- Not the token values themselves — owned by `ui-design-tokens`.
- Not the Stimulus behavior primitives (presence, overlay stack, positioning, group
  navigation, field binding, media-query watching) — owned by
  `ui-presence-and-overlay-stack` and `ui-positioning-and-navigation`.
- Not a retrofit of the seven existing components onto this layer — owned by
  `ui-foundation-retrofit`. This scope ships `Ui::Base` and proves it against a
  throwaway test component; it does not migrate `DropdownComponent`,
  `PopoverComponent`, `TooltipComponent`, `ModalComponent`, `ConfirmDialogComponent`,
  `ToastComponent`, or `ToastContainerComponent`.
- Not cross-part render-time state sharing between slots — see Assumptions.

## Behavior

`Ui::Base` is a `ViewComponent::Base` subclass. Every kit component inherits from
it instead of `ViewComponent::Base` directly, mirroring how the existing seven
(`DropdownComponent`, `PopoverComponent`, `TooltipComponent`, and siblings) inherit
from `ViewComponent::Base` today.

A class-level `class_variants` declaration wraps `ClassVariants.build(base:,
variants:, compound_variants:, defaults:)` unchanged — no wrapper DSL, no
reinterpretation of its keyword arguments. It memoizes the built variant object on
the component class. An instance method resolves that object's `.render(**variant_
values)` — called without `class_variants`' own `class:` keyword — against the
variant values passed to `initialize`.

Class merging is a separate, explicit step, not `class_variants`' own `class:`
argument: `Ui::Base` holds one memoized `TailwindMerge::Merger` instance and calls
`merger.merge(variant_classes, caller_class)` with the caller's `class:` merged
*last*, because `tailwind_merge` resolves same-property conflicts in favor of the
later string. `class_variants` ships with zero runtime dependencies, so nothing
about adopting it gives the caller-wins guarantee for free — `Ui::Base` is what
makes rule 5 of the parent true, by construction, for every component built on it.

Concretely: `render Ui::ButtonComponent.new(variant: :primary, class: "bg-red-500")`
resolves `variant_classes = "bg-primary text-primary-foreground …"` from
`class_variants`, then `merger.merge(variant_classes, "bg-red-500")`, which drops
`bg-primary` and keeps `bg-red-500` because both set the `background-color`
property and the caller's string was merged last. Without this step — e.g. naive
`[variant_classes, caller_class].join(" ")` — both classes land in the rendered
`class` attribute and the winner is decided by stylesheet load order, which is the
defect this scope exists to close.

Attribute forwarding is generic: a component's `initialize` declares its known
variant keywords explicitly and captures everything else through a catch-all
keyword hash, which `Ui::Base` merges onto the root element's attributes —
shallow-merging `data:`/`aria:` sub-hashes so a component's own `data-controller`
survives alongside a caller's `data-testid`, and letting plain attributes (`id`,
`tabindex`) pass through unchanged. A component author never enumerates every
attribute a caller might want to pass.

`Ui::Base` adopts the `data-slot` convention: the root element of every kit
component, and every distinct semantic part inside a component's own template,
carries `data-slot="<part-name>"` (`data-slot="button"`, `data-slot="trigger"`,
`data-slot="panel"`) as a styling and testing hook that survives class or markup
changes. `Ui::Base` provides the mechanism for stamping it on a component's own
root element; content rendered inside a `renders_one`/`renders_many` slot is
caller-authored markup, so a component's template is responsible for stamping
`data-slot` on its own slot-wrapper elements — `Ui::Base` cannot reach into
caller-supplied slot content to add it.

## Business rules

1. Every `Ui::*Component` written after this scope ships inherits from `Ui::Base`,
   never from `ViewComponent::Base` directly.
2. Caller-wins is resolved exclusively through `TailwindMerge::Merger#merge`, with
   the caller's `class:` merged last. No component concatenates, `Array#|`s, or
   otherwise hand-merges its own default classes with a caller's `class:`.
3. No component defines its own `class_variants` block outside a component class
   that inherits `Ui::Base`'s declaration mechanism, and no component instantiates
   its own `TailwindMerge::Merger` — one memoized instance per process, owned by
   `Ui::Base`.
4. A component's `initialize` never grows a parameter for a passthrough HTML
   attribute (`id:`, `data_testid:`, and so on); such attributes flow through the
   generic catch-all forwarding path.
5. Every semantically distinct rendered part of a kit component carries
   `data-slot`; a component that introduces a new visual part without one is
   incomplete, not merely unpolished.

## Assumptions

- `class_variants` v1.1.1 and `tailwind_merge` v1.5.5 are assumed maintained and
  Tailwind-v4-capable, per § Assumptions of ui-component-library. Reverified here
  by resolving both against rubygems at authoring time: `class_variants (1.1.1)`
  and `tailwind_merge (1.5.5)` are the latest versions published, matching the
  parent's pinned versions exactly — no contradiction found.
- `class_variants`' own `.render(color: :red, class: "…")` form exists but is not
  used by `Ui::Base`: it has zero runtime dependencies, so it cannot itself be
  performing Tailwind-aware conflict resolution on that `class:` argument. Treating
  its output as a plain string and merging it through `tailwind_merge` separately,
  rather than trusting that keyword, is a deliberate design choice this scope
  makes, not a gap in the gem.
- **Slots are content-only.** `renders_one`/`renders_many` (already in use by
  `DropdownComponent`'s `:trigger`/`:menu`, `PopoverComponent`'s
  `:trigger`/`:panel`, and `TooltipComponent`'s `:trigger`) compose markup; they do
  not give sibling slots a way to share render-time Ruby state the way React
  context does. Any state coordination between a trigger and its
  panel/menu — open/closed, active index, positioning — happens client-side, in
  the DOM, via Stimulus targets/values/outlets, not in Ruby. This is a real
  architectural boundary that `ui-presence-and-overlay-stack` and
  `ui-positioning-and-navigation` design around; `Ui::Base` does not attempt to
  paper over it with a Ruby-side shared-state mechanism.
- The host pipeline is Tailwind 4 via the `engine.css` convention, per § Assumptions
  of ui-component-library; `Ui::Base` ships no compiled CSS of its own.
- **`ui-design-tokens` ships first** (`relations.md`). This scope defines no token
  values, but its proof-of-caller-wins component's variant table names token-backed
  utilities (`bg-primary` against a caller's `bg-red-500`), and those utilities only
  compile once the token layer's `@theme` mapping exists — so the acceptance check
  cannot pass without it. The dependency is on the token layer existing, not on any
  particular `oklch()` value.

## Critical files

- `rails_ui_kit.gemspec` — gains `class_variants` and `tailwind_merge` as runtime
  dependencies, alongside the existing `rails`, `view_component`, `stimulus-rails`,
  `turbo-rails`.
- `app/components/ui/base.rb` (new) — `Ui::Base` itself.
- `app/components/ui/dropdown_component.rb`, `app/components/ui/popover_component.rb`,
  `app/components/ui/tooltip_component.rb` — existing `renders_one` slot usage this
  layer must compose with; read for the slot convention, not modified by this
  scope.
- `test/components/ui/base_test.rb` (new) — where this scope's throwaway
  proof-of-caller-wins test component and its test live; it runs on the existing unit
  lane through `test/test_helper.rb`, which this scope does not change.

## Acceptance checks

### agent-loopable

- A test component built on `Ui::Base` with a `background` variant axis, rendered
  with `variant: :primary, class: "bg-red-500"`, produces `bg-red-500` in its
  `class` attribute and does not produce the variant default `bg-primary` —
  run: `bundle exec rake test TEST=test/components/ui/base_test.rb TESTOPTS="-n /caller_class_wins/"`
- `rails_ui_kit.gemspec` declares both `class_variants` and `tailwind_merge` as
  runtime dependencies — run: `ruby -e "d = Gem::Specification.load('rails_ui_kit.gemspec').dependencies.map(&:name); raise('missing') unless (%w[class_variants tailwind_merge] - d).empty?"`

### judgeable

- `Ui::Base`'s merge order (variant defaults first, caller `class:` merged last via
  `TailwindMerge::Merger#merge`) is the mechanism that makes § Business rules of
  ui-component-library, rule 5 ("the caller wins") true by construction rather than
  by convention, and satisfies rule 8 ("adopt over build") by never reimplementing
  either gem's job.

### human-gate

- Jonathan confirms the `data-slot` naming convention (`data-slot="trigger"`,
  `data-slot="panel"`, `data-slot="button"`) reads naturally against the seven
  existing components' slot and part names before `ui-foundation-retrofit` applies
  it broadly.

## Out of scope / deferred

- **Token values** — owned by `ui-design-tokens`; `Ui::Base` only consumes
  whatever token-backed utility classes a component's variant table names.
- **The Stimulus primitives** (presence, overlay stack, positioning, group
  navigation, field binding, media-query watching) — owned by
  `ui-presence-and-overlay-stack` and `ui-positioning-and-navigation`.
- **Migrating the seven existing components onto `Ui::Base`** — owned by
  `ui-foundation-retrofit`. This scope proves the mechanism against a throwaway
  test component only.
- **A Ruby-side mechanism for cross-slot render-time state sharing** — the
  slots-are-content-only boundary (see Assumptions) is accepted, not solved here.
- **Auto-deriving `data-slot` values from a component's class name** — left an
  open question rather than decided; see `open-questions.md`.
