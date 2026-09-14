---
slug: ui-select
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: medium
size: large
target_model: frontier
created: 2026-09-13
loop_budget: 8
---

## Intent

The kit is being cut to components that own a Rails or Turbo concept, or that solve a
genuinely hard browser behaviour. The generic `Ui::NativeSelectComponent` passes
neither test and is being deleted. What replaces it is **an intelligent select built
from a collection, with search, using a dropdown with keyboard support.** It passes
both tests. It owns what `collection_select`, model enums and form submission mean in
Rails. And the WAI-ARIA combobox keyboard model is among the hardest browser
behaviours there is to get right.

**The trap.** It is easy to build a JavaScript widget that looks like a select but has
quietly stopped being a form control. The native `<select>` does a lot for free:

- it submits;
- it validates `required`;
- it resets with its form;
- it works without JavaScript;
- it is what Rails' form helpers, `field_error_proc`, `form_change` and a host's
  `change->` Stimulus actions expect.

A replacement that loses any of those is a regression dressed as a feature. This scope
is shaped so that it can't. The real `<select>` stays in the page as the only place
the value lives (§ Business rules, rule 1). Everything the user sees and presses
mirrors it and drives it.

The component also takes over from Dropdown's `kind: :listbox`. That kind has no
selection model, and it moves real DOM focus onto `[role="option"]` elements, which is
the focus model a listbox must never use (§ Intent of ui-positioning-and-navigation;
the audit's Dropdown section, "Hide or build").

**Appetite.** One component with two ARIA modes. Its Rails option API. Local search.
Field and Turbo integration. The browser tests that prove it is still a form control.
Four small primitive prerequisites (§ Assumptions). Remote search is designed here and
built later.

## Goal

`Ui::SelectComponent` renders, inside `Ui::FieldComponent`, a select-only or searchable
combobox whose selected value posts with its form, blocks submission when `required`,
restores on form reset, round-trips through a `422` re-render and still works with
JavaScript disabled. Every key in the APG example for its mode is driven by real
keypresses in `test/system/`, and it passes `assert_accessible` in light and dark mode.

## Non-goals

- **Not a new form-control model.** No hidden input, no form-associated custom element,
  no second place the value lives (§ Behavior, item 1).
- **Not multiple selection.** `<select multiple>` is a different ARIA pattern (a
  multi-select listbox), with a different submission shape (`name[]` plus Rails'
  `include_hidden`). It needs its own scope.
- **Not creatable options.** Typing a value that isn't in the list and submitting it
  turns a select into a text field with suggestions. That is a different control.
- **Not remote search in v1.** It is designed in § Behavior, items 27–31, and built in
  a later phase, with no v1 API break.
- **Not the form builder.** There is no `form.ui_select`, and a form builder is deferred
  by decision rather than planned (§ Behavior, item 14).
- **Not a Command palette.** A menu of actions is not a value picker.
  `ui-deferred-component-decisions` owns Command.
- **Not virtualisation.** `ui--roving-focus` walks its item targets
  (§ Out of scope / deferred of ui-positioning-and-navigation). A collection too large to
  render belongs to remote search, not to windowing.
- **Not new primitives.** The four prerequisites in § Assumptions are small additions to
  existing primitives, made in their own files under their own specs' rules. Select
  consumes them and reimplements none of them.

## Behavior

### The submission model

1. **The real `<select>` is the single source of truth.** The component server-renders
   a real `<select>` with its `<option>`s, and that element carries the field's `id`,
   `name`, `required`, `disabled` and `form` attributes. The custom combobox and listbox
   hold no value of their own. Every state they show is re-derived from the select, in
   one render path, whenever the value changes.

   The alternatives, and why the select wins:

   | Model | Submits | `required` | Form reset | No-JS | Rails helpers, `form_change`, `change->` |
   |---|---|---|---|---|---|
   | **Native `<select>`, mirrored** | yes | yes | yes | yes | yes |
   | `<input type="hidden">` | yes | no: barred from constraint validation | no: a hidden input's default *is* its value, so reset can't restore it | no | partly: no `change` event from user input |
   | Form-associated custom element (`ElementInternals`) | yes | through `setValidity`, reimplemented | through `formResetCallback`, reimplemented | no | no: a second component paradigm beside Stimulus, and not the markup Rails' helpers render |
   | Customizable `<select>` (`appearance: base-select`) | yes | yes | yes | yes | yes, but no search, and not cross-browser (§ Assumptions) |

   Only the mirrored select keeps all five for free. The hidden input and the custom
   element both reimplement things the platform already does, which
   `ui-component-library` § Business rules, rule 8 names a defect.
2. **Progressive enhancement, in the same box.** Server-rendered, the select is visible
   and styled as the kit's form control, with a decorative chevron. The combobox and
   popup are in the markup, `hidden`. When `ui--select` connects, it marks the root
   `data-enhanced`. It also reveals the combobox, and takes the select out of sight and
   out of the accessibility tree: `aria-hidden="true"`, `tabindex="-1"`, `opacity: 0`,
   `pointer-events: none`, laid exactly over the combobox's box. The select is never
   `display: none`, `hidden` or `inert`: a browser can't focus an invalid control it
   can't render, so `required` would block the submission silently. Both states use the
   same height, padding, border and chevron, so the swap causes no layout shift. If
   JavaScript is off, or fails to load, the page keeps a working native select.
3. **User choice writes the select, then announces it.** Choosing an option sets
   `select.value`, then dispatches bubbling `input` and `change` events from the select.
   `ui--select` re-renders from its own `change` listener, so there is exactly one
   render path. The same events are what `ui--form-change`, a host's
   `data-action="change->…"` and an auto-submitting form listen for. Choosing the
   option that is already selected dispatches nothing, as a native select would.
4. **Programmatic change.** Host code sets `select.value` and dispatches `change`.
   `ui--select` re-renders from it. Setting `.value` with no event is not observable,
   just as it isn't for any native control. The guide documents the event.
5. **Form reset.** `ui--select` listens for `reset` on the select's form owner and
   re-renders in the next task, after the browser has restored the select's default
   selectedness.
6. **Constraint validation.** A `required` select with a blank value blocks submission,
   as the platform does. When the browser reports it `invalid` and moves focus to it,
   `ui--select` forwards that focus to the combobox. The combobox carries
   `aria-invalid="true"` until the value is valid again. The browser's own validation
   message is kept, anchored to the select, which sits over the combobox's box (item 2).
   § Assumptions records the contradiction path if the browser drops that bubble when
   focus is forwarded.
7. **Disabled.** `disabled: true` disables the native select, so it doesn't submit, as
   in Rails. The combobox gets `aria-disabled="true"`, leaves the tab order (the search
   input is `disabled`), and never opens.

### The Rails API

8. **Options, modelled on what developers already type.** Exactly one option source per
   instance. Each sketch sits beside the Rails helper it mirrors:

   ```ruby
   # collection_select(:post, :author_id, Author.order(:name), :id, :name)
   Ui::SelectComponent.new(name: "post[author_id]", collection: Author.order(:name),
                           value_method: :id, text_method: :name, selected: @post.author_id)

   # select(:post, :state, [["Draft", "draft"], ["Published", "published"]]) — text first, as options_for_select
   Ui::SelectComponent.new(name: "post[state]", options: [["Draft", "draft"], ["Published", "published"]])
   Ui::SelectComponent.new(name: "shirt[size]", options: %w[S M L])

   # select(:post, :state, { "Draft" => "draft", "Published" => "published" }) — text => value
   Ui::SelectComponent.new(name: "post[state]", options: { "Draft" => "draft", "Published" => "published" })

   # A model enum, labelled through i18n; submits the enum key, which the enum setter accepts
   Ui::SelectComponent.new(name: "order[status]", model: Order, enum: :status, selected: @order.status)

   # grouped_collection_select(:city, :country_id, @continents, :countries, :name, :id, :name)
   Ui::SelectComponent.new(name: "city[country_id]", collection: @continents, group_method: :countries,
                           group_label_method: :name, value_method: :id, text_method: :name)

   # grouped_options_for_select({ "Europe" => [["France", "fr"]] })
   Ui::SelectComponent.new(name: "trip[country]", options: { "Europe" => [["France", "fr"]] })

   # selected:, include_blank:, prompt:, disabled_values:
   Ui::SelectComponent.new(name: "post[author_id]", collection: authors, value_method: :id, text_method: :name,
                           selected: @post.author_id, include_blank: "No author", prompt: true, disabled_values: [3])
   ```

   `value_method` and `text_method` accept a symbol or a proc, as Rails does.
9. **Enum labels.** `model:` with `enum:` reads the keys of the enum mapping
   (`Order.statuses`), in declaration order. Each label is
   `Order.human_attribute_name("status.#{key}")`. That is Rails' own nested-attribute
   lookup (`activerecord.attributes.order/status.pending`), and it falls back to the
   humanised key. The kit invents no enum translation convention.
10. **Rails' blank and prompt semantics, exactly.**
    - `include_blank: true` renders an empty option; a string renders an empty-valued
      option with that text.
    - `prompt:` renders only when the selected value is blank. `prompt: true` uses Rails'
      own `helpers.select.prompt` key ("Please select").
    - `required: true` with neither a blank nor a prompt adds the empty option, as Rails'
      `select` does for a required single select, so a required select can start blank.
    - `selected:` compares by string value, as Rails' helpers do.
11. **One option model, rendered twice, proven equal.** The native `<option>`s and
    `<optgroup>`s are rendered with Rails' public helpers (`options_for_select`,
    `options_from_collection_for_select`, `option_groups_from_collection_for_select`,
    `grouped_options_for_select`), plus blank and prompt handling that matches item 10 —
    adopted, not rebuilt. The listbox is rendered from the same normalised list of
    `{ text, value, disabled, selected, group }`. A unit test asserts that the native
    select matches what `collection_select` and `select` render for the same arguments,
    and that the listbox has the same value, text, disabled and selected sequence.
