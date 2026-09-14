---
slug: ui-choices
type: feature
status: draft
decider: Jonathan Simmons
blast_radius: medium
size: large
target_model: standard
created: 2026-09-14
loop_budget: 5
---

## Intent

The decider asked for a **Choices** component: a label and a set of choices, in a radio
variant (choose one) and a multi-select variant (choose several), with a **wrapped
choice** form where the whole card is the target, not just the small input. A
Stimulus controller ships only where state really needs one.

**Why it passes rule 0** (`ui-component-library` § Business rules). It clears both
gates, for reasons that are easy to get wrong:

- **Gate 1: it owns a Rails contract.** That contract is `collection_radio_buttons`,
  `collection_check_boxes`, model enums and `include_hidden`. A checkbox group without
  Rails' hidden empty field submits nothing when every box is unchecked. The attribute
  is then never assigned, and `user.role_ids` keeps its old values. That is silent data
  retention, and it is the bug this component exists to make impossible to write.
- **Gate 2: the group accessibility wiring is hard.** `Ui::FieldComponent` names one
  labelable control with `<label for>`. A group can't be named that way. Its name,
  description, error and required state each need a different route, and a checkbox
  group has no native or ARIA "required" state at all.

**The position this spec takes: neither variant needs JavaScript for its behaviour.**
Real `<input type="radio">` elements that share a name already provide arrow-key
movement, wrap-around, single selection, Tab entering at the checked radio,
`required`, reset and submission. Real checkboxes already provide Space toggling and
Tab. A `<label>` wrapping the input makes the whole card the click target. The card's
checked, focused, disabled and invalid styling is CSS (`:has()`). Each of these was
checked in headless Chrome on 2026-09-14 (§ Assumptions).

The platform genuinely can't do one thing: **"at least one of these checkboxes"**.
`required` on a checkbox means *that* box must be checked, so Rails' own
`collection_check_boxes(..., required: true)` puts `required` on every box, and the
form demands all of them (verified). That is the only job `ui--choices` has
(§ Behavior, item 14; **decided** 2026-09-14, Jonathan Simmons, relayed by the
orchestrator). The decider's standing direction is to lean on the browser and CSS rather
than add JavaScript; the media-query primitive was removed for that reason. This
controller passes that test only because the browser has no native "at least one
checked" constraint. It is not redundant. Select-all, min/max counts and an exclusive
"None of the above" all need JavaScript too, and none of them is in v1 (§ Out of scope /
deferred).

**Appetite.** One server-rendered component with two variants and two appearances.
It uses Select's option model, moved to a shared home. Two small prerequisites land on
Field. One controller of about thirty lines, for one job. The tests prove it's still
three form behaviours: submission, validation and reset.

## Goal

`Ui::ChoicesComponent` renders, inside `Ui::FieldComponent`, a radio or checkbox group
with the same name, value, id and hidden-field output as `collection_radio_buttons` or
`collection_check_boxes` for the same arguments. Unchecking every box and submitting
empties a real ActiveRecord association. The group is named, described and marked
invalid through Field. Every card is fully clickable and keyboard-operable with no
kit JavaScript. A required checkbox group blocks an empty submission. The component
passes `assert_accessible` in both variants, both appearances, and light and dark
mode.

## Non-goals

- **Not a combobox multi-select.** A searchable, popup "pick several" is a multi-select
  listbox inside a combobox: a different ARIA pattern, a different focus model
  (`aria-activedescendant`, not real focus on each input), and `ui-select`'s territory.
  `ui-select` § Non-goals already records it as its own future scope.
- **Not a switch or toggle.** `role="switch"` is an on/off setting that takes effect
  immediately. It isn't a choice submitted with a form, and it has no group or
  collection semantics. It would have to pass rule 0 on its own.
- **Not virtualisation.** Every choice is a real, rendered, focusable input. A
  collection too long to show as cards or a list is a Select, with remote search
  (`ui-select` § Behavior, items 27–31).
- **Not a second option normaliser.** Option sources are `Ui::Select::OptionSet`'s,
  moved to `Ui::OptionSet` (§ Behavior, item 3). Nothing is copied.
- **Not `ui--roving-focus`.** Native radios already implement group navigation, and
  rule 4 says one implementation. Here the platform's is that one. Adding the
  primitive would fight the browser's own arrow-key handling.
- **Not a form builder.** There's no `form.ui_choices`. That direction is deferred by
  decision (`ui-field-model-binding` § Out of scope / deferred).
- **Not custom markup per choice.** There's no builder block like Rails'
  `collection_check_boxes { |b| … }`. A choice has text, an optional description line
  and an optional decorative icon (§ Behavior, item 9).
- **Not a Card component.** Card was cut against rule 0 on 2026-09-13. The card
  appearance is the styling of a choice's own `<label>`. It isn't a reusable
  container.

## Behavior

### The Rails API

