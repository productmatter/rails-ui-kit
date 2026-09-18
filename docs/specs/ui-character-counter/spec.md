---
slug: ui-character-counter
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: low
size: small
target_model: standard
created: 2026-09-18
loop_budget: 4
---

## Intent

A Rails model says `validates :bio, length: { maximum: 500 }`, and the person typing
the bio finds out they were over on submit, from an error. The counter tells them while
they type: the count against the limit, as help text under the field, so they can trim
before they send. The server's validation stays the truth; the counter is the field
saying what the server will say.

It earns its place under `ui-component-library` § Business rules, rule 0, gate 1: it
owns a Rails concept, the length validator, and reads back what that validator will
count. It is shaped as a utility — one small Stimulus controller and an option on
Textarea — and rendered through Field, because "help text" is Field's row.

Decided 2026-09-18 by Jonathan Simmons: the limit is soft (`limit:`, not `maxlength`);
the counter shares the description's line at the inline-end; over the limit the count
turns destructive and nothing else changes; a screen reader hears it only at
thresholds. One consequence follows from "rendered as help text" and is recorded in
§ Behavior, item 3: the counter needs a Field to render in.

## Goal

A Textarea inside a Field, given `counter: true, limit: 500`, shows `12 / 500` at the
end of its help-text line, keeps that count exactly equal to what `validates length:`
will count as the user types, gives the line up to the Field's error whenever the field
is invalid, reads in the destructive colour past the limit, and is announced to a
screen reader only when the remaining room gets tight, when the limit is crossed, and
when the text comes back under it.

## Non-goals

- Enforcing the limit. Nothing stops typing or pasting; `maxlength` stays the caller's.
- Being a validator. The counter never marks the control invalid and never blocks a
  submission.
- Input. Decided for Textarea; Input is deferred until a client build needs it.
- Word or byte counts, or a "remaining" display style.

## Behavior

### The option

1. **`Ui::TextareaComponent.new(counter: true, limit: 500)`.** `counter:` is a boolean,
   default `false`. `limit:` is a positive integer and is required when `counter:` is
   true. Both are component keywords, consumed and never forwarded to the element, the
   way `size:` is (`ui-presentational-components` § Business rules, rule 1). Either one
   without the other raises `ArgumentError` naming the fix, the way Choices treats
   `description_method:` without `collection:`.
2. **`maxlength` is independent.** The kit never sets `maxlength` from `limit:`. If the
   caller sets it, the browser stops input there and the counter simply reflects the
   value. A soft limit lets a person paste, see they are over, and trim, while the
   server decides (decided 2026-09-18).
3. **The counter needs a Field.** Help text is `Ui::FieldComponent`'s row, and Textarea
   is one element by its own spec, with nowhere to render a second part. A Textarea
   with `counter: true` rendered outside a Field raises `ArgumentError` in development
   and test. Flagged to the decider on 2026-09-18 as the consequence of "rendered as
   help text"; the alternative, a wrapper around Textarea, is not taken here.

### Where it renders

4. **In the description part, at the inline-end.** The count is the last child of the
   Field's description element (`Ui::Field::DescriptionComponent`,
   `data-slot="field-description"`), on the same line as the description text: the
   text grows, the count is `shrink-0` and `tabular-nums` in `text-muted-foreground`
   (decided 2026-09-18). A Field with a counter and no description still renders the
   description part, holding the count alone. One element, so `aria-describedby`
   already names it (`ui-field-model-binding` § Behavior, item 20) — a person focusing
   the control hears the help text and then the count — and Field's swap hides and
   restores text and count together (items 19 and 22). The counter adds no second
   mechanism for any of that.
5. **The error wins.** When the Field is invalid the description part is hidden and the
   error takes its place, count included (item 19). The count keeps being tracked while
   hidden, so when a morph makes the field valid the line returns showing the current
   count (item 22). The counter never sets `aria-invalid`, never writes an error, and
   never touches the Field's `data-invalid`: validity is the server's and Field's
   (decided 2026-09-18).

### What it counts

6. **Code points, as Ruby counts them.** The count is the number of code points, which
   is what `String#length` returns, so a value the counter calls 500 is 500 to
   `validates length:`. An emoji sequence counts as its code points on both sides.
7. **Line breaks count as the server receives them.** A `<textarea>`'s API value has
   `LF` line breaks, but the browser submits `CRLF`, so each line break reaches Rails as
   two characters. The counter counts a line break as two, and the server-rendered count
   (item 8) does the same, so the counter and the validator agree exactly. A counter
   that used the API value's length would be one short per line.