12. **Attribute routing.** The component takes the attributes `Ui::FieldComponent`
    hands any control, so it needs no special case there:
    - `id`, `name`, `required`, `disabled`, `form` and `autofocus` go to the native
      select;
    - `aria-describedby` and `aria-invalid` go to both the select (for the no-JS state)
      and the combobox;
    - `class:` merges onto the visible control, as it does for Input
      (`ui-component-library` § Business rules, rule 5);
    - other `data:` and `aria:` attributes go on the root, where `change` events bubble
      to.
13. **Search is a flag.** `search: false` is the default. `search: true` switches the
    combobox to its editable mode (item 17). Nothing else in the API changes between
    modes.
14. **No form-builder method. That decision is deferred, not planned.** There is no
    `form.ui_select`, and no scope is queued to add one. A form builder would be the
    first time the kit extends a Rails API rather than supplying a component. The
    decider has deferred that direction, along with any other Rails primitive override
    such as setting `field_error_proc` in a host app
    (`ui-field-model-binding` § Out of scope / deferred, which records the reasoning
    and the cost of reversing it). A caller binds Select to a record through Field:
    `Ui::FieldComponent.new(model:, attribute:)` fills `name`, `selected` and `errors`
    from the record (`ui-field-model-binding` § Behavior, items 4, 13 and 16). Select's
    Rails-shaped option API (items 8–11) still leaves a builder possible later without
    an API change. That is a property of the API, not a commitment to build one.