1. **One component, two variants, chosen by `multiple:`.** `multiple: false`, the
   default, renders radios. `multiple: true` renders checkboxes. That mirrors
   `select(..., multiple: true)`, which is the Rails keyword that means the same
   submission change: `name[]` plus a hidden field. Each sketch below sits next to the
   helper it mirrors:

   ```ruby
   # f.collection_radio_buttons :plan_id, Plan.order(:price), :id, :name
   Ui::ChoicesComponent.new(name: "account[plan_id]", collection: Plan.order(:price),
                            value_method: :id, text_method: :name, checked: @account.plan_id)

   # f.collection_check_boxes :role_ids, Role.order(:name), :id, :name
   Ui::ChoicesComponent.new(name: "user[role_ids]", multiple: true, collection: Role.order(:name),
                            value_method: :id, text_method: :name, checked: @user.role_ids)

   # Arrays and hashes, as options_for_select reads them
   Ui::ChoicesComponent.new(name: "shirt[size]", options: %w[S M L])
   Ui::ChoicesComponent.new(name: "post[state]", options: { "Draft" => "draft", "Published" => "published" })

   # A model enum: labels through human_attribute_name, submits the key
   Ui::ChoicesComponent.new(name: "order[status]", model: Order, enum: :status, checked: @order.status)

   # The wrapped card, with a description line and a decorative icon
   Ui::ChoicesComponent.new(name: "account[plan_id]", collection: plans, value_method: :id, text_method: :name,
                            description_method: :tagline, icon_method: ->(plan) { plan_icon(plan) },
                            appearance: :card, class: "sm:grid-cols-3")
   ```

   Inside a Field, which is the normal case:

   ```erb
   <%= render Ui::FieldComponent.new(model: @user, attribute: :role_ids, required: true,
                                     errors: @user.errors[:roles]) do |field| %>
     <% field.with_label { "Roles" } %>
     <% field.with_control(Ui::ChoicesComponent, multiple: true, collection: Role.order(:name),
                           value_method: :id, text_method: :name) %>
     <% field.with_description { "People with no role can sign in but see nothing." } %>
   <% end %>
   ```

   A `has_many` association is validated as `roles`, but it's edited as `role_ids`.
   So the caller states `required:` and `errors:` here, because the model-bound Field
   only reads validators and errors on the attribute it's given
   (`ui-field-model-binding` § Behavior, item 2). The guide spells this out.
2. **Keywords and their Rails namesakes.**
   - **`checked:`** is the value or values that start checked, compared as strings.
     It's Rails' own `checked:` option for the collection helpers. Select says
     `selected:` because Rails' `select` does. Each component uses its helper's word.
   - **`disabled_values:`** is the values rendered disabled. It isn't `disabled:`,
     because `disabled:` is the whole group (item 12). This matches Select.
   - **`include_hidden:`**, default `true`, is Rails' option with Rails' default for
     both helpers (item 5).
   - **`value_method:`, `text_method:` and `description_method:`** each take a symbol
     or a proc, as Rails' `value_for_collection` does. `icon_method:` does too, and
     returns HTML-safe markup. Descriptions and icons need a collection source: an
     array, hash or enum source that passes them raises `ArgumentError`, because
     there's no object to call them on.
   - **`size:`** is `sm`, `default` or `lg` (item 17).
   - **`appearance:`** is `:list`, the default, or `:card` (items 15 and 16).
   - **`required_message:`** is the per-instance override for the one chrome string
     (item 14).
   - **`required:`, `disabled:` and `form:`** follow items 11–13.
   - Every other attribute goes to the group's root element, and the caller's `class:`
     merges there (`ui-component-library` § Business rules, rule 5).
3. **The option model is `Ui::Select::OptionSet`, moved to `Ui::OptionSet`.** It
   already handles the collection, array, hash and enum sources with Rails'
   `value_for_collection`, `option_text_and_value` and `human_attribute_name`
   semantics, and `select_options_test.rb` covers it. Choices renders from its `items`
   (text, value, disabled, selected). It never calls `native_options`, which stays
   Select's rendering. Four things don't fit as it stands, and each is fixed in the
   class rather than worked around:
   - **The class lives under `Ui::Select::`.** It moves to
     `app/components/ui/option_set.rb` as `Ui::OptionSet`. The move touches four files:
     `select_component.rb`, `select/listbox_component.rb`, `select_options_test.rb`
     and the class itself. It isn't public API: it appears in no README, CHANGELOG or
     guide, so it gets no alias. The move is its own commit, with no behaviour change,
     and the Select tests stay green across it.
   - **Its error messages name `Ui::SelectComponent`.** They take the calling
     component's name instead.
   - **Its `Item` doesn't carry the source element.** `Item` gains `object`, which is
     the collection element and `nil` for array, hash and enum sources. That's what
     `description_method:` and `icon_method:` are called on.
   - **It supports placeholders and groups that choices can't have.** `include_blank:`,
     `prompt:`, `group_method:`, `group_label_method:` and a grouped `options:` shape
     all raise `ArgumentError` from Choices. Rails' collection helpers have no blank
     option, and a "none" choice is just an option the caller adds. Grouped radios
     would put `role="group"` elements inside a `radiogroup`, whose owned elements are
     radios. Choices also never passes `required:` to the option set, because that
     keyword only adds Select's implicit blank.
4. **Names and ids are Rails'.**
   - With `multiple: true`, `[]` is appended to `name:` unless it already ends in `[]`.
     `user[role_ids]` becomes `user[role_ids][]`, which is what `collection_check_boxes`
     emits.
   - Each input's id is `"#{id}_#{sanitized value}"`, using ActionView's
     `Tags::Base#sanitized_value` rule: whitespace and `.` become `_`, other non-word
     characters are dropped, and the result is lowercased. So `user[plan]` with value
     `pro` is `user_plan_pro`. `id` is Field's `control_id`, or else the name-derived
     id that Field and Select both use.
   - The group's root carries `id` itself. A choice's text and description get
     `"#{input id}-label"` and `"#{input id}-description"`, and the required hint gets
     `"#{id}-required"`. Rails' sanitised ids use `_` and the kit's part ids use `-`,
     so the two can't collide.

