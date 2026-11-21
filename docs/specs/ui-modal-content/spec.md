---
slug: ui-modal-content
type: feature
status: ratified
decider: Jonathan Simmons
blast_radius: low
size: small
target_model: standard
created: 2026-11-21
loop_budget: 4
---

## Intent

`Ui::ModalComponent` is already a pure wrapper: it renders only its `content` inside the
`<dialog>` and owns open, close, focus, scroll lock, position and animation. The kit gives a
host nothing for what goes *inside* it, so every host hand-rolls a header, a body and a
footer. An audit of the main consuming app found 44 modals. The ones built on a shared
content component conform; the hand-rolled ones drift in two ways:

- **Layout.** The content root doesn't fill a full-height pane, so in a `position: :right`
  modal the content hugs the top third and the footer floats mid-panel instead of sitting
  at the bottom.
- **Later responses re-mount the modal.** A 422, a server-decided confirm step, or step 2
  of a flow re-renders a whole new `Ui::ModalComponent` through `turbo_stream.update
  "modal"` instead of replacing the content. The dialog re-animates, loses its
  `track_changes` state, and jumps width.

Decided 2026-11-21 by Jonathan Simmons: **the modal is a wrapper, mounted once; its
content — header, body, footer — is its own turbo frame, and every later server response
addresses the frame, never the modal.** This scope makes that model a component, so the
right shape is the easy one, and adds an opt-in check that catches a modal built without it.

## Goal

A host renders `Ui::ModalContentComponent.new(id:, title:)` inside `Ui::ModalComponent` on
open, and the same component on its own for every later response. The frame id is the same
in every state by construction. The header stays at the top and the footer at the bottom of
a full-height pane, whether the content is short or overflows. A 422 swaps the frame and
leaves the same `<dialog>` element open. A host that turns on
`Ui::ModalComponent.require_content_component` gets an error for any modal whose content
skips the component.

## Non-goals

- **No change to `Ui::ModalComponent`'s look or behaviour by default.** Strict mode is off
  unless a host turns it on.
- **No new Stimulus controller.** The close button uses `ui--modal#close`, and the form
  uses `ui--form-change`; both already ship.
- **No form builder.** Kit fields bind through `model:`, so the form block needs no
  builder (`ui-field-model-binding`).
- **No rewrite of the Modal page's position previews.** They are host-flavoured
  showcases, not the pattern.

## Behavior

### The component

1. **`Ui::ModalContentComponent.new(id:, ...)` always renders a `<turbo-frame>` as its
   root**, with `id:` as the frame id and `data-slot="modal-content"`. The same component
   renders inside the modal on open and on its own (a bare frame) for a 422, a next step or
   an in-modal navigation, so the frame id can't differ between states.
2. **The header.** `title:` renders an `<h2>` with the id `title_id`, which is
   `"#{id}_title"` and public, so the caller names the dialog with
   `Ui::ModalComponent.new(aria: { labelledby: content.title_id })`. `description:` renders
   a muted line under the title. `close:` (default `true`) renders an icon button with
   `data-action="click->ui--modal#close"`, named by the chrome string
   `rails_ui_kit.modal.close_label` (`close_label:` overrides it). With no title, no
   description, no header slot and `close: false`, the header isn't rendered at all.
3. **Slots.** `header` replaces the default heading and close button inside the sticky
   header wrapper, for a custom header such as a phone title bar with Cancel, a title and
   Save. The content block is the body. `footer` holds the actions; with no footer slot,
   no footer is rendered.
4. **`form:`** takes a Hash of `form_with` options. When it's given, one `<form>` wraps the
   header, body and footer, so a submit button in the header and one in the footer submit
   the same form. The form carries `data-controller="ui--form-change"`, joined with any
   controller the caller passes, so `track_changes: true` works with no extra wiring.
5. **Classes and attributes.** `header_class:`, `body_class:` and `footer_class:` merge
   over each part's defaults through `tailwind_merge`. Every other keyword is forwarded to
   the root frame, and `class:` merges over the root's defaults.

### Layout contract

6. **The root fills a full-height pane.** The frame is `flex min-h-full flex-col`. In a
   `:right` or `:left` modal (`h-screen overflow-y-auto`) it fills the dialog. In a
   `:center` or `:bottom` modal it takes its natural height. With `form:`, the form is
   `flex flex-1 flex-col`, so the chain keeps filling.
7. **The header is sticky at the top**, `sticky top-0`, on the popover background with a
   bottom border: title and description at the inline start, close at the inline end.
8. **The body is `flex-1`**, padded, so it takes whatever height the header and footer
   leave.
9. **The footer is sticky at the bottom**, `sticky bottom-0`, on the popover background
   with a top border, actions aligned to the inline end. When the content is short, its
   bottom edge sits on the dialog's bottom edge. When the content overflows and the dialog
   scrolls, it stays in view.

### Strict mode

10. **`Ui::ModalComponent.require_content_component`**, a class-level setting, defaults to
    `false`. When it's `true`, rendering a `Ui::ModalComponent` whose rendered content
    doesn't contain `data-slot="modal-content"` raises
    `Ui::ModalComponent::MissingContentError`, naming the fix. The check reads the
    rendered HTML, so content built through partials or other components counts. A host
    turns it on in development and test, from a `to_prepare` block, so it survives a code
    reload.

