---
slug: ui-field-model-binding
type: feature
status: building
decider: Jonathan Simmons
blast_radius: medium
size: large
target_model: frontier
created: 2026-09-14
loop_budget: 5
---

## Intent

`Ui::FieldComponent` shipped in v0.3.0 as wiring: the caller hands it an HTML `name`
and an array of error messages, and it derives every id and the ARIA that joins a
label, a control, a description and an error. It knows nothing about the record behind
the form. So every call site retypes what the record already knows:

```erb
<%= render Ui::FieldComponent.new(name: "user[email]", errors: @user.errors[:email]) do |field| %>
  <% field.with_label { "Email" } %>
  <% field.with_control(Ui::InputComponent, value: @user.email, required: true) %>
<% end %>
```

That's five copies of one fact. Any of them can drift. `required: true` is the one that
does real harm when it drifts, because nothing checks it against the model.

This scope lets Field take the record instead:

```erb
<%= render Ui::FieldComponent.new(model: @user, attribute: :email) %>
```

From the record it works out the HTML name Rails' own helpers would emit, the control
id, the error messages, the label text, and whether the attribute is required. The
last one comes from asking the model's validators.

**Why this is Gate 1, not sugar.** Deriving a name is convenience. Deriving `required`
from `validators_on` is Field owning a Rails concept, the model's validation contract,
and carrying it into the browser. That is the exact example `ui-component-library`
§ Business rules, rule 0 gives for Gate 1. It is also the risky part. A validator
that can't be evaluated without an instance and a context has to be left out, not
guessed at. This spec is shaped around that honesty (§ Behavior, items 9–12).

**Appetite.** One component, extended and not replaced. The model-bound constructor.
Name, id, label and error derivation. Required detection and its accessibility layer.
Taking the existing Select `422` round trip onto a real ActiveModel object. One small
prerequisite on Select. The help text swapping to the error, animated where a morph
keeps the old field (§ Behavior, items 19–23). No form builder (§ Out of scope / deferred).

## Goal

`Ui::FieldComponent.new(model:, attribute:)` renders a name and id identical to
`form_with(model:)` for the same record, the model's error messages, a label matching
`form.label`, and `required` on the control and a hidden-from-assistive-technology
marker on the label exactly when the attribute has an unconditional presence validator.
The v0.3.0 `name:`/`errors:` form renders unchanged apart from the swap: an invalid
field's help text gives way to its error, and it animates, and the error is announced,
when a morph delivers the change. The Select docs page's `422`
round trip passes its existing browser tests with its errors, value and `required`
coming from an ActiveModel object.

## Non-goals

- **Not a form builder.** No `form.ui_field`, no `FormBuilder` subclass, no method added
  to any Rails class. See § Out of scope / deferred for why this is a deferred
  architectural decision and not a gap.
- **Not client-side validation.** The only constraint Field puts in the browser is
  native `required`. It emits no `pattern`, `minlength`, `maxlength`, `min` or `max`
  from length, format or numericality validators, and ships no validation JavaScript.
  The only script is the help-text swap's animation (§ Behavior, item 22), which
  validates nothing.
- **Not a complete mirror of the model's validations.** Required detection deliberately
  under-reports (§ Business rules, rule 2). The server stays the authority and the
  `422` re-render stays the path for everything the browser doesn't catch.
- **Not nested-attribute name derivation.** Field doesn't build
  `post[comments_attributes][0][body]` from a parent, an association and an index. It
  renders one when given that name explicitly (§ Behavior, item 5).
- **Not input-type inference.** `attribute: :email` does not make `type="email"`, just
  as `form.text_field :email` does not. The caller picks the control and its type.
- **Not an ActiveRecord integration.** No ActiveRecord constant, association reflection,
  column metadata or database constraint is read (§ Business rules, rule 4).
- **Not a change to the v0.3.0 API.** `name:`, `errors:` and `control_id:` keep their
  meaning and their output, apart from the hidden description on an invalid field
  (§ Business rules, rule 1, and its amendment).

## Behavior

### The API

1. **Two constructors, one component.**

   ```ruby
   # v0.3.0, unchanged
   Ui::FieldComponent.new(name: "user[email]", errors: @user.errors[:email])

   # Model-bound: name, id, errors, label text, required and value derived
   Ui::FieldComponent.new(model: @user, attribute: :email)

   # Any derived value can be stated instead
   Ui::FieldComponent.new(model: @user, attribute: :nickname, required: true)
   Ui::FieldComponent.new(model: @post, attribute: :author_id,
                          errors: @post.errors[:author_id] + @post.errors[:author])
   Ui::FieldComponent.new(model: comment, attribute: :body,
                          name: "post[comments_attributes][0][body]")
   ```

   `required:` is new and available to both constructors (`true`, `false`, or omitted).
   The name form previously had no field-level way to say it, so a caller who passed
   `required: true` to `with_control` got a required control under a label that didn't
   show it.