### Submission

5. **`include_hidden:` defaults to `true` for both variants, as in Rails.** Rails
   prepends one `<input type="hidden" name="…" value="" autocomplete="off">` before the
   inputs. It's `user[role_ids][]` for checkboxes and `user[plan]` for radios, and it
   carries `form:` when given. Verified against ActionView 8.1.3.1 and 7.2.3.2, whose
   `collection_helpers.rb` files are byte-identical.
   - **Checkboxes.** Unchecking everything submits `user[role_ids][]=""`.
     `permit(role_ids: [])` passes `[""]`, and ActiveRecord's `ids_writer` drops blanks
     (`compact_blank`), so the association empties. Without the hidden field the key
     is absent, `role_ids=` is never called, and the old roles survive. Verified with an
     in-memory `has_and_belongs_to_many` round trip: `[]` with the hidden field,
     `[1, 2]` without it. And if that's the only field in the form, `params.require(:user)`
     raises `ParameterMissing`.
   - **Radios.** A radio can't be unchecked by the user, so the hidden field only
     matters when the group starts with nothing checked. It then submits `""`. For a
     string column that's `""`; for an enum it's `nil`. That's Rails' behaviour, and
     the guide names it. A required radio group blocks that submission in the browser
     (item 11).
   - **`include_hidden: false`** omits the field, as in Rails. The docs show what it
     costs.
6. **Choices submits only through real inputs.** Values live in three kinds of input,
   all server-rendered:
   - the checked inputs;
   - Rails' blank hidden field (item 5);
   - the locked-value hidden fields (item 7).

   No data attribute or controller field holds a value, and no other hidden input
   exists. Reset, `ui--form-change`'s `FormData` comparison, a host's `change->`
   actions and Turbo's snapshot all work on them unchanged.
7. **A checked, locked choice survives a save.** **Decided** 2026-09-14 by Jonathan
   Simmons, relayed by the orchestrator; this overrides the default in
   `open-questions.md`. A value that is both checked and in `disabled_values:` is
   carried by a hidden input with the same name and value, so saving the form never
   deletes a value the form showed as checked and locked.
   - **Why this deviates from Rails.** A disabled input isn't submitted. So Rails' own
     `collection_check_boxes(disabled: [...])` markup deletes a locked role on every
     save. That is data loss contradicting what was on screen, the same reasoning as
     the `<fieldset disabled>` deviation (item 12).
   - **Checkboxes.** One hidden input per locked value, rendered after the blank field.
     `role_ids[]=""`, `role_ids[]=<locked>`, then the user's checked boxes all arrive
     in `role_ids`.
   - **Radios.** A checked radio isn't locked the way a checkbox is: the user can still
     choose an enabled radio, which natively unchecks the disabled one. So the carrier
     sits after the blank field and **before** every radio. Rack keeps the last value
     for a non-array key (`user[plan]=&user[plan]=pro&user[plan]=free` parses to
     `free`, verified on Rack 3.2.7). A radio the user chooses therefore wins, and an
     untouched form keeps the locked value. This is Rails' own "hidden then real"
     ordering for `checkbox`.
   - **A disabled group** (`disabled: true`) disables its carriers along with
     everything else in the fieldset, so the attribute is left untouched (item 12).
   - **A locked checkbox is not authorization.** A hidden input can be removed or edited
     in the browser, and a disabled one re-enabled. The server still decides what a
     user may change, and filters or merges locked values itself. The docs page and
     the guide say this plainly, beside the example that uses `disabled_values:`.

### Accessibility and Field

8. **The group is a `<fieldset>`, named by `aria-labelledby`.**
   - The radio variant is `<fieldset role="radiogroup">`; ARIA in HTML allows
     `radiogroup` on `fieldset`.
   - The checkbox variant is a plain `<fieldset>`, which is implicitly `role="group"`.
   - Why a fieldset rather than a `div`: `disabled` on a fieldset disables every
     descendant control natively, including the hidden field (item 12). And a fieldset
     is still a group with JavaScript and CSS both gone.
   - Its name comes from `aria-labelledby`, not a `<legend>`, because the visible
     label is Field's and stays in Field's layout. Chrome computes the name and role
     from exactly this markup: `radiogroup "Plan"` and `group "Roles"` (verified).
   - The fieldset resets its UA `min-inline-size: min-content` (item 18).
   - Outside a Field, the caller names the group with `aria: { labelledby: }` or
     `aria: { label: }`, as with Select.
9. **Each choice is a `<label>` wrapping its input.** The input's name is only its text
   and its description is only its description line, so the label's full text never
   becomes the name.
   - The input carries `aria-labelledby` pointing at the text element and, when there
     is a description line, `aria-describedby` pointing at it. Without that, a
     wrapping label names the input with all its text, as in "Pro Unlimited projects".
   - The icon is `aria-hidden`. It decorates, and the text names the choice.
   - Verified in Chrome: the radio's name is "Free" while the label also contains
     "For hobby projects".
   - A click anywhere in the label (text, description, icon or padding) checks or
     toggles the input, and focus lands on the input (verified for the description).
   - The card holds no interactive content. A link inside a choice isn't supported,
     and the guide says so.