### Guide and demos

11. **The guide teaches the model.** `docs/guides/modal-and-turbo.md` says that content is
    a component that owns its frame, and that later responses replace the frame, never
    re-mount the modal. §4 is rewritten around the component and its layout contract. The
    guide's scenarios include a multi-step flow, a server-decided confirm step and a
    create that answers with a one-time result. The reference tables gain the component
    and strict mode, and the checklist gains lines for both.
12. **The demos use it.** The `examples/` Modal & Turbo resource (projects and invitations,
    including the read-only activity modal) renders its content through the component, so
    the guide's verbatim samples show the pattern.

## Business rules

**Must**

1. **One frame id per content, in every state.** The component is the only thing that
   renders the content's frame, and it renders it in every state.
2. **Later responses address the frame.** No guide sample or demo answers a 422, a next
   step or an in-modal navigation by re-rendering `Ui::ModalComponent`.
3. **Additive.** With strict mode off, no existing modal renders differently.
4. **Chrome in every shipped locale.** The close button's name goes through I18n, in
   `config/locales/rails_ui_kit.en.yml` and in the `fr` test fixture, and is documented on
   the Internationalization page (`ui-localization`).
5. **Logical utilities only** (`ui-localization-rtl` § Business rules, rule 1).
6. **Guide, demos and tests change together** (`ui-modal-turbo` § Business rules, rule 4).

**Should**

7. **Hosts turn strict mode on in development and test**, so a hand-rolled modal fails
   while it's being built rather than drifting in production.

## Assumptions

Inherits `ui-component-library` § Assumptions and `ui-modal-turbo` § Assumptions.

- **A `<turbo-frame>` is inline by default.** Giving it `flex` makes it a block-level flex
  container, and percentage `min-height` resolves against a dialog with a definite height
  (`h-screen`), so `min-h-full` fills a side pane. **At a contradiction**, the system test
  in § Acceptance checks fails, and the fix goes in the component's root classes.
- **`sticky` resolves against the dialog's own scroll box.** The dialog is the overflow
  container (`overflow-y-auto`) and the sticky parts' containing block spans the whole
  content, so the header and footer stick for the full scroll.

## Critical files

- `app/components/ui/modal_content_component.rb`, `modal_content_component.html.erb` (new).
- `app/components/ui/modal_component.rb` — `require_content_component` and
  `MissingContentError`.
- `config/locales/rails_ui_kit.en.yml`, `test/fixtures/locales/rails_ui_kit.fr.yml` —
  `rails_ui_kit.modal.close_label`.
- `examples/app/views/projects/*`, `examples/app/views/invitations/*` — the demo resource.
- `examples/app/views/docs/modal.html.erb`, `examples/app/views/docs/i18n.html.erb` — the
  docs site.
- `docs/guides/modal-and-turbo.md`, `test/modal_and_turbo_guide_test.rb`.
- `test/components/ui/modal_content_component_test.rb` (new),
  `test/components/ui/modal_component_test.rb`, `test/system/modal_content_test.rb` (new).
- `CHANGELOG.md`.

## Acceptance checks

### agent-loopable

- The component renders a `<turbo-frame>` root with the id and `data-slot`, with or without a title, description, header slot and footer slot; `title_id` names the heading; `close: false` drops the close button; `form:` wraps every part in one form carrying `ui--form-change` joined with the caller's controller; class keywords merge and attributes forward — run: `bundle exec rake test TEST=test/components/ui/modal_content_component_test.rb`
- Strict mode off renders any content; on, it raises `MissingContentError` without the component and renders with it, including content from a partial — run: `bundle exec rake test TEST=test/components/ui/modal_component_test.rb`
- In a `:right` modal the footer's bottom edge sits on the dialog's bottom when the content is short, and stays in view when the content overflows and the dialog scrolls; the header stays at the top — run: `bundle exec rake test:system TEST=test/system/modal_content_test.rb`
- A 422 keeps the same `<dialog>` element and the same frame id, and the header's close button closes the modal — run: `bundle exec rake test:system TEST=test/system/modal_content_test.rb`
- Every guide sample is still a verbatim slice of its demo file — run: `bundle exec rake test TEST=test/modal_and_turbo_guide_test.rb`
- The close label is chrome, in English and the `fr` fixture, and documented — run: `bundle exec rake test TEST=test/i18n/chrome_contract_test.rb`
- Every existing Modal & Turbo lifecycle test stays green on the converted demos — run: `bundle exec rake test:system TEST="test/system/modal_*_test.rb"`

### judgeable

- The guide makes "content owns its frame; later responses replace the frame" explicit, and every claim it adds is a test — judged against § Behavior, item 11, and `ui-modal-turbo` § Business rules, rule 4.

### human-gate

- Jonathan opens the docs app's demos and judges the header, body and footer as a host's
  default modal content.

## Out of scope / deferred

- **Converting the Modal page's eight position previews.** Showcases, not the pattern.
- **A scrolling body with a fixed header and footer** (overflow on the body rather than the
  dialog). Sticky parts on the dialog's own scroll give the same result without a second
  scroll container.