2. **One precedence rule: what the caller states beats what the model implies.** For
   each derived value (name, errors, required, label text, value), an explicit keyword
   replaces the derived value. The model fills in only what the caller didn't say. There
   are no per-value exceptions, and nothing is merged: `errors: []` shows no errors even
   when the model has some.

   **Decided** (the orchestrator's ruling of 2026-09-14, relaying the decider): explicit
   wins, and nothing raises when both are given. Three real, common cases need both at
   once. Nested attributes need an explicit name (item 5). `belongs_to` puts its error on the association rather than the foreign key
   (item 13). And conditional validators need an explicit `required:` (item 11). Raising
   would force those callers back to the name form and lose every other derivation.
   Resolved values can't disagree with each other. The control id always comes from the
   resolved name, as it does today, unless `control_id:` is given. `required` is a
   single resolved value that the label, the wrapper and the control all read (item 14).
3. **What raises.** Each of these raises `ArgumentError` at construction, with a message
   naming the fix:
   - neither `name:` nor `model:` given;
   - `model:` without `attribute:`, or `attribute:` without `model:`;
   - `model:` doesn't respond to `to_model`. That covers `nil`, a symbol
     (`model: :user`, which is `form_with(scope:)`'s job; the message points to
     `name:`), a string, a hash, and a model *class*. A class isn't a record: it has no
     errors and no value. Rails' `ActiveModel::Conversion#to_model` is an instance
     method, so a class fails the check with no special case. This was verified in the
     bundle;
   - the object `to_model` returns doesn't respond to `model_name` and `errors`
     (§ Business rules, rule 4, the duck type);
   - `attribute:` contains `[`, `]` or `.`, which is an attempt at a nested path
     (item 5), or ends in `?`. Rails strips a trailing `?` for the name but
     `field_name` doesn't (verified, § Assumptions). Rather than reproduce that
     asymmetry, Field asks for the attribute name.

   `model: nil` raises rather than rendering a nameless field. A nil record at render
   time is a controller bug, and a silent empty field hides it.

### Name and id

4. **The name and id are `form_with(model:)`'s, exactly.** The name is Rails' public
   `field_name` helper applied to the model's `model_name.param_key` and the attribute.
   The id is derived from that name by Field's existing derivation, which produces what
   `field_id` produces for every case below. Verified against `actionview` 8.1.3.1 by
   rendering `form_with(model:)` in this repository's bundle on 2026-09-14:

   | Record | `form_with` name | `form_with` id |
   |---|---|---|
   | `User` | `user[email]` | `user_email` |
   | `Admin::User` (plain module namespace) | `admin_user[email]` | `admin_user_email` |
   | custom `model_name` (`ActiveModel::Name.new(self, nil, "Person")`) | `person[email]` | `person_email` |
   | `Blog::Post` under an isolated engine namespace | `post[title]` | `post_title` |

   **The trap in the last row.** `field_id` accepts a model object directly, but when
   given one it uses `model_name.singular` (`blog_post`), not `param_key` (`post`). So
   `field_id(record, :title)` returns `blog_post_title` while `form_with` emits
   `post_title`. Derivation always goes through the `param_key` string and never hands
   the record to `field_id`. The obvious call is the wrong one, and a unit test pins it.
5. **Included and excluded naming cases.**

   | Case | Supported? | How |
   |---|---|---|
   | Plain, namespaced, custom-named and engine-isolated ActiveModel records | derived | item 4 |
   | Nested attributes (`post[comments_attributes][0][body]`) | explicit only | `model:` is the nested record and `name:` is the full name. Errors, required and label come from the nested record; the id derives from the name (`post_comments_attributes_0_body`, identical to `fields_for`, verified). |
   | `form_with(scope:)` renaming the object (`account[email]`) | explicit only | `name: "account[email]"` |
   | `form_with(namespace:)` prefixing ids (`ns_user_email`) | explicit only | `control_id:`. Field can't see the surrounding form's options, and without a builder there is nothing to read them from. |
   | `index:` / `multiple:` names (`user[0][email]`, `user[tags][]`) | explicit only | `name:` |
   | A plain symbol, class, hash or `nil` as `model:` | excluded | raises (item 3) |
   | An attribute path (`"address.city"`, `"comments_attributes][0][body"`) | excluded | raises (item 3) |

   "Explicit only" means the model-bound constructor still works. Only the name, or id,
   is stated rather than derived.

### Label

6. **Label text matches `form.label`.** When the caller doesn't supply label content,
   the text is resolved in the order `form.label` uses for the same record (verified in
   `ActionView::Helpers::Tags::Label` and `Tags::Translator`, 8.1.3.1):
   1. `helpers.label.<param_key>.<attribute>`;
   2. `helpers.label.<i18n_key>.<attribute>`;
   3. the model class's `human_attribute_name(attribute)`, which covers
      `activemodel.attributes.*` and `activerecord.attributes.*`;
   4. `attribute.to_s.humanize`, when the class has no `human_attribute_name`.

   Verified that a `helpers.label.user.nick` translation changes `form.label`'s text
   ("Handle") while `human_attribute_name` alone still returns "Nick", so step 1 isn't
   optional. `Tags::Translator` is `:nodoc:`, so Field implements the documented order
   rather than calling it. A unit test holds Field's text equal to `form.label`'s for all
   four steps, so a Rails change shows up as a red test.

   **A documented divergence.** For a nested record given an explicit `name:`,
   `form.label` inside `fields_for` looks up `helpers.label.post.comments.body`, and
   Field looks up `helpers.label.comment.body`. Steps 3 and 4 agree. Field doesn't parse
   names back into object paths.
7. **The label renders without being asked.** With `model:`, a Field whose caller
   doesn't call `with_label` renders a label with the derived text. `with_label` with a
   block replaces the text. `with_label(class: …)` with no block keeps the derived text
   and applies the attributes. The name form is unchanged: no label unless the caller
   sets one.
8. **The control renders without being asked.** With `model:`, a Field with no
   `with_control` renders `Ui::InputComponent` with its default `type`, so the one-line
   form in § Intent is a complete field. The name form is unchanged.

### Required detection

9. **The rule.** A derived `required` is true exactly when
   `to_model.class.validators_on(attribute)` includes a validator that meets both
   conditions:
   - its `kind` is `:presence`;
   - its `options` have no key other than `:message` and `:strict`.

   Any `if:`, `unless:`, `on:`, `allow_nil:` or `allow_blank:` rules it out, and so does
   any option key the kit doesn't recognise. The rule reads `kind`, not a constant, so
   ActiveModel's and ActiveRecord's presence validators both qualify and no ActiveRecord
   constant is named. If the class doesn't respond to `validators_on`, the derived value
   is false.
10. **The trade-off, stated.** A field wrongly marked required is worse than one wrongly
    left unmarked.
    - **Wrongly required:** the browser blocks a submission the model would have
      accepted. No request is made, so the server logs nothing, no test sees it, and the
      user is stuck with a message saying the field is required when it isn't.
    - **Wrongly not required:** the user submits, the server runs the validation it
      always runs, and the `422` re-render shows the error through Field (items 13 and
      18). That costs one round trip, and every Rails form already handles it.

    The asymmetry decides every ambiguous case toward *not required*. Coverage is
    traded for never being wrong in the harmful direction. The one exception is
    item 12.
11. **What it deliberately misses.** None of these mark a field required. A caller who
    knows better passes `required: true`.

    | Validation | Why it isn't read |
    |---|---|
    | `presence: true, if:` / `unless:` | Needs an instance and runs arbitrary code; the record at render time may not be the record at submit time. |
    | `presence: true, on: :create` / `on: :update` / a custom context | Needs the validation context, which a form doesn't declare. Includes `has_secure_password`'s `password` presence (`on: :create`). |
    | `presence: { allow_nil: true }` / `allow_blank:` | The option weakens or cancels presence. Seen in the bundle: `options` carries `allow_nil: true`. |
    | `length: { minimum: }`, `numericality`, `inclusion`, `format`, `comparison` | Rejecting blank is a side effect that depends on the option set (`allow_nil`, `allow_blank`, `in:` containing `""`). Reading it would be guessing. |
    | `acceptance` | Its options default to `allow_nil: true` (verified), and a checkbox isn't a supported control here. |
    | `belongs_to` (ActiveRecord) | The presence validator is on the association (`:author`), not the foreign key a field renders (`:author_id`). Under Rails ≥ 7.1 defaults (`belongs_to_required_validates_foreign_key = false`) it also carries an `if:` lambda. Verified in `activerecord` 8.1.3.1 `Builder::BelongsTo.define_validations`. Doubly out. |
    | `validate :custom_method`, custom `EachValidator`s, `validates_with` | Opaque. |
    | Database `NOT NULL` | Not ActiveModel; rule 4. |

12. **What it can still get wrong, and the escape hatch.** An unconditional presence
    validator is necessary for the model to reject a blank, but it doesn't prove the
    *control* is where the value comes from. If the attribute is filled by a
    `before_validation` callback, assigned in the controller from something other than
    this field, or given a value by a default the user can clear, Field marks it
    required and the browser blocks a submission the model would accept. That is the
    harmful direction, and it is the rule's one known false positive. It is accepted
    because it can only arise when the form renders a control for a value the server
    doesn't take from that control, which is a design smell in the host's form. The
    documented fix is `required: false`, and the Field docs page shows it.

### Errors

13. **Errors from the model.** With `model:`, errors are `to_model.errors[attribute]`:
    the message strings, rendered as today (`to_sentence`, one error element). That is
    the key Rails' own `error_wrapping` reads (`object.errors[@method_name]`), so Field
    shows what `form.text_field` would treat as errored, no more and no less. It
    inherits Rails' `belongs_to` blind spot: an error on `:author` doesn't show on an
    `:author_id` field. The documented fix is the explicit `errors:` in item 1.

### Required in the accessibility layer

14. **One resolved `required`, three places, always in agreement.** `required` resolves
    in this order:
    1. a `required:` passed to `with_control`;
    2. the Field's `required:`;
    3. derivation (item 9).

    That single value drives all three places below. The label, the wrapper and the
    control can't disagree, whatever order the caller sets parts in, and whichever
    source supplied the value.
    - **The control** gets native `required`, through the same control-attribute
      hand-off that carries `aria-invalid` today. `aria-required` isn't added to a
      native `input`, `select` or `textarea`: native `required` already exposes the
      required state to the accessibility API.
    - **The wrapper** gets `data-required="true"`, mirroring `data-invalid`, so a host
      styles from the wrapper and not from DOM structure.
    - **The label** gets a trailing marker,
      `<span aria-hidden="true" data-slot="field-required-indicator">*</span>`. It's
      `aria-hidden`, so it is excluded from the label's text and from the control's
      computed accessible name. The name stays "Email", not "Email star" or
      "Email asterisk", and the "required" a screen reader speaks comes from the
      control's state. The marker is real markup, not CSS `content`: generated content
      *is* part of accessible-name computation, and the alt-text syntax for it isn't
      verified across the browsers the kit supports. Its colour comes from a token and
      meets 4.5:1 on every token surface in both modes.
15. **A non-native control carries it too.** Select's enhanced combobox is a
    `div role="combobox"` or `input role="combobox"`, not the native select, so native
    `required` never reaches it. It gets `aria-required="true"` whenever its native
    select is `required`. That is prerequisite 1 in § Assumptions. It lands under
    `ui-select`'s spec, and it closes a gap that already exists for a Select given
    `required: true` directly.

### Value

16. **The control shows the record's value.** **Decided** (the orchestrator's ruling of
    2026-09-14, relaying the decider; `open-questions.md`). Without it, the one-liner
    loses what the user typed on a `422`. That is data loss in the feature pitched as
    Rails-aware, so it isn't optional. With `model:`, Field derives the value
    `form.text_field` would render for the same record and attribute, and a caller-supplied value always wins
    (item 2). It hands that value to the kit's own controls in each one's own shape:
    - `Ui::InputComponent`: `value:`. For `type: "password"` and `type: "file"`, no
      value, matching `password_field` and `file_field`, so a `422` never echoes a
      password into the HTML;
    - `Ui::TextareaComponent`: its content;
    - `Ui::SelectComponent`: `selected:`.

    Any other control receives no derived value. Field knowing the kit's own three
    controls by name is accepted coupling. A custom control receives its value through
    explicit attributes, and the block form can read `field.value`. Without
    this, the one-line form in § Intent renders an empty input on exactly the `422`
    re-render item 17 is about, and the user's typing is lost.