### Two modes, two APG patterns, one component

15. **One component, not a Select plus a Combobox.** The two modes share the submission
    model, the option API, Field integration, positioning, the overlay, the listbox
    markup and Turbo handling. They differ only in the combobox element and a key table.
    A second component would duplicate every shared part to save one branch. The parent
    Phase C row's separate "Select" and "Combobox" are both this scope.
16. **`search: false` is the APG select-only combobox**, taken from the w3.org example,
    verified 2026-09-13. The combobox is a `<div role="combobox" tabindex="0">` whose
    text is the selected option's label. It carries `aria-labelledby` (the Field label),
    `aria-controls` (the listbox), `aria-expanded` and `aria-activedescendant`.
    `ui--roving-focus` runs in `activedescendant` mode with `loop: false`,
    `typeahead: true` and its `input` target on the combobox. Because that input is not
    editable, the primitive claims `Home`, `End` and typed characters for navigation
    (§ Behavior, Primitive C of ui-positioning-and-navigation).

    | State | Key | Result |
    |---|---|---|
    | closed | `ArrowDown`, `Alt+ArrowDown`, `Enter`, `Space` | Opens without moving visual focus or changing selection; the active option is the selected one, if any. |
    | closed | `ArrowUp` | Opens, then moves visual focus to the first option (APG's wording, followed as written). |
    | closed | `Home` / `End` | Opens and moves visual focus to the first / last option. |
    | closed or open | printable characters | Opens if closed, then typeahead: first match, full-string match for quick succession, cycling for a repeated character. |
    | open | `ArrowDown` / `ArrowUp` | Next / previous option; at the end, visual focus does not move. |
    | open | `Home` / `End` | First / last option. |
    | open | `PageUp` / `PageDown` | Up / down 10 options, or to the first / last. |
    | open | `Enter`, `Space`, `Alt+ArrowUp` | Selects the active option, closes, visual focus on the combobox. |
    | open | `Tab` | Selects the active option, closes, and moves focus on (the default is not prevented). |
    | open | `Escape` | Closes with no change. |

    `Enter` never submits the form in this mode.
17. **`search: true` is the APG editable combobox with list autocomplete**, verified
    against the w3.org example on 2026-09-13, restricted to the list's values.
    - **Markup.** The combobox is an `<input type="text" role="combobox"
      aria-autocomplete="list" autocomplete="off">`. It has no `name`, so it never
      submits. It has the same `aria-labelledby`, `aria-controls`, `aria-expanded` and
      `aria-activedescendant` as select-only mode.
    - **Show-options button.** A chevron `<button type="button" tabindex="-1">`, named
      through i18n, opens the listbox for touch screen-reader users. APG keeps it for
      exactly that reason.
    - **Primitive values.** `ui--roving-focus` runs with `loop: true`. The input is
      editable, so the primitive leaves `Home`, `End` and typing to the text field.

    | State | Key | Result |
    |---|---|---|
    | closed | `ArrowDown` / `ArrowUp` | Opens and moves visual focus to the first / last option. |
    | closed | `Alt+ArrowDown` | Opens without moving visual focus. |
    | closed | `Escape` | Puts the text back to the selected option's label, and changes nothing else. A deliberate deviation from the APG table, which clears the field — see below. |
    | closed | `Enter` | Not handled: implicit form submission proceeds, as for any text field. |
    | open | `ArrowDown` / `ArrowUp` | Next / previous option, wrapping. |
    | open | `Enter` | With an active option, selects it and closes; with none, closes. Either way the key never submits the form while the listbox is open. |
    | open | `Escape` | Closes; the text reverts to the selected label. |
    | open | `ArrowLeft`, `ArrowRight`, `Home`, `End`, printable characters | Visual focus returns to the text field (`aria-activedescendant` is cleared) and the key edits the text. |
    | open | `Tab` | Closes without selecting; focus moves on. |

    Typing opens the listbox and filters it (item 21).

    **Committing on close.** The text field only ever shows a real option's label once
    the listbox closes:
    - an option was chosen: its label;
    - the text is empty and the select has a blank option: blank is selected;
    - anything else: the selected option's label is restored.

    Tab doesn't select in this mode because APG's list-autocomplete example uses manual
    selection: what the user typed is never silently turned into a choice.

    **Escape on a closed field restores rather than clears.** In the APG example the text
    field *is* the value, so clearing it is a complete operation. Here the value lives in
    the select, and a transcribed "clear the field" would have to do one of two wrong
    things: leave an empty field over a select still holding a value, which breaks
    § Business rules, rule 1, or clear the selection, which turns the cancel key into a
    destructive one that dispatches `input` and `change` from a keystroke the user meant
    as "never mind" — and which behaves differently depending on whether the caller
    offered a blank option. Escape therefore leaves the value alone in both modes, and
    clearing a choice is what `include_blank:` and `prompt:` are for. The key is left
    unclaimed when the text already matches the label, so it still reaches a surrounding
    Modal (§ Behavior, item 25).
18. **DOM focus never leaves the combobox** while the user is working in the widget. The
    popup opens without taking focus (§ Assumptions, prerequisite 1). Options are
    `tabindex="-1"`, and a `mousedown` on an option is cancelled by the primitive.
    Clicking an option selects it and closes the listbox. Hover moves the active option
    through `ui--roving-focus#activate`.
19. **`aria-selected`** follows both APG examples: `aria-selected="true"` is on the
    option `aria-activedescendant` references, and on no other. The option matching the
    select's current value is marked separately, with `data-selected` for a check-mark
    style, so a sighted user can see the current choice while visual focus is elsewhere.
20. **Disabled options** (`disabled_values:`, or a disabled `<option>`) follow the
    primitive's default. They are reachable by arrows, `Home`, `End` and typeahead, so a
    screen-reader user can discover them, but they never select
    (§ Behavior, Primitive C of ui-positioning-and-navigation, "Disabled items").

### Search and scope boundaries

21. **Local filtering.** Typing filters the listbox to options whose label contains the
    typed text, ignoring case and diacritics (`"e"` matches `"É"`).
    - Non-matching options, and any group left with no matching option, get the `hidden`
      attribute. The primitive already skips hidden items.
    - After each filter, `aria-activedescendant` is cleared, per APG: visual focus is on
      the text field.
    - Clearing the text shows every option again.
    - The native select is never filtered, so the value that submits can't be hidden away.
22. **Empty state.** When no option matches, the popup shows a "No results" message from
    `rails_ui_kit.select.no_results`. A polite `role="status"` region in the popup
    announces the result count (`rails_ui_kit.select.results`, pluralised) once typing
    settles, so a screen-reader user knows the list narrowed, or emptied, without having
    to arrow into it.
23. **In v1:**
    - both modes;
    - the collection, array, hash, enum and grouped sources;
    - `selected:`, `include_blank:`, `prompt:`, `required:`, `disabled:` and
      `disabled_values:`;
    - local search with its empty state.

    Groups render as `role="group"` with `aria-labelledby` pointing at a presentational
    label element. Navigation crosses group boundaries in DOM order.

    **Not in v1:** multiple selection, creatable options, remote search (designed below)
    and virtualisation. Whether a Capybara helper for host test suites ships in v1 is
    still open (see `open-questions.md`).

### Popup, positioning and Field

24. **Composition.** The root element stacks `ui--select`, `ui--overlay`, `ui--anchor`
    and `ui--roving-focus`, the way Dropdown already stacks its controllers.
    - **`ui--overlay`** runs in `layer` mode. Its `trigger` is the combobox and its
      `content` is the popup, which is placed in the top layer as `popover="auto"`. It
      has `scrollLock: false`, and opens without moving focus (prerequisite 1). Escape
      and outside-click dismissal, top-layer placement and presence are all the
      overlay's.
    - **`ui--anchor`** has `anchor` on the combobox and `floating` on the popup, with
      `placement: "bottom-start"`, `matchWidth: true` and `strategy: "fixed"`, because
      the popup is in the top layer.
    - **`ui--roving-focus`** has `input` on the combobox and `item` on every option.
    - **`ui--select`** owns only what no primitive does: the submission mirror
      (items 1–7), the mode key tables above (open, select, commit), filtering and the
      empty state. It sets `ui--anchor`'s `active` while open, and writes
      `ui--roving-focus`'s `activeId` when it opens the listbox, filters or selects.
25. **Nesting.** A Select inside a `Ui::ModalComponent` dialog opens above it, is not
    clipped by the dialog's scroll box, and takes the first Escape while the Modal takes
    the second. That is the top layer's ordering, not Select's
    (`ui-component-library` § Business rules, rule 7).
26. **Field integration needs no extra code from the caller.**

    ```erb
    <%= render Ui::FieldComponent.new(name: "order[status]", errors: @order.errors[:status]) do |field| %>
      <% field.with_label { "Status" } %>
      <% field.with_control(Ui::SelectComponent, model: Order, enum: :status, selected: @order.status) %>
      <% field.with_description { "Customers are emailed when this changes." } %>
    <% end %>
    ```

    Field's `with_control` passes `id`, `name`, `aria-describedby` and `aria-invalid`,
    and item 12 routes them. The label's `for` names the native select's id, so:
    - with JavaScript off, clicking the label focuses the select natively;
    - enhanced, the select forwards that focus to the combobox (the same forwarding as
      item 6).

    The combobox is named by `aria-labelledby` pointing at the Field label's id
    (prerequisite 4), because a `<div role="combobox">` isn't a labelable element for
    `<label for>`. A Select rendered outside a Field is named by the caller's
    `aria: { label: }` or `aria: { labelledby: }`, which go to the combobox.

### Remote search — designed now, built in a later phase

27. **Opt-in by URL.** `search_url: authors_search_path` implies `search: true`. The
    listbox renders inside `<turbo-frame id="<id>-options">`. The frame wraps the whole
    `role="listbox"` element, not the options, so no generic element sits between the
    listbox and its options. The listbox id doesn't change across responses, so
    `aria-controls` stays valid.
28. **Typing drives the frame.** After a debounce, `ui--select` sets the frame's `src` to
    `search_url` with `q=<text>`. Turbo sets `busy` and `aria-busy` on the frame while it
    loads. A newer `src` cancels the in-flight request. Each response re-renders the
    listbox, and `ui--roving-focus`'s `itemTargetConnected` re-normalises it
    (§ Behavior, Primitive C of ui-positioning-and-navigation, "Dynamic items").
29. **The host endpoint is ordinary Rails:**

    ```ruby
    def search
      authors = Author.where("name ILIKE ?", "%#{Author.sanitize_sql_like(params[:q].to_s)}%").order(:name).limit(20)
      render Ui::Select::ListboxComponent.new(id: "post_author_id", collection: authors,
                                              value_method: :id, text_method: :name), layout: false
    end
    ```

    `Ui::Select::ListboxComponent` is the same part v1 renders internally, and it wraps
    itself in the matching `turbo_frame_tag`.
30. **Choosing a remote option that the native select doesn't contain** appends one
    `<option>` with that value and text, selects it, and then follows item 3. The
    initial render still includes the currently selected option, so a `422` re-render and
    the no-JS state both show it.
31. **The same endpoint serves dependent selects** (country → region), by streaming a
    `replace` of the dependent Select, which v1 already supports (item 33). Remote search
    adds no second path for it.

### Turbo

These follow the primitives' Turbo-cache contract (§ Behavior, item 19 of
ui-presence-and-overlay-stack).