8. **Server-rendered first.** Ruby renders the initial count and the limit from the
   textarea's content, so with JavaScript off the line shows a true count that simply
   doesn't update. `ui--character-count` takes over on connect and recounts on every
   `input` event, on the form's `reset`, and whenever a Turbo morph re-renders the field
   (it reads the content again on connect).

### Over the limit

9. **Destructive text, nothing else.** When the count exceeds `limit:`, the count reads
   in `text-destructive` and its element carries `data-over="true"`; the text itself is
   unchanged (`512 / 500`). Nothing about the control or the Field changes (item 5,
   decided 2026-09-18).

### What a screen reader hears

10. **Silent while typing; announced at thresholds.** The visible count changes
    silently: it is part of the accessible description, read on focus, not live.
    Announcements go to a polite `role="status"` region inside the Field, visually
    hidden, and only at three moments (decided 2026-09-18): when the remaining room
    first reaches ten percent of the limit or less (rounded down, never less than one
    character), when the count first exceeds the limit, and when it first comes back to
    the limit or under. Each crossing announces once; typing inside a band announces
    nothing. The messages are pluralised chrome, handed to the controller the way
    `select.results` is: `rails_ui_kit.character_counter.remaining`
    ("%{count} character remaining" / "%{count} characters remaining") and
    `rails_ui_kit.character_counter.over` ("%{count} character over the limit" /
    "%{count} characters over the limit").
11. **The visible format is chrome too.** `rails_ui_kit.character_counter.count` is
    "%{count} / %{limit}", so a locale can change the separator without a kit change.
    Every string follows `ui-localization`'s chrome rules, including the call-site
    override.

### Turbo, forms and direction

12. **No state of its own.** A Turbo morph keeps the description part (Field's presence
    rules, item 22); the controller recounts on connect. A stream `replace` delivers a
    new field with its server-rendered count. Nothing submits from the counter, and
    nothing in it is a value store.
13. **Inline-end, in both directions.** The count sits at the end of the line through
    logical utilities (`ui-localization-rtl`), so it is at the end in RTL too.

## Business rules

**Must**

1. **Help text, not validation.** The counter never marks the control invalid, never
   blocks a submission, never adds to `aria-describedby` beyond the description part it
   lives in, and never changes the Field's invalid state. The Field's error always wins
   (`ui-field-model-binding` § Behavior, items 19 and 20).
2. **Agrees with the server.** What the counter shows is what `validates length:` would
   count for the submitted value (§ Behavior, items 6 and 7). A disagreement, in either
   direction, is a defect.
3. **One mechanism.** Placement, hiding, restoring and animation are Field's. The counter
   adds no swap, presence or live-region logic beyond writing the status text.
4. **Tokens, chrome, direction.** No palette literal; every string through
   `rails_ui_kit.character_counter.*`; logical utilities only.
5. **Composes; reimplements none.** `ui--character-count` is registered by
   `registerControllers`, connects only where `counter: true`, and holds nothing a
   re-render cannot rebuild from the markup.

**Should**

6. **Quiet by default.** Threshold announcements only (§ Behavior, item 10). A host that
   wants more says so; the kit does not.

## Assumptions

Inherits `ui-component-library` § Assumptions.

- **A description part can hold the text and the count on one line without changing
  the order of the computed description.** The count is the last child in the DOM, so
  the accessible description reads text, then count. Verified in the browser lane the
  way Field item 20 verifies its description (the computed description, not the
  attribute). **At a contradiction**, keep the DOM order and drop any layout that would
  visually reorder; never reorder with CSS.
- **Rails does not normalise textarea line breaks on the way in.** `CRLF` from the
  browser reaches `validates length:` as two characters on every supported Rails
  version. Verify at build time by posting a value with line breaks and reading the
  param's length. **At a contradiction**, follow what Rails does and record a
  correction; rule 2 stands either way.
- **`ui--field` swaps the description part as a unit.** Checked 2026-09-18 in
  `field_controller.js`: it collects every `field-description` part and settles each,
  so a part with children needs nothing from it.
- **The kit's locale file carries a `character_counter` scope**, in
  `config/locales/rails_ui_kit.en.yml` and the `fr` fixture.

## Critical files

