---
slug: ui-confirm-dialog
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: medium
size: large
target_model: standard
created: 2026-09-14
loop_budget: 5
---

## Intent

**The dialog is a template, and its contents are the caller's.** Jonathan asked whether
Confirm Dialog's icon is built in or depends on the content. It's built in, and that's a
defect. His ruling, 2026-09-14: **no component forces iconography.** The default template
is a title, a message and two actions. An icon is content a caller adds. The confirm
button's variant is content a caller chooses.

Confirm Dialog passes rule 0 on both gates. It owns Turbo's `data-turbo-confirm`, and focus,
modality and the answer promise are hard to get right in a browser.

**What is true today** (verified against the code on 2026-09-14, with `spec-localization`'s
in-progress `Ui::Chrome` work in the tree):

- `Ui::ConfirmDialogComponent < ViewComponent::Base`, not `Ui::Base`. It takes
  `initialize(title:, message:, confirm_label:, cancel_label:, **overrides)`. The four
  text keywords are `chrome_string`s. `overrides` merges into a frozen `DEFAULTS` hash of
  `id` and nine class strings that **replace** the defaults wholesale: `wrapper_class`,
  `body_class`, `footer_class`, `title_class`, `message_class`, `confirm_class`,
  `cancel_class`, `icon_wrapper_class` and `icon_class`.
- Every one of those defaults is a palette literal: `bg-white dark:bg-gray-800`,
  `bg-gray-100 dark:bg-gray-700/25`, `text-gray-900 dark:text-white`, the confirm button's
  `bg-red-600 hover:bg-red-500 text-white`, `bg-red-100 dark:bg-red-500/10` behind the
  icon, `text-red-600 dark:text-red-400` on it, and `backdrop:bg-gray-900/50` on the
  dialog. Parent rules 1 and 5 are both broken.
- The template **always** renders a red warning-triangle SVG (`aria-hidden`). A caller can
  restyle it through `icon_wrapper_class`/`icon_class`, but can't change the glyph or
  remove it. The confirm button is always red. "Publish this post?" looks exactly as
  dangerous as "Delete this project?", which trains people to stop reading confirmations.
  The docs app's own "Publish post" Turbo example shows it.
- The buttons are hand-classed `<button type="submit" value="cancel|confirm">` elements
  in a `<form method="dialog">`, not `Ui::ButtonComponent`. Cancel comes first in DOM and
  on screen, and carries `autofocus`. The dialog is `role="alertdialog"` with
  `aria-labelledby`/`aria-describedby`, opened as a modal through `ui--overlay`.
- **One shared `<dialog id="default-confirm">` is reused for every confirmation.**
  `dialog_controller.js` installs `window.defaultConfirmDialog(messageOrOptions)`, which
  reads the rendered `data-default-title`/`data-default-message`, overlays the options,
  writes only `title` and `message` as `textContent` (other option keys are silently
  ignored), and resolves `true` only for `returnValue === "confirm"`. It also installs
  `window.customConfirmDialog(selector)`, which opens a host dialog as rendered.
- `turbo_confirm_controller.js` sets `Turbo.config.forms.confirm`. Turbo calls it as
  `confirm(message, formElement, submitter)`, where `message` is `data-turbo-confirm` read
  from the submitter or the form (verified in bundled turbo-rails 2.0.23,
  `FormSubmission#start`). For a `data-turbo-method` link, Turbo builds a hidden form and
  copies **only** `data-turbo-confirm` onto it (verified, `FormLinkClickObserver`). The
  kit therefore remembers the clicked link in a capturing `click` listener, to read
  `data-turbo-confirm-title` back from it. That's the path any new per-confirmation
  attribute travels.

**What this scope is.** The default template without the icon. Every part becomes content: an
optional `icon` slot, the title, the message or a `body` slot, and the actions' labels and
confirm variant. The buttons become `Ui::ButtonComponent`. Colours become tokens, and the
dialog moves onto `Ui::Base`. JavaScript and Turbo can set the text and the confirm variant
per confirmation. That's `ui-foundation-retrofit`'s Confirm Dialog half, taken over here so
the template is rewritten once (§ Assumptions). It adopts `ui-toast`'s shared convention
(`ui-toast` § Business rules, rules 1 to 5): plain-data payloads, JavaScript that never
composes classes or markup, Button for every button, loud-in-development validation, and no
forced or JavaScript-supplied iconography.