32. **Page cache.** On `turbo:before-cache`, `connect` and `disconnect`, `ui--select`
    returns to its resting state, with no animation:
    - the popup is closed (the overlay already does this);
    - the filter is cleared and every option unhidden;
    - `activeId` is empty;
    - in search mode, the text field shows the selected label.

    The selected value is not reset: it lives in the native select, and Turbo's snapshot
    carries a select's selectedness. So Back restores a closed Select showing the value
    the user left, and focus is not pulled into it.
33. **Options change by re-rendering the component.** A Turbo Stream `replace` or
    `update` targets the Select's root, or the Field around it. The new element connects
    fresh and derives its state from its own select. A stream that patches `<option>`s or
    listbox options on their own is unsupported, and the guide says so. It would desync
    the two renderings that item 11 keeps equal. The one exception is remote search's
    frame (item 27), which replaces the listbox, never the select.
34. **Frame swaps and `422` re-renders.** A Select inside a swapped frame disconnects,
    releasing every listener, and the new one connects from its markup. A `422` that
    re-renders the Field shows the submitted value as selected and the server's error
    through Field.
35. **Morphing page refresh.** `ui--select` re-renders from its select on
    `turbo:morph-element` for its root, so a morph that changes the select's selectedness
    never leaves the combobox showing a stale label.