### Rails integration

17. **`field_error_proc` never fires for a Field control.** Rails runs `field_error_proc`
    only inside its `Tags` classes (`ActiveModelInstanceTag#error_wrapping`), which a
    form builder's `text_field` goes through. Verified in the bundle: one
    `field_with_errors` wrapper for an errored `form.text_field`. Field renders its
    controls through ViewComponent and tag helpers, never through `Tags`. So a model with
    errors produces no `div.field_with_errors` even under the default proc, and the
    model-bound form changes nothing there. `data-invalid`, `aria-invalid` and now
    `data-required` keep carrying the state.
18. **The `422` round trip is the existing one, on a real model.** The Select docs page's
    `POST /demos/select` (`docs#select_submit`, `docs/_select_round_trip.html.erb`) stops
    hand-building an errors hash:
    - The action builds an ActiveModel form object, `DemoTrip`, from `params[:trip]`
      and validates it. It keeps the same two failures: `presence` on `city`, and a
      custom `validate` that rejects `tokyo`. It renders `422` when invalid.
    - `DemoTrip` declares `model_name` as `ActiveModel::Name.new(self, nil, "Trip")`, so
      the derived name and id stay `trip[city]` / `trip_city`. The page doubles as the
      custom-`model_name` case from item 4.
    - The partial renders `Ui::FieldComponent.new(model: trip, attribute: :city)`. It
      drops `errors:`, the explicit `required: true` and `selected:`. `required` now
      comes from the presence validator, and `selected` from item 16.

    The existing `select_form_submission`, `select_validation` and
    `select_no_javascript` tests pass against it unmodified. That is the proof that the
    derived name, id, `required`, errors and value are the ones the hand-written version
    produced.

