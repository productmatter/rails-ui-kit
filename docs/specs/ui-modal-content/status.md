## State

ready-for-review

Shaped and built 2026-11-21 on `feature/modal-content-component`, from Jonathan Simmons's brief,
which decided the model: the modal is a wrapper mounted once, and its content is a component that
owns its own frame. Every § Acceptance check outside the human gate runs green. Jonathan's read of
the demos (§ Acceptance checks, human-gate) is still open.

## Done

- Authored `spec.md`, `relations.md` and this `status.md`, and added the scope to
  `ui-component-library` § Scopes.
- **The component.** `Ui::ModalContentComponent` (`app/components/ui/modal_content_component.*`):
  `id:`, `title:`, `description:`, `close:`, `close_label:`, `form:`, `header_class:`,
  `body_class:`, `footer_class:`, the `header` and `footer` slots, the `title_id` reader, and
  attribute forwarding onto the root frame. The `rails_ui_kit.modal.close_label` chrome string is in
  `en`, the `fr` fixture and on the Internationalization page.
- **Strict mode.** `Ui::ModalComponent.require_content_component` (a `class_attribute`, default
  `false`) and `Ui::ModalComponent::MissingContentError`, checked in `before_render` against the
  rendered content.
- **Guide, demos, docs.** The projects, invitations and activity demos render through the
  component. `docs/guides/modal-and-turbo.md` § "The shape of it", §3 and §4 are rewritten around
  it, with the layout contract, the later-response scenarios and strict mode, plus a gotcha,
  reference rows and checklist lines. The README's modal sample and the Modal docs page (a new
  Content section) follow.
- **Tests.** `test/components/ui/modal_content_component_test.rb` (new),
  `test/components/ui/modal_component_test.rb` (strict mode), and `test/system/modal_content_test.rb`
  (new): the side-panel layout short and overflowing, a 422 and a stream replace keeping the same
  dialog, the header close, and an axe audit. The layout assertions were checked against a
  mutant without `min-h-full` and the sticky footer, and both failed it.
- **Adversarial review, fixed (2026-11-21).** Each finding was confirmed in a browser by the
  reviewer, and each fix has a test that fails without it:
  - The top and bottom positions had no max-height, so long content grew past the viewport. They
    are now `max-h-[90dvh]`, and the overflow and sticky check runs in every position.
  - The side panels are `h-dvh`, and the footer's bottom padding respects
    `env(safe-area-inset-bottom)`.
  - A `<form>` inside `form:` mode raises in development and test. After a frame swap it turned
    Save into the inner form's DELETE.
  - The unsaved-changes prompt survives a 422. `ui--form-change` no longer announces `pristine`
    as it connects, and a model with errors renders the form dirty. This bug predates this scope and
    exists on 0.5.2.
  - `title:` or `description:` given with `with_header` raises.
  - A blank `id:` raises.
  - `description_id` is exposed for the modal's `aria-describedby`.
  - Strict mode now requires the content component to be the content's root, and every doc says it
    enforces structure rather than preventing re-mounts. The kit's own remaining modals (the
    position previews, the Select page's and the stress page's) are converted, and `examples/`
    runs with strict mode on.
  - The guide says a modal form succeeds with a stream or a `204`, never a redirect. A system test
    proves the redirect renders "Content missing".
  - The guide notes that two open modals need distinct content ids, and the README sample is
    complete.

## In progress

None.

## Last green checkpoint

2026-11-21, `feature/modal-content-component`: `bundle exec rake test`, `bundle exec rake test:system`
and `bundle exec rubocop` green. `specline check` reports nothing for this scope.

## Dead ends

None.

## Corrections

- § Behavior, items 1–4, 6, 9, 10 and 12, and the new item 13: amended for the review's findings.
  Strict mode's first text implied it prevented re-mounts; it enforces structure. — provable —
  adversarial review