### Supersedes Dropdown's listbox kind

36. **Dropdown's `kind: :listbox` is removed**, in the same release as Select, on the
    decider's confirmation that no live consumer renders it. It had no selection model
    and moved real DOM focus onto `[role="option"]` elements, the one focus model a
    listbox must never use. The removal is in the same CHANGELOG release as Select
    (`ui-component-library` § Business rules, rule 10). Dropdown keeps `:menu` and
    `:dialog`. A caller who wants a value picker uses Select.

## Business rules

Inherits every rule in `ui-component-library` § Business rules unmodified. The parent's
numbering is referenced as-is; the rules below are scope-local.

**Must**

1. **The native `<select>` is the only place the value lives.** No JavaScript variable,
   data attribute or hidden input holds the value. Every visible state is re-derived
   from the select, in one render path (§ Behavior, items 1 and 3). This is what keeps
   submission, `required`, reset, the no-JS state and Rails' conventions intact, and
   it's why none of them needs its own implementation.
2. **It remains a form control in every respect a native select is one.** It posts its
   value, blocks submission when `required`, restores on reset, excludes itself when
   `disabled`, dispatches `input` and `change` on user choice, and works with
   JavaScript off. A change that breaks any of these is a regression, whatever else it
   adds.
3. **Rails' semantics, not new ones.** Option sources, `selected:`, `include_blank:`,
   `prompt:`, `required:`'s implicit blank and enum labelling behave exactly as Rails'
   helpers do. The native options are rendered by those helpers
   (§ Behavior, items 8–11; `ui-component-library` § Business rules, rule 8).