### Help text and the error

Added 2026-09-14 on the orchestrator's directive, relaying the decider: help text is
optional, and when the field becomes invalid the help text swaps to the error message with
animation, and back when it becomes valid. It applies to both constructors, because help
text isn't a model concept.

19. **The error takes the help text's place.** An invalid field renders its description
    with the `hidden` attribute, and the error where the description was. A valid field
    renders the description and no error element. A field with no description shows the
    error, or nothing, as in v0.3.0. This is server-rendered, so it holds with JavaScript
    off and on every render path in item 21. **It supersedes v0.3.0**, where an invalid
    field showed the description *and* the error (§ Business rules, rule 1 is amended to
    match).

    **The description stays in the DOM while hidden.** Three reasons. It has to exist for
    the swap back to animate (item 22). `aria-describedby` still names it (item 20), and
    an id that points at nothing would be a dangling reference. And the help text is
    usually the instruction for fixing the error ("Letters and numbers only"), so taking
    it away from assistive technology at the moment the user needs it would be worse than
    keeping it.
20. **`aria-describedby` is correct in both states, and unchanged from v0.3.0.** Valid:
    the description's id. Invalid: the description's id, then the error's. A hidden
    element that `aria-describedby` references directly is still part of the computed
    description (Accessible Name and Description Computation 1.2, step 2A's exception),
    so a screen reader on an invalid field hears the error and the instruction. The list
    is rendered by the server for each state, so a morph carries the right one to the
    control with no client code. The browser lane holds the computed description, not
    just the attribute.
21. **Where a swap is observable.** Verified 2026-09-14 against `turbo-rails` 2.0.23
    (Turbo 8.0.23) in this repository. "Observed" means driven in the examples app in
    headless Chrome; "read" means read in the bundled `turbo.js`.

    | How the invalid state arrives | Old field DOM kept? | Evidence |
    |---|---|---|
    | Initial page load, or a POST with JavaScript off | no: a new document | — |
    | A Turbo Frame form whose response is a `422` (the docs page's `docs#select_submit` round trip) | **no**: `FrameController#loadResponse` uses `FrameRenderer`, which replaces the frame's children. `MorphingFrameRenderer` is used only by `reload()` on a `src` frame with `refresh="morph"`, never for a form response | observed: only `turbo:before-frame-render` fires, the new field is a different node and the old one is disconnected |
    | A Turbo Stream `replace` or `update` without `method` | no: the target is replaced | read |
    | A Turbo Stream `replace`/`update` with `method="morph"` (`turbo_stream.replace(target, method: :morph)`) | **yes**: `morphElements` keeps matched nodes and changes their attributes and text | observed: same node, attributes changed in place |
    | A Turbo Drive form `422` | only when the page declares `turbo-refresh-method` `morph` **and** `PageView#isPageRefresh` holds (no current visit, or the same path with a `replace` action). A form reached by a Drive `advance` visit re-renders with `PageRenderer`. | read |
    | A morphing page refresh (`turbo_refreshes_with method: :morph`) | yes | read |

    So the swap animates on a morph and only on a morph. Every other path delivers a new
    field, which renders its final state with no animation, exactly as an initial page
    load does. There is no earlier state on the page to animate from, and inventing one
    would animate every Drive navigation too. A host that wants the swap on a form in a
    frame renders it through a morph: a Turbo Stream response with `method: :morph`, or
    `turbo:before-frame-render` setting `event.detail.render` to `Turbo.morphChildren`.
    The Field docs page's swap demo uses the stream response.
22. **The animation is Primitive D, composed by import.** A `ui--field` controller on
    the wrapper imports `rails_ui_kit/overlay/presence`, the module `ui--presence` and
    `ui--overlay` already share, the same way `ui--overlay` composes it (parent rule 4).
    It declares no duration, sets no timer and writes no animation of its own. The
    description and the error fade on `data-state`, through Tailwind classes on the
    parts.
    - **Out, then in.** The outgoing part exits and holds its space until
      `presence.exit` settles. Then the incoming part enters. The two never occupy the
      space together, so the field's height changes once, at the swap, not twice.
    - **Nothing on connect.** The controller only acts on `turbo:morph-element` for its
      own wrapper, after the morph has finished. Initial page load, a frame render and a
      stream replace connect a new controller that animates nothing.
    - **The morph can't undo the animation.** A morph sets every attribute to the
      server's markup, which would remove `data-state`, re-add `hidden` at once and
      delete a leaving error before it had faded. While a Field is morphed, the
      controller cancels `turbo:before-morph-attribute` for `hidden`, `data-state` and a
      removed `role` on its description and error. The wrapper's `data-invalid` is the
      state the server sent, and the controller derives both parts from it. It also
      cancels `turbo:before-morph-element` for the error's removal, runs the error's exit,
      and removes it once the exit settles.
    - **Interruption.** A morph that arrives mid-swap starts a new swap toward the newest
      state. Presence reverses an element in place, and the superseded swap does nothing
      more. A leaving error that the next morph renders again is kept rather than removed.
    - **Reduced motion.** Under `prefers-reduced-motion: reduce`, presence skips the wait
      and doesn't defer the entry to a frame (`presence.js`, `settle` and `enter`), and
      the parts carry `motion-reduce:transition-none`. The swap completes in the task
      that the morph ran in.
    - **Page cache.** On `turbo:before-cache` the field snaps to its resting state for its
      current `data-invalid`, so a snapshot is never cached mid-swap.
    - The wrapper's `data-controller` is joined with a caller's rather than replaced by
      it.
23. **The error is announced when it appears.** On the morph path, the controller gives
    the error `role="alert"` before revealing it. A node with that role entering the
    accessibility tree is announced. The role survives later morphs, so a message that
    changes while the field stays invalid is announced as well. A server-rendered error
    (initial load, a frame render, a stream replace) carries no role, as in v0.3.0,
    because a role on every error on arrival would announce the whole form
    (`Ui::Field::ErrorComponent`). `turbo:before-cache` removes the role, so restoring a
    snapshot announces nothing.

    **The trade-off.** `alert` is assertive. When one response makes several fields
    invalid, each one is announced. That is accepted: the response is the answer to the
    submission the user just made, and a polite region set on an element that has only
    just been inserted isn't reliably announced at all.

    **A correction.** `ErrorComponent`'s comment said a stream could pass `role: "alert"`
    to the error "through attribute forwarding", and the Field docs page said to pass it
    "through the control's forwarded attributes". Field has no path that forwards
    attributes to its error, and `role="alert"` on the control would make the input
    itself an alert. Both are corrected to point at the morph path.

## Business rules

Inherits every rule in `ui-component-library` § Business rules unmodified, and Primitive
E's contract in `ui-positioning-and-navigation` § Behavior. The rules below are
scope-local.

**Must**

1. **The v0.3.0 API is untouched.** `name:`, `errors:` and `control_id:` render what they
   rendered in v0.3.0. Every existing test in `test/components/ui/field_component_test.rb`
   passes without being removed or weakened. The model-bound form is additive and lands
   in `CHANGELOG.md`'s `[Unreleased]` section, not as a breaking change.

   **Amended 2026-09-14 for the help-text swap (§ Behavior, item 19), on the decider's
   request.** One rendered difference is intended: an invalid field's description carries
   `hidden`. Its id, classes, content and place in `aria-describedby` are unchanged. The
   three existing tests that locate the description on an *invalid* field gain
   `visible: :all`, since Capybara skips hidden elements. Their assertions stay
   otherwise as written, and a new test asserts that the description is hidden.
2. **Required detection never guesses.** Only the validators item 9 names mark a field
   required. Adding a validator kind, or reading an option the rule now excludes, is a
   reshape of this spec, not an implementation choice. When the rule and a caller's
   intuition disagree, `required:` is the answer, not a wider rule.
3. **Rails' output, not an approximation of it.** The name, the id, the label text, the
   error key and the value match what `form_with(model:)` and its field helpers render
   for the same record. Each match is held by a test that renders the Rails helper and
   compares, not by a hand-written expected string. The name comes from Rails' public
   `field_name`. Where Rails' own path is `:nodoc:` (label translation, value before
   type cast), Field implements the documented behaviour and the comparison test is
   what keeps it honest.
4. **ActiveModel-shaped at most, never ActiveRecord.** What `model:` requires, after
   `to_model`:
   - `model_name` returning an `ActiveModel::Name`-like object with `param_key` and
     `i18n_key`;
   - `errors` responding to `#[]`, which returns an array of messages for the attribute.

   What is used when present, with a stated fallback when absent:
   - `class.validators_on`: not required;
   - `class.human_attribute_name`: `humanize`;
   - the attribute reader and `<attribute>_before_type_cast`: the reader alone.

   This is `ActiveModel::API`'s shape, and a subset of what `ActiveModel::Lint` asks of a
   form object. No file under `app/components/ui/field*` names `ActiveRecord`, requires
   `active_record`, or reads association reflections or column metadata. Tests use
   `ActiveModel::API` models in `test/support/`, beside `test_order.rb`, with no
   database.
5. **One resolved value per concern** (item 14). The label marker, `data-required` and the
   control's `required` are computed from one value. So are the name and the id (item 2).
   A rendered field in which any two of them disagree is a defect.
6. **The required marker is invisible to assistive technology** (item 14). The control's
   computed accessible name is the label text with no marker glyph. Required state
   reaches assistive technology through the control's own `required` or `aria-required`,
   never through label text.

**Should**

7. **Errors toward not required.** Any case this spec leaves unstated, such as a
   validator shape nobody anticipated, resolves to not required (item 10).
8. **One precedence rule, no exceptions** (item 2). A proposal to merge rather than
   replace one derived value, such as errors, is a reshape.

**May**

9. A host may read `field.required?`, `field.value` and the derived label text in the
   block form, to build a custom control that honours them.

## Assumptions

Inherits `ui-component-library` § Assumptions and Primitive E's in
`ui-positioning-and-navigation`.

- **Rails behaviour verified in the bundle, 2026-09-14, `rails` 8.1.3.1.** Each item was
  observed by rendering real helpers in this repository's bundle, not recalled:
  - `form_with(model:)` names and ids for the four records in item 4;
  - `field_id`'s `model_name.singular` trap;
  - `fields_for` nested name and id;
  - the `namespace:` and `scope:` outputs;
  - `validators_on` options for `if:`, `on:`, `allow_nil:` and `acceptance`;
  - `validator.kind == :presence`;
  - `form.label`'s `helpers.label` precedence over `human_attribute_name`;
  - `field_error_proc` wrapping `form.text_field` once;
  - `field_name("post", :admin?)` returning `post[admin?]`, where `Tags::Base#tag_name`
    strips the `?` first (read in source, not rendered);
  - a model class not responding to `to_model`;
  - `belongs_to`'s association-keyed, conditional presence validator;
  - an `ActiveModel::Attributes` model having no `_before_type_cast` reader, so
    `form.text_field` renders the cast value (`"abc"` for an integer shows `0`).

  **At a contradiction** at build time, follow what the helper actually renders, correct
  the table, and record a correction.
- **The gemspec allows Rails ≥ 7.2 (raised from 7.0 on this branch, `81e2cf9`), and only 8.1.3.1 has been observed.** `field_name` and
  `field_id` have been public since 7.0. Because Field calls `field_name` rather than
  reimplementing it, names track whichever Rails version is running. Label order,
  validator options and the `belongs_to` condition were read from 8.1.3.1 source only,
  and there is no Rails-version matrix in CI. **At a contradiction** reported on an
  older Rails, record it against that version. Don't add version branches without the
  decider's call on whether the floor moves.
- **ViewComponent exposes `field_name` on the component before render.** Verified with
  view_component 4.15.0: `Ui::FieldComponent#field_name` and `#field_id` resolve at
  construction, because `ViewComponent::Base` inherits `ActionView::Base`. So the name
  can be derived in `initialize`, where `control_id` is derived today. **At a
  contradiction** on a supported ViewComponent version, derive at `before_render`
  through `helpers`, and keep every slot lambda that reads `control_id` working.
- **The examples app doesn't load ActiveModel by default.** `examples/config/application.rb`
  required only `action_controller` and `action_view`, and `ActiveModel` wasn't defined
  until required. ~~`DemoTrip` follows `demo_order.rb` and requires `active_model` itself.~~
  **Corrected at build, 2026-09-14:** that stopped working the moment `DemoTrip` produced a
  message. It autoloads during a request, after I18n has loaded its translations, so
  `require 'active_model'` added ActiveModel's `en.yml` to the load path too late, and
  `select_no_javascript` SN4 rendered "Translation missing" in place of "can't be blank".
  The docs app now requires `active_model/railtie`, which loads ActiveModel before I18n
  does. That is ActiveModel only: still no `active_record/railtie` and no database, so
  the escalation this assumption named doesn't apply.
- **WebDriver's computed label is available in the browser lane.** Rule 6's check reads
  the control's accessible name through Selenium's `Element#accessible_name`, which is
  chromedriver's Get Computed Label. **At a contradiction**, read it from CDP
  `Accessibility.getPartialAXTree` instead. Don't fall back to asserting markup alone,
  which would miss the case the rule exists for.
- **Primitive E's install-generator `field_error_proc` step was never built, and it is
  deferred.** `ui-positioning-and-navigation` specified that the install generator writes
  an identity proc. `lib/generators/rails_ui_kit/install/install_generator.rb` never
  contained one. Primitive E is corrected to say so, and the step is deferred with the
  form builder (§ Out of scope / deferred). Nothing here depends on it, because item 17
  holds without it.

## Critical files

- `app/components/ui/field_component.rb`, `field_component.html.erb`: the constructor,
  derivation, the resolved `required`, the default label and control.
- `app/components/ui/field/model_binding.rb`: everything read from the record (items 4,
  6, 9, 13 and 16), kept out of the component so it stays under `Metrics/ClassLength`.
- `app/components/ui/field/label_component.rb`: defers the label to render time, as
  `ControlComponent` does for the control, so the marker follows a `required:` given to
  `with_control` after the label is set.
- `app/components/ui/field/control_component.rb`: where `required`, and the value per
  control (item 16), join the attribute hand-off at render time.
- `app/components/ui/label_component.rb`: read only; the marker is Field's content in
  the label, not a Label keyword.
- `app/components/ui/select_component.rb`: prerequisite 1, `aria-required` on the combobox.
- `test/components/ui/field_component_test.rb`: the v0.3.0 contract (rule 1).
- `test/support/test_order.rb`: the precedent for ActiveModel test doubles.
- `examples/app/controllers/docs_controller.rb` (`select_submit`),
  `examples/app/views/docs/_select_round_trip.html.erb`,
  `examples/app/models/demo_order.rb` (precedent for `DemoTrip`): the `422` round trip
  (item 18).
- `examples/app/views/docs/field.html.erb`: the model-bound section, the `required: false`
  escape hatch (item 12), and a required preview for the accessibility checks.
- `test/system/select_form_submission_test.rb`, `select_validation_test.rb`,
  `select_no_javascript_test.rb`, `field_test.rb`: browser checks this scope must keep
  green or extends.
- `CHANGELOG.md`: `[Unreleased]`.
- `app/javascript/rails_ui_kit/controllers/field_controller.js` and its registration in
  `index.js`: the swap (§ Behavior, items 22 and 23). `overlay/presence.js`: read only.
- `app/components/ui/field/description_component.rb`, `error_component.rb`: the
  `data-state` fade classes, and the corrected comment.
- `examples/app/views/docs/field.html.erb` and a `POST /demos/field` action that answers
  with a morphing Turbo Stream (`_field_swap_demo.html.erb`, `demo_signup.rb`): the swap's
  demo and its browser tests. `demo_profile.rb`: the required preview and the
  `required: false` escape hatch.
- `examples/config/application.rb`: requires `active_model/railtie` (§ Assumptions, the
  correction).

## Acceptance checks

### agent-loopable

- The derived name and id equal `form_with(model:)`'s rendered output for a plain, a module-namespaced, a custom-`model_name` and an engine-isolated record, where the last proves derivation uses `param_key` rather than `field_id(record, …)`. A nested record given an explicit `name:` gets the id `fields_for` renders — run: `bundle exec rake test TEST=test/components/ui/field_model_naming_test.rb`
- Every case in § Behavior, item 3 raises `ArgumentError`, and an explicit `name:`, `errors:`, `required:` or label block each replaces its derived value while the other derivations still apply — run: `bundle exec rake test TEST=test/components/ui/field_model_precedence_test.rb`
- An unconditional presence validator, with or without `message:` and `strict:`, marks the field required. Every row of § Behavior, item 11's table, plus an unknown option key and a class without `validators_on`, leaves it not required. `required: true` and `required: false` override derivation both ways — run: `bundle exec rake test TEST=test/components/ui/field_model_required_test.rb`
- The control's `required`, the wrapper's `data-required` and the label's `aria-hidden` marker are present together or absent together, for derived, field-level and `with_control`-level `required`, whatever order the parts are set in. The name form with `required: true` behaves the same — run: `bundle exec rake test TEST=test/components/ui/field_model_required_test.rb`
- Label text equals `form.label`'s for a `helpers.label.<param_key>` key, a `helpers.label.<i18n_key>` key, an `activemodel.attributes` key and the humanised fallback. With `model:` and no block, a label and an Input render — run: `bundle exec rake test TEST=test/components/ui/field_model_label_test.rb`
- Errors come from `errors[attribute]`, and a model with errors rendered under a `field_error_proc` that wraps visibly produces no wrapper — run: `bundle exec rake test TEST=test/components/ui/field_model_errors_test.rb`
- The Input's value equals `form.text_field`'s for the same record, password and file Inputs render no value, Textarea gets the value as content and Select as `selected:`, and a caller value wins — run: `bundle exec rake test TEST=test/components/ui/field_model_value_test.rb`
- The v0.3.0 Field tests still pass — run: `bundle exec rake test TEST=test/components/ui/field_component_test.rb`
- No Field file names ActiveRecord — run: `! grep -rn "ActiveRecord\|active_record" app/components/ui/field_component.rb app/components/ui/field_component.html.erb app/components/ui/field/`
- The Select `422` round trip, now bound to `DemoTrip`, passes its existing keyboard, pointer and re-render checks unmodified — run: `bundle exec rake test:system TEST=test/system/select_form_submission_test.rb`
- A required Select left blank still blocks submission with no request sent, now with `required` derived from the presence validator, and its combobox carries `aria-required="true"` — run: `bundle exec rake test:system TEST=test/system/select_validation_test.rb`
- With JavaScript off, the model-bound Select posts, and a blank submission comes back `422` with the model's error on the select — run: `bundle exec rake test:system TEST=test/system/select_no_javascript_test.rb`
- The Field docs page's required preview passes `assert_accessible` in light and dark mode. The control's computed accessible name is exactly the label text with no `*`, and the marker meets 4.5:1 on every token surface in both modes — run: `bundle exec rake test:system TEST=test/system/field_test.rb`
- An invalid field renders its description `hidden` with the error after it, and a valid field renders the description visible with no error, for both constructors. `aria-describedby` is the description's id when valid and the description's then the error's when invalid. The wrapper's `data-controller` includes `ui--field` alongside a caller's own — run: `bundle exec rake test TEST=test/components/ui/field_message_swap_test.rb`
- Over a real `POST /demos/field` round trip answered with a morphing stream, becoming invalid holds the description at `data-state="closing"` while the error stays hidden, then enters the error. Becoming valid holds the error in place until its exit settles, then removes it and enters the description. A second submission mid-swap settles on the newest state. In both states the control's computed description is what item 20 says — run: `SLOW=1 bundle exec rake test:system TEST=test/system/field_swap_test.rb`
- No presence transition runs on initial page load of an invalid field, or when the Select round trip's frame render delivers an invalid field. Under `prefers-reduced-motion: reduce` the swap completes with no `closing` state observable — run: `SLOW=1 bundle exec rake test:system TEST=test/system/field_swap_test.rb`
- A page cached mid-swap and restored by Back shows the field at rest for its current state, with no leaving error and no `closing` part — run: `SLOW=1 bundle exec rake test:system TEST=test/system/field_swap_test.rb`
- An error revealed by a morph has `role="alert"` in the accessibility tree before it's shown, and keeps it across a later morph that changes its message. A server-rendered error has no role — run: `SLOW=1 bundle exec rake test:system TEST=test/system/field_swap_test.rb`
- The unit lane and lint are green — run: `bundle exec rake test && bundle exec rubocop`

### judgeable

- Precedence is one rule applied the same way to every derived value, with no merge and no per-value exception, judged against § Behavior, item 2 and § Business rules, rule 8.
- Required detection reads nothing beyond `kind == :presence` and the permitted option keys, and each ambiguous path resolves to not required, judged against § Behavior, items 9–11 and § Business rules, rules 2 and 7.
- Every Rails-matching claim is held by a test that renders the Rails helper and compares, not by a literal expected string, per § Business rules, rule 3.
- The existing Field tests pass without being edited to accommodate the change, except the `visible: :all` the rule 1 amendment names for the hidden description, and the `select_*` system tests named above are unmodified, per § Business rules, rule 1 and § Behavior, item 18.
- The swap owns no animation mechanism of its own. Every wait goes through `presence.enter`/`presence.exit`, and nothing animates on a path § Behavior, item 21 lists as delivering a new field, per parent rule 4.
- Nothing in the change adds a method to a Rails class, subclasses `FormBuilder`, or registers a builder, per § Out of scope / deferred.

### human-gate

- Jonathan uses the Field docs page's required preview with VoiceOver in Safari and confirms that the field reads as its label plus "required", with no "star" or "asterisk".
- Jonathan accepts the marker's glyph, colour and placement, or rules otherwise.
- Jonathan submits the Field docs page's swap demo with VoiceOver in Safari. He confirms that the error is announced when it appears, and that the swap reads as one change in both directions.

## Out of scope / deferred

- **The form builder (`form.ui_field :email`), and every other Rails primitive override:
  deferred by decision, not by oversight.**
  Every component the kit ships is rendered as a ViewComponent:
  `render Ui::SomethingComponent.new(…)`. A form builder would be the first time the
  kit extends a Rails API rather than supplying a component. It would register a
  `FormBuilder` subclass, or add methods to Rails' own, and hosts would reach the kit
  through `form_with`. That is an architectural direction, and it changes what the kit
  *is*: from a set of components a host renders to a layer that modifies the framework
  a host builds on. It should be chosen deliberately, and it isn't being chosen now,
  before any Rails primitive override exists in the kit to show what that direction
  costs.

  **The same line covers `field_error_proc`.** Having the install generator set
  `ActionView::Base.field_error_proc` in a host app is itself a Rails primitive
  override. It changes how every Rails form helper in the host renders, not just the
  kit's components. Primitive E specified that step and it was never built. On the
  orchestrator's ruling of 2026-09-14, relaying the decider, it is deferred with the
  builder, and `ui-positioning-and-navigation` is corrected to say so. The kit doesn't need it: Field's controls never reach the proc
  (§ Behavior, item 17).

  This scope is shaped so either choice stays open. A future builder is a thin shim
  that calls `Ui::FieldComponent.new(model: object, attribute: method, …)`, supplying
  `name:`/`control_id:` from the builder's `object_name`, `index` and `namespace` where
  they differ from derivation. It needs no change to anything specified here.

  **Cost of reversing either way.**
  - **Adding the builder later** is cheap and additive. It needs a builder class, a
    registration story (the default builder or opt-in `builder:`), and tests. No
    component API changes, because the model-bound constructor already carries every
    derivation.
  - **Removing the builder once shipped** is expensive. Every host form written as
    `form.ui_field` breaks, which is a breaking release under `ui-component-library`
    § Business rules, rule 10, and a mechanical rewrite in every consumer. Once the kit
    patches the framework, hosts start depending on the patch's side effects, such as
    `field_error_proc` interplay and builder option inheritance. A generator-written
    `field_error_proc` has the same shape: once it's in host initializers, removing it
    means every host re-deciding how all its errored fields render.

  The asymmetry is the reason to wait. `ui-select` § Behavior, item 14 now records
  `form.ui_select` as not planned, under this decision. Select binds to a record through
  Field.
- **Animating the swap on a render that replaces the field.** A frame render, a stream
  `replace` without `method: :morph` and a Drive render deliver a new field, with no
  earlier state on the page to animate from (§ Behavior, item 21). Detecting "this
  arrived by a frame, not a page" to animate on connect would be a heuristic that also
  fires on every Drive navigation. A host that wants the swap renders through a morph.
- **Nested-attribute name derivation.** Supported through explicit `name:` (§ Behavior,
  item 5). Deriving it needs the parent form's object name, the association and the
  index, which is builder territory.
- **Client-side constraints from other validators** (`minlength`, `maxlength`, `pattern`,
  `min`, `max`). Each has the same wrong-in-the-harmful-direction risk as `required`,
  with more ways to mistranslate (`allow_blank`, `tokenizer`, Ruby versus JavaScript
  regex). Its own scope, if a client build needs it.
- **Evaluating conditional validators against the instance.** Running `if:` lambdas at
  render time executes host code in a view, against a record whose state at render
  isn't its state at submit. Declined.
- **Checkboxes, radio groups and `multiple` selects bound to a model.** Rails' hidden
  `"0"` input, `checked` derivation and `name[]` are their own control shapes.
- **An "optional" marking convention, or a page-level legend explaining `*`.** How a
  product explains its required marker is page copy, not a field's job. The Field docs
  page shows one approach.
- **Field forwarding its model to Select** (`enum:` from `model:`). Select's `model:`
  takes a class for its enum and Field's takes a record. Joining them is a convenience
  with no pulling need.