**Appetite.** One component, two controllers touched, no new chrome string, no new token.

## Goal

Confirm Dialog renders its title, message and two `Ui::ButtonComponent` actions on tokens
and `Ui::Base`. The icon and body are Ruby slots, empty unless filled, and the confirm
variant is the caller's choice. A confirm variant, title, message and labels reach the
shared dialog from a Ruby render, `window.defaultConfirmDialog` and a Turbo
`data-turbo-confirm`, and reset between confirmations. Everything 0.2.0 rendered, except the
removed icon, is pinned by a regression check written before the change. This is
established when every agent-loopable check in § Acceptance checks passes.

## Non-goals

- **A kit icon set, or a tone that picks a glyph.** Ruled out by the decider. The kit ships
  no confirmation glyph.
- **Custom content through JavaScript or Turbo.** No icon, SVG or markup string travels
  through `defaultConfirmDialog` or a data attribute. Rich content comes from a
  Ruby-rendered dialog with slots, opened with `window.customConfirmDialog`.
- **A third action, or a caller-built actions area.** The dialog answers yes or no. Its
  `value="confirm"`/`value="cancel"` form is the answer contract.
- **Turbo confirmations opening a host's own dialog.** `data-turbo-confirm` uses the shared
  default dialog, as today.
- **Changing `role="alertdialog"`, Cancel's initial focus, or the button order.** A
  confirmation interrupts, and the least destructive answer takes focus, whatever the
  variant.

## Behavior

1. **The default template has no icon.** Title, message, and the actions: Cancel, then
   Confirm. The warning triangle and its tinted circle are deleted from the template. With
   no icon, the text column starts at the panel's inline-start padding at `sm` and up, and
   stays centred below it, as the text does today. **This is a visible change from 0.2.0**
   (item 11).