4. **One APG pattern per mode, never blended.** `search: false` is the select-only
   combobox; `search: true` is the editable combobox with list autocomplete. Each
   follows its w3.org example's key table as recorded in § Behavior, items 16 and 17. A
   key that behaves differently from that table is a defect, unless a correction
   records why.
5. **DOM focus stays on the combobox.** No option, popup or group is ever focused.
   Visual focus is `aria-activedescendant` plus the primitive's `active` class
   (§ Business rules of ui-positioning-and-navigation, rule 4).
6. **Composes the primitives; reimplements none** (`ui-component-library` § Business
   rules, rule 4).
   - Positioning is `ui--anchor`'s, placement and dismissal `ui--overlay`'s, exit
     animation `ui--presence`'s, and navigation and typeahead `ui--roving-focus`'s.
   - `ui--select` registers no `document`-level `keydown` or `click` listener, and
     imports no primitive module.
   - Where a primitive lacks something Select needs, the primitive gains it under its
     own spec (§ Assumptions). Select never works around the gap.
7. **The listbox is never the source of options.** Options change by re-rendering the
   component; remote search's frame replaces only the listbox, and the chosen option is
   written into the select (§ Behavior, items 30 and 33).
8. **Accessibility is definition-of-done** (`ui-component-library` § Business rules,
   rule 6). Both modes pass `assert_accessible` closed, open, filtered, empty and
   invalid, in light and dark mode. The combobox, option text, the active option's
   indicator and the focus ring meet WCAG contrast on their token surfaces.
9. **Nested behaves as standalone** (`ui-component-library` § Business rules, rule 7).
   Select inside a Modal is a required system test.
10. **Select is the kit's only listbox.** Dropdown's `kind: :listbox` is removed in this
    scope's build (§ Behavior, item 36).

**Should**

11. **Local first.** Remote search ships in a later phase, behind `search_url:`, with no
    change to the v1 API (§ Behavior, items 27–31).
12. **Every user-facing string goes through i18n.** "No results", the result count and
    the show-options button's name come from `rails_ui_kit.select.*`. The prompt comes
    from Rails' own `helpers.select.prompt`.

**May**

13. A host may change the value from its own code by setting `select.value` and
    dispatching `change` (§ Behavior, item 4). That is the supported programmatic API;
    there is no second one.

## Assumptions

Inherits `ui-component-library` § Assumptions, and the primitives' assumptions in
ui-positioning-and-navigation and ui-presence-and-overlay-stack.

- **Four primitive prerequisites land before Select's controller.** Each was checked
  against the shipped source on 2026-09-13. Each is a small, backwards-compatible
  addition made under its owning spec, not a Select-local workaround (rule 6).
  1. **`ui--overlay` can open a `layer` without moving focus.** `moveFocusIn()` always
     focuses the `initialFocus` match, an `[autofocus]` descendant or the content
     itself, and `keepFocusInside()` calls it again when focus lands on `<body>`. A
     combobox must keep DOM focus on its input (rule 5). Needed: a value that opens with
     no focus move and no refocus, leaving focus restore untouched.
  2. **`ui--overlay` respects an existing `aria-controls`.** `prepareContent()`
     overwrites the trigger's `aria-controls` with the content target's id. For a
     combobox, that has to name the listbox inside the popup, not the popup wrapper,
     which also holds the empty state and status region. Needed: leave `aria-controls`
     alone when the trigger already has one.
  3. **`ui--roving-focus` handles `PageUp` and `PageDown`.** The select-only APG
     example requires a 10-option jump, and the primitive has no page keys. Adding them
     to Select would be a second navigation implementation. Needed: a page-step value
     (0, unhandled, by default) under the same `skipDisabled` and `loop` rules.
  4. **`Ui::FieldComponent`'s label has an id** (`"#{control_id}-label"`). A
     `<div role="combobox">` can't be named by `<label for>`, so it needs
     `aria-labelledby`. Field's label renders `for=` but no id today.

  **At a contradiction** — a prerequisite that can't be added without changing a
  primitive's existing behaviour or public API — escalate to the decider rather than
  working around it in `ui--select`.