- `app/components/ui/textarea_component.rb`, `textarea_component.html.erb` — the two
  keywords, the misuse errors, and what Textarea tells Field it wants.
- `app/components/ui/field_component.rb`, `field_component.html.erb`,
  `app/components/ui/field/description_component.rb` — rendering the count at the end
  of the description part, and the part when only a count is present; the status
  region.
- `app/javascript/rails_ui_kit/controllers/character_count_controller.js` (new) —
  `ui--character-count`: counting (items 6–7), thresholds (item 10).
- `app/javascript/rails_ui_kit/index.js` — registers it.
- `config/locales/rails_ui_kit.en.yml`, `test/fixtures/locales/rails_ui_kit.fr.yml` —
  `rails_ui_kit.character_counter.*`.
- `examples/config/initializers/docs_pages.rb`, `examples/app/views/docs/` — a
  Character Counter page under Utilities, in the Forms section, with a limit, an
  over-limit paste, and a Field that goes invalid and back.
- `test/components/ui/textarea_component_test.rb`, `test/components/ui/field_component_test.rb`,
  `test/system/character_counter_test.rb` (new), `test/components/ui/chrome_override_test.rb`,
  `test/system/localization_switch_test.rb`, `test/components/ui/logical_direction_test.rb`,
  `test/javascript/register_controllers_test.rb`.
- `CHANGELOG.md`.

## Acceptance checks

### agent-loopable

- A Textarea with `counter: true, limit:` inside a Field renders the count as the last child of the description part, server-rendered from the content, counting code points and each line break as two; a counter with no description renders the part with the count alone; `counter:` without `limit:`, `limit:` without `counter:`, and `counter:` outside a Field each raise `ArgumentError` — run: `bundle exec rake test TEST=test/components/ui/textarea_component_test.rb`
- Typing updates the count; a paste past the limit turns it `text-destructive` with `data-over="true"` and leaves the control without `aria-invalid`; the status region announces once when remaining reaches ten percent, once when the count exceeds the limit, once when it returns under, and nothing between; a `422` delivered by morph hides the line and shows the error, and a valid morph brings the line back with the current count; form reset recounts; with JavaScript disabled the line shows the server's count — run: `bundle exec rake test:system TEST=test/system/character_counter_test.rb`
- The control's computed accessible description is the help text followed by the count, and `assert_accessible` passes valid, invalid and over the limit, in light and dark mode — run: `bundle exec rake test:system TEST=test/system/character_counter_test.rb TESTOPTS="--name=/accessib/"`
- A value with line breaks posted through the docs demo has a param length equal to the count the counter showed (§ Behavior, item 7) — run: `bundle exec rake test:system TEST=test/system/character_counter_test.rb TESTOPTS="--name=/agree/"`
- `registerControllers` registers `ui--character-count` — run: `bundle exec rake test TEST=test/javascript/register_controllers_test.rb`
- Every string is chrome: under the `fr` fixture the count and both announcements show French, and a call-site override wins — run: `bundle exec rake test:system TEST=test/system/localization_switch_test.rb && bundle exec rake test TEST=test/components/ui/chrome_override_test.rb`
- The count sits at the inline-end through logical utilities only — run: `bundle exec rake test TEST=test/components/ui/logical_direction_test.rb`

### judgeable

- Nothing in the counter sets validity, writes an error or alters Field's swap; placement and animation are Field's — judged against § Business rules, rules 1 and 3, and `ui-field-model-binding` § Behavior, items 19–22.
- The option reads as a Textarea option a Rails developer expects, consumed and not forwarded — judged against `ui-presentational-components` § Business rules, rule 1.
- No palette literal, and no string outside `rails_ui_kit.character_counter.*` — judged against § Business rules, rule 4.

### human-gate

- Jonathan types past the limit and back in the docs demo with VoiceOver in Safari, and judges that the announcements arrive at the three moments and nowhere else, and that the count reads as help text, not as an error.

## Out of scope / deferred

- **Input** — the same option on `Ui::InputComponent`, when a client build needs it.
- **A count with no limit** — `counter: true` alone; declined for now, a limit is what
  makes the count mean something.
- **Word and byte counts** — different concepts; not queued.
- **Hard enforcement from `limit:`** — that is `maxlength`, and it is the caller's.
- **A wrapper so a standalone Textarea can carry the count** — declined 2026-09-18
  (§ Behavior, item 3); reopen if a real form needs a counter outside Field.