10. **How Field's wiring reaches a group.** Field's `control_attributes` stay exactly
    as they are. Choices routes what it's handed:

    | Field hands the control | For one input (today) | For a Choices group |
    |---|---|---|
    | `id` | the input | the fieldset; inputs derive theirs (item 4) |
    | `name` | the input | every input and the hidden field (item 4) |
    | label | `<label for=id id=label_id>` | `<label id=label_id>`, **no `for`**; the fieldset carries `aria-labelledby=label_id` (prerequisite 1) |
    | `aria-describedby` (description, error) | the input | the fieldset, with Choices appending its required hint's id when there is one (item 14) |
    | `aria-invalid` | the input | the fieldset; axe-core 4.13 treats `aria-invalid` as global, so it's valid on `group` and `radiogroup` |
    | `required` | the input | radios: every radio; checkboxes: **never an input**, see item 14 |
    | record value (`field.value`) | `value:` | `checked:` (prerequisite 2) |

    The label loses `for` because `for` must point at a labelable element, and neither
    a fieldset nor any single input is the thing being labelled. Pointing it at the
    first input would make clicking "Roles" toggle Admin. Field's label stays a
    `<label>`, which keeps Label's styles and Field's required marker; it just labels
    nothing by association. Field keeps hiding the description of an invalid field and
    announcing a morphed error (`ui-field-model-binding` § Behavior, items 19–23).
    Nothing in `ui--field` addresses the control, so a group needs nothing new there.

    **The expected accessibility tree**, which is provable (§ Acceptance checks):

    - radio variant: `radiogroup`, name "Plan", description from Field's description
      and error, invalid when Field is. Each `radio` has its choice's name and
      description, `checked`, and `required` when the group is required.
    - checkbox variant: `group`, name "Roles", description from Field's description,
      Field's error, and the required hint when the group is required. Each `checkbox`
      has its choice's name and description, `checked`, and no `required`.

    **What a screen reader should announce** on Tab into a required, invalid radio
    group: the checked (or first) radio's name, state, position ("2 of 3") and
    description, then "required", then the group name "Plan", with the group
    description and the invalid state. Whether VoiceOver in Safari actually speaks a
    fieldset's `aria-describedby` and `aria-invalid` when focus moves in from outside
    is the unverified seam (§ Assumptions). It's a human gate.
11. **`required:` for radios is native.** Every radio gets `required`, as Rails does,
    and HTML makes the whole group `valueMissing` until one is checked (verified). The
    browser blocks submission, focuses the first radio and shows its own message. The
    fieldset carries no `aria-required`, because each radio already exposes the state
    and a second copy doubles the announcement.
12. **`disabled: true` is `<fieldset disabled>`.** Every input and the hidden field are
    disabled, so the group submits nothing and the attribute is left untouched
    (verified: an empty `FormData`).
    - **This is a deliberate deviation from `collection_check_boxes` and
      `collection_radio_buttons`**, whose hidden field stays enabled when
      `disabled: true` is in `html_options`. Submitting a disabled Rails checkbox
      group sends `role_ids[]=""` and wipes the association (verified in the rendered
      markup).
    - Rails' own `select(multiple: true, disabled: true)` and `checkbox(disabled: true)`
      do disable their hidden fields (verified). Choices follows those two, since the
      collection helpers are the inconsistent case.
    - `disabled_values:` disables single inputs. The platform takes those out of Tab
      and arrow-key order. A checked one is carried by its hidden input (item 7).
13. **`form:`** goes on every input and on the hidden field, as in Rails.

### The one controller