- **The browser keeps its validation bubble on a select laid over the combobox, and
  focus forwarding doesn't dismiss it.** This is unverified (§ Behavior, item 6). Verify
  it in Chrome, Safari and Firefox at build time. **At a contradiction**, `ui--select`
  calls `preventDefault()` on the select's `invalid` event, focuses the combobox, and
  renders `validationMessage` into a message element named in the combobox's
  `aria-describedby`. The select still blocks submission either way. Record it as a
  correction.
- **Turbo's snapshot preserves a select's selectedness, and a newer frame `src` cancels
  the in-flight request.** Both are believed true of `turbo-rails` 2.0.23 (Turbo 8), and
  neither has been observed here. The first underwrites § Behavior, item 32; the second
  underwrites remote search. **At a contradiction**, § Behavior, item 32 re-derives from
  the value last committed. Record it rather than adding a second value store.
- **`human_attribute_name("status.pending")` resolves
  `activerecord.attributes.order/status.pending`, and falls back to the humanised key.**
  This is Rails' nested-attribute lookup. If a supported Rails version differs, follow
  what it actually does and record a correction. Don't add a kit-specific enum
  translation scope.
- **The kit's locale file is present.** `config/locales/rails_ui_kit.en.yml` is being
  introduced alongside this scope. Select adds its `select` keys there. If it hasn't
  landed at build time, escalate rather than hardcoding English.
- **No live consumer renders `Ui::DropdownComponent` with `kind: :listbox`.** The kind
  shipped on `main`, but the decider confirmed no consumer outside this repository uses
  it, so it is removed outright in this scope's build rather than deprecated for a
  release (§ Behavior, item 36).
- **Customizable select (`appearance: base-select`) is not cross-browser.** It was
  Chromium-first at shaping time, and it offers no search either way. It's recorded as a
  future replacement to watch for select-only mode, and nothing here depends on it.
  Re-check support at build time; it doesn't change this scope.
- **The browser lane can run JavaScript-disabled.** The no-JS check subclasses
  `ApplicationSystemTestCase` with `driven_by :rack_test`, which posts forms without a
  browser. If the base class can't be re-driven per test class, escalate to
  `ui-test-harness` rather than dropping the check.
- **Local filtering stays fast enough up to a few hundred options.** Past that, the
  guide points to remote search. Measure a 500-option filter keystroke in the docs app at
  build time.

## Critical files

- `app/components/ui/select_component.rb`, `select_component.html.erb`,
  `app/components/ui/select/` (new) — the component, its option normaliser and
  `Ui::Select::ListboxComponent`.
- `app/javascript/rails_ui_kit/controllers/select_controller.js` (new) — `ui--select`:
  the submission mirror, the mode key tables, filtering, empty state and the Turbo
  resting state.
- `app/javascript/rails_ui_kit/index.js` — registers `ui--select`.
- `app/javascript/rails_ui_kit/controllers/overlay_controller.js` — prerequisites 1 and
  2 (`moveFocusIn`, `keepFocusInside`, `prepareContent`).
- `app/javascript/rails_ui_kit/controllers/roving_focus_controller.js` — prerequisite 3
  (page keys). Read its `activedescendant` model and editable carve-out before writing
  any key handling in `ui--select`.
- `app/javascript/rails_ui_kit/controllers/anchor_controller.js` — read only;
  `matchWidth` and `strategy: "fixed"`.
- `app/components/ui/field_component.rb`, `app/components/ui/field/control_component.rb`
  — prerequisite 4, and the attribute hand-off § Behavior, item 12 routes.
- `app/components/ui/dropdown_component.rb`, `dropdown_controller.js` — remove
  `kind: :listbox` (§ Behavior, item 36).
- `app/components/ui/native_select_component.rb` — being deleted. Its token classes are
  the starting point for the unenhanced select's styling (§ Behavior, item 2).
- `config/locales/rails_ui_kit.en.yml` — gains `rails_ui_kit.select.*`.
- `examples/config/initializers/docs_pages.rb`, `examples/app/views/docs/` — a Select
  page with both modes, every option source, a Field with a real `422`, a Select in a
  Modal, and a Turbo Stream replace.
- `test/application_system_test_case.rb` — `assert_accessible`, `each_token_surface`,
  `contrast_ratio`; every system check below inherits it.
- `CHANGELOG.md` — Select, and the removal of Dropdown's `kind: :listbox`.

## Acceptance checks

### agent-loopable