2. **The content, all of it the caller's:**

   | Part | Ruby | `defaultConfirmDialog` option | Turbo attribute |
   |---|---|---|---|
   | Title | `title:` (chrome default) | `title` | `data-turbo-confirm-title` (exists) |
   | Message | `message:` (chrome default) | `message`, or the String argument | `data-turbo-confirm` (Turbo's own) |
   | Rich body | `body` slot | none | none |
   | Icon | `icon` slot, empty by default | none | none |
   | Confirm label | `confirm_label:` (chrome default) | `confirm_label` | `data-turbo-confirm-confirm-label` |
   | Cancel label | `cancel_label:` (chrome default) | `cancel_label` | `data-turbo-confirm-cancel-label` |
   | Confirm variant | `confirm_variant:`, default `:destructive` | `confirm_variant` | `data-turbo-confirm-confirm-variant` |

   Option keys follow the shared rule (`ui-toast` § Business rules, rule 1): `snake_case`,
   one spelling in Ruby and JavaScript. A Turbo attribute is `data-turbo-confirm-` plus
   the key, dasherized, with no exceptions, so `title` gives the attribute that already
   ships. The doubled `confirm-confirm-` is the price of a rule a developer never has to
   look up. The labels are chrome by default (`ui-localization`) and content when a call
   site writes them.

3. **`confirm_variant:` defaults to `:destructive`.** Any of Button's variants is
   accepted: `destructive`, `default`, `outline`, `secondary`, `ghost`, `link`. A
   publish passes `:default` and gets a primary button. **The case for `:destructive`**:
   - **A wrong default costs different amounts each way.** A publish shown in red costs
     alarm fatigue. A delete shown in primary costs a data-loss confirmation that looks
     routine. The parent ranks the latter first ("what a wrong implementation costs: data
     loss, a destructive action").
   - **The icon is gone, so the red button is the only danger cue left.** A `:default`
     default would silently strip every existing delete confirmation of it. Every
     `data-turbo-confirm` in a host app shares this one dialog, and in Rails apps that
     attribute sits overwhelmingly on `destroy`.
   - **It keeps 0.2.0's button colour.** The one visible upgrade change is the icon.

   **The case against, and why it loses:** a neutral default is purer to "the kit imposes
   nothing". But a default is a template choice either way, and this one fails safe. The
   docs show `confirm_variant: :default` on the publish example, not on the delete one.

4. **Ruby render.** `Ui::ConfirmDialogComponent.new(id: "default-confirm", title:,
   message:, confirm_label:, cancel_label:, confirm_variant:, **class keywords,
   **html_attributes)`, with `renders_one :icon` and `renders_one :body`. `class:` merges
   onto the `<dialog>` root through `Ui::Base`. Everything a render sets is that dialog's
   default for every confirmation it shows.
   - **Icon slot:** rendered in a layout cell (`data-slot="confirm-dialog-icon"`,
     `aria-hidden="true"`) that owns size and placement, `size-12` centred above the text
     below `sm`, and `sm:size-10` at the inline-start. It owns no colour: the glyph and any
     tint are the caller's, through the slot's markup or `icon_wrapper_class:`. With the
     slot empty, the cell isn't rendered.
   - **Body slot:** rich content that replaces the message paragraph inside the same
     `aria-describedby` target. A dialog rendered with a body has a rich message, so a
     `defaultConfirmDialog` `message` option aimed at it is invalid (item 9). Rich content
     isn't overwritten by text.

5. **JavaScript.** `window.defaultConfirmDialog(message)` or
   `window.defaultConfirmDialog({ title, message, confirm_label, cancel_label,
   confirm_variant })`, still returning a Promise of `true` or `false`.
   `window.customConfirmDialog(selector)` opens a Ruby-rendered dialog exactly as rendered,
   as today, and is how rich content (an icon, a body) is used from JavaScript:

   ```erb
   <%= render Ui::ConfirmDialogComponent.new(id: "archive-confirm", title: t(".archive_title"),
         confirm_label: t(".archive"), confirm_variant: :default) do |dialog| %>
     <% dialog.with_icon { render "icons/archive" } %>
     <% dialog.with_body { t(".archive_body_html", name: @project.name) } %>
   <% end %>
   ```
   ```js
   if (await window.customConfirmDialog("#archive-confirm")) { … }
   ```

6. **Turbo.** `ui--turbo-confirm` reads each attribute in item 2 by the lookup order it
   already uses for `data-turbo-confirm-title`: the submitter, then the form, then the
   remembered `data-turbo-method` link when the form is the one Turbo built from it. It
   passes them to `defaultConfirmDialog` as options. **A `data-turbo-confirm` with no
   variant attribute passes no `confirm_variant`, so the dialog's rendered default applies.
   That's `:destructive` unless the host rendered otherwise.**

   ```erb
   <%= button_to "Publish", publish_post_path(@post), method: :patch,
         data: { turbo_confirm: "Readers will see it immediately.", turbo_confirm_title: "Publish this post?",
                 turbo_confirm_confirm_label: "Publish", turbo_confirm_confirm_variant: "default" } %>
   ```

7. **Every confirmation starts from the rendered defaults.** Each `defaultConfirmDialog`
   call resolves every part from its options, falling back to the dialog's rendered
   defaults: `data-default-title`, `-message`, `-confirm-label`, `-cancel-label` and
   `-confirm-variant`. So nothing one confirmation set leaks into the next. (0.2.0 already
   had the defect this rule prevents for the title, fixed by the check `TC1`.)

8. **Buttons are `Ui::ButtonComponent`,** and JavaScript only swaps them.
   - **Cancel** is `variant: :outline`.
   - **Confirm** is the resolved `confirm_variant`.
   - Both stay `<button type="submit">` with `value="cancel"`/`value="confirm"` inside the
     `<form method="dialog">`. Cancel keeps `autofocus` and comes first.
   - The layout classes today's buttons carry, full width below `sm` and auto width
     above it with the gap between them, are the dialog's own, merged onto Button's.
   - The dialog renders its confirm button in the default variant, and one `<template>`
     per other variant, each produced by `Ui::ButtonComponent` with the same merged
     classes. A confirmation that picks another variant swaps the clone in and writes its
     label. The next confirmation restores the rendered default.

   JavaScript writes text and swaps server-rendered elements. It writes no class
   (`ui-toast` § Business rules, rule 2).

9. **Invalid input** follows the shared rule: loud in development and test, safe in
   production (`ui-toast` § Business rules, rule 4). It covers:
   - An unknown option key, including `icon` or any markup-bearing key.
   - An unknown `confirm_variant`.
   - A non-String text value.
   - `message` aimed at a dialog rendered with a body.

   **Ruby** raises through `Ui::Base`'s unknown-variant path for `confirm_variant`, and
   `ArgumentError` for the rest.

   **JavaScript** reads `data-strict` rendered on the dialog from
   `Ui::Base.raise_on_unknown_variant?`. When strict, `defaultConfirmDialog` rejects before
   opening. `ui--turbo-confirm` already catches that, logs it, and falls back to
   `window.confirm`, which is loud enough. When not strict, it warns and opens with the
   invalid part at its rendered default.

10. **Tokens, logical properties, and the class keywords.** Every palette literal is
    replaced by a token:
    - The panel is `bg-popover text-popover-foreground` with the kit radius, a shadow and a
      `border-border` outline.
    - The footer is `bg-muted`, the title `text-popover-foreground` and the message
      `text-muted-foreground`.
    - The backdrop uses exactly the classes `Ui::ModalComponent` uses, so the kit has one
      modal backdrop.

    No `dark:` utility remains in the component. Directional classes stay logical
    (`sm:ms-4`, `sm:text-start`, as `spec-localization` already converted them).

    The class keywords `wrapper_class`, `body_class`, `footer_class`, `title_class`,
    `message_class`, `confirm_class`, `cancel_class` and `icon_wrapper_class` **stay, and
    now merge** onto the token defaults with `tailwind_merge`, so a caller still wins
    (parent rule 5). `icon_class:` is **removed**, because the kit no longer renders a
    glyph for it to style. Passing it is Ruby's own unknown-keyword `ArgumentError`.
    **Decided 2026-09-14 by the orchestrator's ruling that ratified this scope**
    (`open-questions.md`). This **reverses `ui-foundation-retrofit`'s ratified deletion of
    all nine**, for two reasons. Deleting them would break every 0.2.0 app that styles its
    dialog. Merging fixes the defect the retrofit actually named, wholesale replacement,
    without that break. The one behaviour difference, which UPGRADING states: a caller who
    relied on replacing a default wholesale now gets back the default utilities that don't
    conflict with their classes.

11. **The upgrade notes.** `UPGRADING.md` gains these entries and grep lines:

    > ## The confirm dialog no longer shows a warning icon (visible, not loud)
    >
    > `Ui::ConfirmDialogComponent` no longer renders the red warning triangle. Its default
    > is a title, a message and the two buttons. The confirm button is still destructive
    > red by default. A dialog that isn't confirming something destructive can now say so
    > with `confirm_variant: :default`, or `data-turbo-confirm-confirm-variant="default"`.
    >
    > **To get an icon back,** render it as content. This restores the 0.2.0 look:
    >
    > ```erb
    > <%= render Ui::ConfirmDialogComponent.new(icon_wrapper_class: "rounded-full bg-destructive/10 text-destructive") do |dialog| %>
    >   <% dialog.with_icon do %>
    >     <svg class="size-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
    >       <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
    >     </svg>
    >   <% end %>
    > <% end %>
    > ```
    >
    > The icon shows on every confirmation that dialog opens, from JavaScript and Turbo
    > too. An icon can't be passed through JavaScript.
    >
    > ## Confirm dialog class options add to the defaults instead of replacing them (visible, one loud)
    >
    > `wrapper_class:`, `body_class:`, `footer_class:`, `title_class:`, `message_class:`,
    > `confirm_class:`, `cancel_class:` and `icon_wrapper_class:` used to replace the
    > component's classes. They're now merged on top: where your class and a default set the
    > same property, yours wins, and the defaults you didn't contradict stay. If you passed
    > a complete class string, the result is usually what you had. **The one difference:**
    > if you relied on replacing a default wholesale, the default utilities your classes
    > don't conflict with come back. Your `wrapper_class: "rounded-none"` still removes the
    > radius, but the token background and shadow you didn't mention now render. To drop
    > one, pass a class that sets the same property (`shadow-none`, `bg-transparent`). `icon_class:` is removed and raises `ArgumentError`. Style your
    > icon inside the `icon` slot.
    >
    > ```bash
    > grep -rn 'ConfirmDialogComponent.new' app/ | grep '_class:'
    > grep -rn 'icon_class:' app/ | grep -i confirm
    > ```

## Business rules

These refine `ui-component-library` § Business rules, rules 1, 5 and 6, and adopt
`ui-toast` § Business rules, rules 1 to 5, the shared convention, without restating them.

**Must**

1. **The kit renders no icon unless a caller provides one** (decided 2026-09-14, Jonathan
   Simmons). An icon is Ruby slot content in an `aria-hidden` cell. No option,
   attribute or JavaScript value supplies or selects one.
2. **Meaning is in the words.** A title and a confirm label say what will happen. Neither
   the variant's colour nor an icon is ever the only signal. The docs' destructive example
   names its action ("Delete project"), not "Confirm".
3. **A confirmation with no variant is destructive** unless the rendered dialog says
   otherwise, from every entry point.
4. **Every confirmation starts from the rendered defaults.** No option outlives the
   confirmation that set it.
5. **The answer contract is unchanged.** It's `role="alertdialog"`, Cancel first with
   initial focus, `value="confirm"` resolving `true`, and everything else, including
   Escape, the Turbo cache and a superseding confirmation, resolving `false`.
6. **Everything 0.2.0 rendered except the icon is pinned before it changes** (§ Acceptance
   checks). A pinned property that moves is a defect, not a restyle, with one exception:
   colour moves to tokens, which the retrofit's visual-parity assumption already accepts.

## Assumptions

- **This scope takes over Confirm Dialog's half of `ui-foundation-retrofit`.** That covers
  tokens, `Ui::Base` and the class-keyword decision. The dialog already consumes
  `ui--overlay`, so there's no primitive work. It reverses one ratified retrofit
  decision, deleting all nine class keywords (decided 2026-09-14, § Behavior item 10). The
  retrofit's spec and `implementation.md` were trimmed to match that day.
  **At a contradiction**, where the retrofit build has already migrated the dialog, this
  scope builds on it.
- **Turbo's confirm hook, verified in bundled turbo-rails 2.0.23:**
  `confirm(message, formElement, submitter)`. `getAttribute("data-turbo-confirm",
  submitter, form)` takes the first element that has the attribute. A link-built form
  receives only `data-turbo-confirm`. **At a contradiction** after a Turbo upgrade, keep
  the remembered-link lookup the kit already has rather than adding a second mechanism.
- **`spec-localization`'s `chrome_string` keywords land first.** The four text keywords
  and their keys are its; this scope renders them into `data-default-*` and doesn't rename
  them.
- **The remembered link is reliable for a `data-turbo-method` link.** `TC1` already relies
  on it for the title. The new attributes ride the same lookup, so they share its limits
  and add none.

## Critical files

- `app/components/ui/confirm_dialog_component.rb`, `.html.erb`: the subject.
- `app/javascript/rails_ui_kit/controllers/dialog_controller.js`: option resolution,
  defaults reset, button swap, strict validation.
- `app/javascript/rails_ui_kit/controllers/turbo_confirm_controller.js`: reading the
  attributes.
- `app/components/ui/button_component.rb`, `app/components/ui/base.rb`,
  `app/components/ui/modal_component.rb` (its backdrop classes): read, not changed.
- `test/components/ui/confirm_dialog_component_test.rb`, which needs a rewrite of the two
  class-keyword tests, `test/system/confirm_dialog_test.rb` and
  `test/system/turbo_confirm_test.rb`.
- `examples/app/views/docs/confirm_dialog.html.erb`, `examples/app/views/docs/turbo_confirm*`,
  `README.md` (Confirm dialog theming, which is rewritten, and Triggering confirm dialogs),
  `CHANGELOG.md`, `UPGRADING.md`.

## Acceptance checks

### agent-loopable

- **Written and green against today's component before any change to it,** then kept green unedited. The default render keeps: `id="default-confirm"`, `role="alertdialog"`, `aria-labelledby`/`aria-describedby` resolving to the title and message, `data-default-title`/`-message`, a `method="dialog"` form with Cancel before Confirm in DOM and on screen, Cancel focused on open, the panel's width at a 1280 px and a 375 px viewport, the body and footer padding, the title's and message's font size and weight, the buttons' heights and their full-width-below-`sm` layout, the footer's end alignment, the confirm button's fill in the destructive hue family, and Escape and the backdrop behaving as today. **It pins everything except the icon.** The icon cell's presence and the text column's inline offset are deliberately not asserted. Proved able to fail by planting a changed footer padding. Run: `bundle exec rake test:system TEST=test/system/confirm_dialog_default_render_test.rb`
- The UPGRADING snippet restores the icon: rendered as documented, the icon cell measures 48 px below `sm` and 40 px above, sits where 0.2.0's did relative to the title, and is `aria-hidden`. Run: `bundle exec rake test:system TEST=test/system/confirm_dialog_icon_test.rb`
- Ruby render. No `<svg>` and no `confirm-dialog-icon` slot by default. The icon and body slots render in their cells. Confirm is `Ui::ButtonComponent` `:destructive` by default and matches that variant's classes, and `confirm_variant: :default` gives the primary variant's classes. Cancel is `:outline`. Each class keyword beats a conflicting default and keeps the defaults it doesn't contradict. `icon_class:` raises. No palette literal and no `dark:` utility is in the component. Run: `bundle exec rake test TEST=test/components/ui/confirm_dialog_component_test.rb && ! grep -nE -- '-(white|black)\b|-(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|green|blue|indigo)-[0-9]{2,3}\b|\bdark:' app/components/ui/confirm_dialog_component.rb app/components/ui/confirm_dialog_component.html.erb`
- **The confirm variant reaches the dialog from all three entry points.** A dialog rendered with `confirm_variant: :default` shows a primary confirm. `defaultConfirmDialog({ confirm_variant: "default" })` shows one with the primary variant's exact classes. A Turbo `data-turbo-confirm-confirm-variant="default"` does the same on a submit button, on a form, and on a `data-turbo-method` link. The labels and title arrive the same three ways. Run: `bundle exec rake test:system TEST=test/system/confirm_dialog_variant_test.rb`
- **A Turbo `data-turbo-confirm` without a variant still gets `:destructive`,** including immediately after a confirmation that set `default`, which is the leak `TC1` guards for the title. Every part resets the same way from `defaultConfirmDialog`. Run: `bundle exec rake test:system TEST=test/system/turbo_confirm_test.rb`
- Nothing custom crosses JavaScript. Strict `defaultConfirmDialog({ icon: "<svg onload=…>" })` rejects before opening, and injects no element. Not strict, it warns, opens with no icon, and the DOM has no new `svg` or `img`. An unknown `confirm_variant` and a `message` aimed at a body-slot dialog behave by § Behavior, item 9. Run: `bundle exec rake test:system TEST=test/system/confirm_dialog_validation_test.rb`
- Both variants pass `assert_accessible` in light and dark, with and without an icon, LTR and RTL. The existing CD and TC checks stay green. Run: `bundle exec rake test:system TEST=test/system/confirm_dialog_test.rb`
- The whole suite stays green. Run: `bundle exec rubocop && bundle exec rake test && bundle exec rake test:system`

### judgeable

- The docs page, README and UPGRADING entries show a delete and a publish confirmation side
  by side. They make the no-icon default, `confirm_variant:`, and "rich content needs a
  Ruby-rendered dialog" plain. Judged against § Behavior, items 1 to 5 and 11.
- `dialog_controller.js` and `turbo_confirm_controller.js` write no class and build no
  markup. Judged against `ui-toast` § Business rules, rule 2.

### human-gate

- Jonathan compares the default dialog against 0.2.0 in light and dark and accepts that
  only the icon and token colour moved. He then views a publish confirmation beside a
  delete one and accepts that the difference reads.

## Out of scope / deferred

- **A Turbo attribute that points a confirmation at a host's own dialog**
  (`data-turbo-confirm-dialog="#id"`) is not planned. There's no pulling need, and it
  would make the remembered-link lookup carry a selector.
- **Per-confirmation classes from JavaScript** are not planned. It's the same reason as
  `ui-toast`'s open question on an action's `class`.
- **Retiring the class keywords in favour of a general per-part `class:` API** is not
  planned (decided 2026-09-14, `open-questions.md`). `Ui::Base` ships no part API today.