14. **A required checkbox group: `ui--choices`, and only there.**
    - **Server-rendered, with or without JavaScript.**
      - No checkbox gets `required`.
      - The fieldset carries `data-required="true"`, which Field's marker already
        mirrors.
      - A visually hidden hint (`sr-only`) with the chrome string
        `rails_ui_kit.choices.required_message` ("Select at least one option.") is named
        in the fieldset's `aria-describedby`.

      That hint is how a screen-reader user learns what the visual `*` means. The
      `group` role allows no `aria-required` (axe-core 4.13's standards), and putting
      `required` or `aria-required` on each checkbox would announce that every box is
      required, which is false.
    - **Enhanced.** `ui--choices` is attached only when `multiple:` and `required:` are
      both true (**decided** 2026-09-14, Jonathan Simmons, relayed by the
      orchestrator). It keeps one fact in sync with the DOM. When no checkbox is
      checked, the first enabled checkbox gets `setCustomValidity(hint text)`.
      Otherwise every checkbox's custom validity is cleared. A checked, locked box
      counts as checked, because its value is carried (item 7). A group whose only
      checked box is locked is therefore valid.
      - It re-derives on `connect`, on `change` inside the group, on the form's `reset`
        (in the next task, after the browser restores checkedness, as Select does) and
        on `turbo:morph-element`.
      - The message is read from the hint element's text, so the string has one source
        and the controller holds no English fallback (the chrome contract's
        `JS_FALLBACKS` doesn't grow).
      - The browser then blocks the empty submission, fires `invalid` on that checkbox,
        focuses it and shows the message (verified with `setCustomValidity`).
      - It registers no `keydown`, no `click` and no `document`-level listener.
    - **Without JavaScript**, the empty group submits and the server's validation
      returns it through Field's error. That is the same degradation every constraint
      beyond `required` already has.
    - **Why nothing else needs a controller.** Toggling, single selection, arrow keys,
      reset, disabled, the checked style and the focus style are all the platform's or
      CSS's. They were verified or compile-checked, not assumed (§ Assumptions).
    - **Why this controller is not redundant.** The decider has directed that
      components lean on the browser and CSS rather than JavaScript. The media-query
      primitive was removed under that test. `ui--choices` survives it for one reason:
      the browser has no native "at least one checked" constraint, and neither
      `required` on each box nor `aria-required` on the group expresses one (both
      verified). Nobody should remove it as a platform duplicate unless a native
      constraint for a checkbox group ships in every supported browser. Even then,
      removing it is a spec change, not a cleanup.

### Appearance

15. **`appearance: :list`** puts each choice on a row: the indicator at the
    inline-start, then the text column. The whole row is the label, so the text is a
    target too. The indicator draws the control boundary: `border-input`, with the
    control fill rule `bg-background` in light and `dark:bg-muted/50` in dark, never
    transparent (`ui-presentational-components` § Business rules, rule 6(a), amended
    2026-09-14). The focus ring is the input's own `focus-visible` outline, the same
    as Input's.
16. **`appearance: :card`** makes each choice a bordered box: the indicator, then the
    optional icon, then the text column with its optional description line in
    `text-muted-foreground`. The card takes the control fill and a `border-input`
    boundary, since a card is a control.

    | State | Where it shows | Selector (compiled with tailwindcss 4.3.1 against the kit's theme) |
    |---|---|---|
    | checked | card border `--primary`; indicator filled `--primary` with a `--primary-foreground` mark | `has-checked:` → `&:has(*:checked)` |
    | keyboard focus | a 2px `--ring` outline, offset 2px, on the **card**; the input's own outline is suppressed in this appearance only | `has-focus-visible:` → `&:has(*:focus-visible)` |
    | disabled | card at 50% opacity, not-allowed cursor | `has-disabled:` → `&:has(*:disabled)`, which also matches inputs inside `fieldset[disabled]` |
    | invalid | every card's border `--destructive`, **including the checked card** | the fieldset's `aria-invalid`, read by a named `group/choices` |

    - **Focus appears only for the keyboard.** A pointer click doesn't match
      `:focus-visible` on the radio, and an arrow key does (verified), so the card
      rings only for keyboard users.
    - **Invalid must beat checked, and a naive class list gets this backwards.**
      `group-aria-invalid/choices:border-destructive` and `has-checked:border-primary`
      compile to equal specificity (0,2,0), and Tailwind emits `has-checked:` later. So
      the checked card would keep its primary border inside an invalid group. The
      invalid border needs a compound or more specific selector. The acceptance check
      measures the computed colour rather than trusting the class order.
    - **Don't style from `:invalid` or `:user-invalid`.** A required radio group is
      `:invalid`, and so is its fieldset, from first paint before anyone has touched it
      (verified). Invalid styling reads `aria-invalid` only, as Input's does.
    - **The mark has to survive forced colours.** The check and the dot are an
      `aria-hidden` SVG in `currentColor` beside an `appearance-none` input. In forced
      colours the fill becomes `Canvas` and a background-drawn mark would vanish, but a
      `currentColor` stroke becomes `CanvasText`.
17. **`size:` sets each choice's minimum block size** to the step's
    `--control-height*` token (`ui-control-sizing`), in both appearances. So a
    one-line card matches the Input or Select beside it, and every choice stays a
    target of at least 24px (WCAG 2.5.8). Text size and indicator size don't change by
    step, as with Input and Select. Content makes a choice taller; a step never makes
    it shorter. An unknown size fails the way an unknown variant does.
18. **Long text and narrow widths: controls truncate, lists wrap**
    (`ui-localization` § Behavior, item 12). Choices is a list, so it never truncates.
    - Choice text and description wrap. An unbreakable string breaks rather than
      overflowing (`wrap-break-word`).
    - The indicator doesn't shrink and stays aligned with the first line of text.
    - The text column and the fieldset are `min-w-0`. Without that, a fieldset's UA
      `min-inline-size: min-content` holds it at its longest word: a 100px fieldset
      rendered 382px wide in Chrome (verified). Tailwind 4's preflight doesn't reset
      it.
    - The default layout stacks: a `grid` with a gap. Columns are the caller's
      `class:` (`sm:grid-cols-3`), so at phone widths cards stack unless the caller
      says otherwise.
19. **Direction: logical CSS, no RTL promise.** Every directional class is logical
    (`ps-`/`pe-`, `gap`, `text-start`), and the kit's guard test holds that. This
    follows `ui-localization-rtl`'s ruling, "convert now, promise later". Choices
    claims no RTL support and adds no RTL browser check. Arrow keys inside a radio
    group are the browser's, left unmodified.

### Turbo

20. **No state to reset.** Every checked state lives in the inputs, and Turbo's
    snapshot copies checkedness (input cloning copies it). Back therefore restores the
    choices the user left. A Stream `replace` of the Field or the component delivers
    fresh markup, and `ui--choices`, if present, re-derives on connect. A `422`
    re-render shows the submitted choices checked through `checked:` and Field's error.

## Business rules

Inherits every rule in `ui-component-library` § Business rules unmodified. The parent's
numbering is referenced as-is; the rules below are scope-local.

**Must**

1. **The inputs are the form control.** Values live only in real radio and checkbox
   inputs, Rails' blank hidden field and the locked-value hidden fields. No JavaScript
   variable, data attribute or other hidden input holds a value (§ Behavior, items 6
   and 7).
2. **Unchecking everything clears the attribute.** With the default
   `include_hidden: true`, a checkbox group with nothing checked submits the blank
   entry that empties an association (§ Behavior, item 5). A change that breaks this
   is a data-integrity regression, whatever else it adds.
3. **Rails' semantics, except where recorded.** Names, ids, the hidden field, `checked:`,
   `include_hidden:` and enum labels behave as `collection_radio_buttons` and
   `collection_check_boxes` do. There are three deviations, each recorded with its
   reason:
   - `[]` is appended to a stated name (§ Behavior, item 4);
   - checked, locked values are carried by hidden inputs (§ Behavior, item 7);
   - the hidden fields are disabled along with the group (§ Behavior, item 12).

   A fourth deviation needs a recorded reason too.
4. **No kit JavaScript except the required-checkbox validity.** `ui--choices` exists for
   § Behavior, item 14 and nothing else. It is the one place the browser has no native
   constraint, which is why it passes the decider's lean-on-the-platform test and why
   it isn't redundant. A later feature that needs JavaScript (select-all, min/max, an
   exclusive option) extends that controller under a spec change. It never adds a
   second controller, and never puts behaviour on radios.
5. **One option normaliser** (`ui-component-library` § Business rules, rule 4). Choices
   and Select both read `Ui::OptionSet`. Neither copies it or subclasses it to change a
   source's meaning.
6. **A group is named, described and marked invalid as a group.** `aria-labelledby`,
   `aria-describedby` and `aria-invalid` go on the fieldset. An input's own name is
   only its choice's text. `required` never appears on a checkbox.
7. **The whole card is the target and never the focus.** DOM focus is always on a real
   input. No card, label or fieldset is focusable, and nothing adds a `tabindex`.
8. **Accessibility is definition-of-done** (`ui-component-library` § Business rules,
   rule 6). Both variants and both appearances pass `assert_accessible` resting,
   checked, disabled and invalid, in light and dark mode. The indicator boundary, the
   checked card border and the focus ring reach 3:1 on every token surface.

**Should**

9. **Every chrome string goes through i18n**, resolving call site → host locale → kit
   default. Choices has exactly one, `rails_ui_kit.choices.required_message`, overridden
   per instance by `required_message:` (`ui-localization` § Behavior, items 1–3).
10. **Descriptions and icons are content, not chrome.** They come from the caller's
    collection and the host translates them.

**May**

11. A host may pass `include_hidden: false` when it genuinely wants "no key means no
    change". The docs show what that costs.

## Assumptions

Inherits `ui-component-library` § Assumptions, and `ui-select`'s and
`ui-field-model-binding`'s.

- **Two Field prerequisites land before the component.** Each is small and
  backwards-compatible, and each is made under `ui-field-model-binding` with its own
  test. Neither is a Choices-local workaround.
  1. **Field's label drops `for` when the control isn't labelable.** A control
     component answers a class-level `labelable?` (HTML's own term). It defaults to
     true, and `Ui::ChoicesComponent` returns false. `Ui::Field::LabelComponent` omits
     `for:` for a non-labelable control and keeps `id`. Input, Textarea and Select
     render exactly as today.
  2. **`Ui::Field::ControlComponent` hands a Choices control the record's value as
     `checked:`**, unless the caller passed `checked:`, as it already hands Select
     `selected:`. `ModelBinding#value` already returns `role_ids` as an array and an
     enum as its key.

  **At a contradiction**, where either can't be added without changing what an
  existing Field renders, escalate to the decider rather than giving Choices its own
  label.
- **The `Ui::OptionSet` move waits for the in-flight Select work.** Another worker is
  editing `app/components/ui/select*` on this branch. The move (§ Behavior, item 3) is
  the first build step once that work is committed. **At a contradiction**, where
  Select's option handling has diverged so that one class can't serve both, escalate.
  Don't fork a second normaliser.
- **Screen readers speak a fieldset's `aria-describedby` and `aria-invalid` when focus
  enters the group.** This is widely relied on (GOV.UK's fieldset pattern), and Chrome
  computes the description (§ Acceptance checks). VoiceOver in Safari hasn't been
  observed doing it. **At a contradiction**, Field's error id is also added to each
  input's `aria-describedby`, and `aria-invalid` to each input. Record it as a
  correction, and don't move the group's name.
- **The browser claims were checked in headless Chrome** (Selenium, this bundle,
  2026-09-14):
  - a disabled fieldset submits nothing, and its hidden field matches `:disabled`;
  - `aria-labelledby` names the fieldset and wins over the wrapping label's text;
  - a pointer click doesn't set `:focus-visible` on a radio, and ArrowDown does;
  - ArrowDown wraps from the last radio to the first;
  - a click on the description text checks the radio;
  - `setCustomValidity` on the first checkbox blocks submission and focuses it;
  - `required` on one radio makes the whole group `valueMissing`;
  - `required` on every checkbox demands all of them;
  - a fieldset keeps `min-inline-size: min-content`.

  Safari and Firefox weren't run. **At a contradiction** in either browser, record the
  browser and the behaviour, and escalate before adding JavaScript to cover it.
- **The CSS claims come from a real compile.** tailwindcss 4.3.1 was run against the
  kit's `engine.css`, with the host's `@custom-variant dark`. `has-checked:`,
  `has-focus-visible:`, `has-disabled:`, `group-aria-invalid/choices:` and `min-w-0`
  produce the selectors in § Behavior, item 16, including the ordering trap.
- **Rails' collection helper output is stable across the supported range.**
  `collection_helpers.rb` is identical in ActionView 7.2.3.2 and 8.1.3.1. **At a
  contradiction** in a later Rails, follow what that Rails renders and record a
  correction.
- **`ActiveRecord`'s `ids_writer` drops blank ids.** It does in 8.1.3.1
  (`compact_blank`). The unit check runs against in-memory sqlite, which the Gemfile's
  test group already has.
- **The locale file is present.** `config/locales/rails_ui_kit.en.yml` exists and
  `Ui::Chrome` resolves strings. This scope adds one key to `ui-localization`'s chrome
  inventory. The chrome contract test and the i18n docs page absorb it without
  special-casing, and the count stated in that scope's text is updated when this one
  builds.
- **Rack keeps the last value for a repeated non-array key.** Verified on Rack 3.2.7,
  and it's what Rails' own `checkbox` hidden field relies on. The radio carrier's
  ordering depends on it (§ Behavior, item 7). **At a contradiction**, drop the radio
  carrier rather than risk a locked value overriding the user's choice, and escalate.

## Critical files

- `app/components/ui/choices_component.rb`, `choices_component.html.erb` (new) — the
  component.
- `app/components/ui/select/option_set.rb` → `app/components/ui/option_set.rb` — the
  move, the caller-named messages, `Item#object` (§ Behavior, item 3).
- `app/components/ui/select_component.rb`, `select/listbox_component.rb`,
  `test/components/ui/select_options_test.rb` — references that follow the move.
- `app/components/ui/field/label_component.rb`, `field/control_component.rb` — the two
  prerequisites.
- `app/components/ui/field_component.rb` — read only; `control_attributes`,
  `label_id` and `required?` are what item 10 routes.
- `app/javascript/rails_ui_kit/controllers/choices_controller.js` (new), and
  `app/javascript/rails_ui_kit/index.js` — `ui--choices` and its registration.
- `app/components/ui/chrome.rb` — `chrome_string :required_message`.
- `config/locales/rails_ui_kit.en.yml` — `rails_ui_kit.choices.required_message`.
- `app/components/ui/input_component.rb`, `select_component.rb` — read only; the fill,
  boundary, focus and invalid classes the indicator and card follow.
- `examples/config/initializers/docs_pages.rb`, `examples/app/views/docs/` — a Choices
  page (both variants, both appearances, a Field with a real `422`, the unchecked-all
  round trip, `include_hidden: false`'s cost, and a locked value with its plain "a
  locked checkbox is not authorization" warning) and the i18n page's new key row.
- `README.md` and the forms guide — the same warning wherever `disabled_values:` is
  documented (§ Behavior, item 7).
- `test/application_system_test_case.rb` — `assert_accessible`, `each_token_surface`,
  `contrast_ratio`, `assert_focus_outline_in_forced_colors`, `cdp_browser`.

## Acceptance checks

### agent-loopable

- For collection, array, hash and enum sources, each variant renders names, values, ids, `checked`, `disabled`, `form` and the prepended hidden field identical to `collection_radio_buttons` / `collection_check_boxes` for the same arguments, `include_hidden: false` omits the field, `multiple: true` appends `[]` exactly once, and grouped sources, `include_blank:`, `prompt:` and a `description_method:` on a non-collection source each raise `ArgumentError` — run: `bundle exec rake test TEST=test/components/ui/choices_component_test.rb`
- A rendered checkbox group, submitted with every box unchecked the way a browser builds the entry list, empties an in-memory ActiveRecord `has_and_belongs_to_many` association; the same submission without the hidden field leaves it unchanged; a checked, locked value stays in the association after a save that unchecks every other box; a locked checked radio's value survives an untouched save and loses to an enabled radio the user chose; a `disabled: true` group contributes no entry at all, carriers included — run: `bundle exec rake test TEST=test/components/ui/choices_submission_test.rb`
- `Ui::OptionSet` serves Select and Choices, `Ui::Select::OptionSet` no longer exists, its errors name the calling component, `Item#object` is the collection element (nil otherwise), and every Select unit test still passes — run: `bundle exec rake test TEST="test/components/ui/{option_set,select_options,select_component}_test.rb"`
- In a Field, a Choices control gets a label with `id` and no `for`, a fieldset with `aria-labelledby`, `aria-describedby` (description, error, then the required hint) and `aria-invalid`; a model-bound Field hands `checked:` from the record; Input, Textarea and Select Fields render byte-identical to before — run: `bundle exec rake test TEST="test/components/ui/{field_choices,field_component,field_model_value}_test.rb"`
- A checked value in `disabled_values:` renders exactly one hidden carrier with the input's name and value — after the blank field and before every input for radios — and an unchecked disabled value renders none; a required checkbox group puts `required` on no checkbox, renders the hint and `data-controller="ui--choices"`; a required radio group puts `required` on every radio and has no controller; `required_message:` overrides the string per instance and the chrome contract still holds — run: `bundle exec rake test TEST="test/{components/ui/choices_component,i18n/chrome_contract,components/ui/chrome_override}_test.rb"`
- The component uses no physical directional class — run: `bundle exec rake test TEST=test/components/ui/logical_direction_test.rb`
- In the browser, checking two boxes and submitting posts both ids; unchecking both and submitting posts `role_ids[]=""`; a `422` re-render shows the submitted choices checked and Field's error — run: `bundle exec rake test:system TEST=test/system/choices_submission_test.rb`
- With real keypresses and no kit controller attached to radios: Tab enters a radio group at the checked radio, Arrow keys move and check with wrap-around and skip disabled radios, Tab leaves the group; Space toggles a checkbox; a click on a card's text, description, icon and padding each checks it; `document.activeElement` is always an input — run: `bundle exec rake test:system TEST=test/system/choices_keyboard_test.rb`
- A required radio group and a required checkbox group each block an empty submission with no request sent and focus on their first enabled input; the checkbox group's validation message is the chrome string; checking one box clears it; a group whose only checked box is locked submits; form reset and a Turbo Stream replace both re-derive it — run: `bundle exec rake test:system TEST=test/system/choices_validation_test.rb`
- With JavaScript disabled, both variants post their choices, the unchecked-all entry clears the attribute, and an empty required checkbox group posts and returns Field's error — run: `bundle exec rake test:system TEST=test/system/choices_no_javascript_test.rb`
- Chrome's accessibility tree (CDP) shows `radiogroup`/`group` named by the Field label and described by description, error and hint; each input named by its choice text only and described by its description line; no icon in the tree; and both variants in both appearances pass `assert_accessible` resting, checked, disabled and invalid in light and dark mode — run: `bundle exec rake test:system TEST=test/system/choices_accessibility_test.rb`
- Measured computed styles: a card rings with `--ring` on keyboard focus and not after a click; a checked card's border is `--primary` and an invalid group's checked card is `--destructive`; indicator boundary, checked border and ring reach 3:1 on every token surface; the focus outline and the check mark stay visible under forced colours — run: `bundle exec rake test:system TEST=test/system/choices_appearance_test.rb`
- At a 320px viewport, a 200-character choice and a 60-character unbreakable token wrap inside their card with no horizontal overflow of the fieldset; the indicator neither shrinks nor leaves the first line; every choice measures at least its step's `--control-height*` and 24px — run: `bundle exec rake test:system TEST=test/system/choices_layout_test.rb`
- `ui--form-change` turns dirty when a choice changes and pristine when it changes back, and Back from a cached page restores the choices the user left — run: `bundle exec rake test:system TEST=test/system/choices_turbo_test.rb`
- `registerControllers` registers `ui--choices` — run: `bundle exec rake test TEST=test/javascript/register_controllers_test.rb`

### judgeable

- `ui--choices` does only § Behavior, item 14: it holds no value, registers no key, click or document-level listener, and nothing else in the component needs JavaScript — judged against § Business rules, rules 1 and 4.
- The docs page, README and guide state plainly, beside `disabled_values:`, that a locked checkbox is not authorization and the server decides what a user may change — judged against § Behavior, item 7.
- The API reads like `collection_radio_buttons` and `collection_check_boxes` to a Rails developer, and every keyword that differs from its Rails namesake is one of the recorded deviations — judged against § Behavior, items 1–5 and 12, and § Business rules, rule 3.
- Choices consumes `Ui::OptionSet` without copying, subclassing or re-deriving any source's semantics — judged against § Behavior, item 3 and § Business rules, rule 5.
- The group's name, description, invalid and required routing matches § Behavior, item 10's table, and no ARIA attribute appears on an element whose role doesn't allow it.

### human-gate

- Jonathan uses both variants with a keyboard and with VoiceOver in Safari, entering a required, invalid, described group from outside, and accepts what is announced or triggers the contradiction path in § Assumptions.
- Jonathan looks at the card appearance at phone and desktop widths, in light and dark mode, with a description line and an icon, and accepts it as high-fidelity or says what's off.

## Out of scope / deferred

- **Select-all with an indeterminate box.** `indeterminate` is a DOM property with no
  HTML attribute, so it needs JavaScript, and without JavaScript it's a dead checkbox.
  Its natural home is bulk selection of rows, which is table territory (cut). No form
  build needs it for a handful of choices. If one does, it extends `ui--choices`
  (§ Business rules, rule 4).
- **`min:` / `max:` counts.** They're designed to extend item 14's validity check with a
  count and two pluralised chrome strings, with no API change. Not built: no client
  form needs "pick up to 3" yet, and each adds strings, plural handling and tests.
- **An exclusive option ("None of the above").** It needs JavaScript to clear the
  others, and a server contract for a "none" value submitted alongside real ids. A
  preceding yes/no radio group models it without either.
- **Combobox multi-select** — `ui-select`'s territory, and a different ARIA pattern
  (§ Non-goals).
- **Switch / toggle** — not a collection choice; it would need its own rule 0 case
  (§ Non-goals).
- **Virtualisation** — use Select with remote search (§ Non-goals).
- **Grouped choices** (`group_method:`, grouped `options:`) — they raise in v1
  (§ Behavior, item 3).
- **Descriptions and icons for array, hash and enum sources** — map to a collection of
  objects instead (§ Behavior, item 2).
- **A per-choice builder block** like Rails' `collection_check_boxes { |b| … }` — not
  planned (§ Non-goals).
- **`form.ui_choices`** — a form builder is deferred by decision.