- Each option source (collection, array, hash, enum, grouped) renders a native select identical to Rails' `collection_select`, `select` or `grouped_collection_select` output for the same arguments, including `selected:`, `include_blank:`, `prompt:`, `disabled_values:` and `required:`'s implicit blank — run: `bundle exec rake test TEST=test/components/ui/select_component_test.rb`
- The listbox's option value, text, disabled and selected sequence equals the native select's for every source, and enum labels resolve through `human_attribute_name` with a humanised fallback — run: `bundle exec rake test TEST=test/components/ui/select_options_test.rb`
- Choosing an option by keyboard and by pointer posts its value with the form, dispatches `input` and `change` from the native select, and a `422` re-render shows the submitted value still selected — run: `bundle exec rake test:system TEST=test/system/select_form_submission_test.rb`
- A `required` Select left blank blocks submission with no request sent and focus on the combobox; a server-side error re-rendered through Field puts `aria-invalid` and an `aria-describedby` naming the error on the combobox — run: `bundle exec rake test:system TEST=test/system/select_validation_test.rb`
- Form reset restores the default selection in both the native select and the combobox's label, and a disabled Select neither opens nor submits — run: `bundle exec rake test:system TEST=test/system/select_form_reset_test.rb`
- Every key in the select-only table (§ Behavior, item 16), driven with real keypresses, produces its result, with `aria-expanded`, `aria-activedescendant` and `aria-selected` correct after each and `document.activeElement` always the combobox — run: `bundle exec rake test:system TEST=test/system/select_keyboard_test.rb`
- Every key in the search table (§ Behavior, item 17) produces its result; typing filters case- and diacritic-insensitively, hides emptied groups, clears `aria-activedescendant`, shows and announces the empty state, commits on close as specified, and DOM focus never leaves the input — run: `bundle exec rake test:system TEST=test/system/select_search_test.rb`
- Clicking the Field label focuses the combobox, clicking an option selects it without moving DOM focus off the combobox, and a disabled option is reachable but never selected — run: `bundle exec rake test:system TEST=test/system/select_pointer_test.rb`
- With JavaScript disabled the native select is visible, labelled by the Field label, and posts the chosen value — run: `bundle exec rake test:system TEST=test/system/select_no_javascript_test.rb`
- A Select inside a Modal opens above the dialog unclipped; the first Escape closes only the listbox and the second closes the Modal — run: `bundle exec rake test:system TEST=test/system/select_in_modal_test.rb`
- Back to a page cached with a Select open restores it closed, unfiltered, showing the value the user left and without pulling focus in — run: `bundle exec rake test:system TEST=test/system/select_turbo_cache_test.rb`
- A Turbo Stream replacing a Select, a frame swap containing one, and a morphing refresh that changes its selection each leave a working Select showing the select's current value — run: `bundle exec rake test:system TEST=test/system/select_turbo_stream_test.rb`
- Both modes pass `assert_accessible` closed, open, filtered, empty and invalid, in light and dark mode, and the combobox text, option text, active indicator and focus ring meet contrast on their surfaces — run: `bundle exec rake test:system TEST=test/system/select_accessibility_test.rb`
- `registerControllers` registers `ui--select` — run: `bundle exec rake test TEST=test/javascript/register_controllers_test.rb`
- `kind: :listbox` is no longer a recognised Dropdown kind: passing it falls back to `:menu` rather than raising — run: `bundle exec rake test TEST=test/components/ui/dropdown_component_test.rb`

### judgeable

- The native select is the only value store: no controller field, data attribute or hidden input holds the value, and every visible state derives from the select in one render path — judged against § Business rules, rules 1 and 2.
- `ui--select` contains no positioning, dismissal, focus-restore, presence or arrow-key navigation of its own, and no `document`-level listener, per rule 4 in the § Business rules section of ui-component-library and rule 6 of this spec's § Business rules.
- The component's API reads like `collection_select` and `select` to a Rails developer, with no option, keyword or default that means something different from its Rails namesake — judged against § Behavior, items 8–11, and § Business rules, rule 3.
- The remote-search design in § Behavior, items 27–31, can be built on the v1 component without changing its public API or the submission model, per § Business rules, rule 11.

### human-gate

- Jonathan uses both modes with a keyboard and with VoiceOver in Safari, and judges that each reads as a select a person would trust with a form.
- Jonathan loads the Select docs page on a throttled connection and accepts the native-to-enhanced swap as invisible, or rules otherwise.
- Jonathan uses select-only mode on a phone and confirms or overturns the coarse-pointer decision in `open-questions.md`.

## Out of scope / deferred

- **Remote search** — designed in § Behavior, items 27–31; built in a later phase of
  this scope's line, after v1 ships.
- **Multiple selection** — a different ARIA pattern and submission shape; its own scope
  if a client product needs it.
- **Creatable options** — makes the control free text; declined.
- **`form.ui_select`**: not planned. A form builder is deferred by decision, as a Rails
  primitive override (§ Behavior, item 14; `ui-field-model-binding` § Out of scope /
  deferred).
- **A Capybara helper for host system tests** — see `open-questions.md`.
- **Virtualised listboxes** — large collections use remote search.
- **Inline autocomplete** (`aria-autocomplete="both"`) — APG's third variant; no
  consuming need.
- **RTL arrow mapping** — deferred with `ui--roving-focus`'s own deferral.
- **Customizable `<select>`** — a future replacement for select-only mode to watch once
  it is cross-browser; see § Assumptions.
