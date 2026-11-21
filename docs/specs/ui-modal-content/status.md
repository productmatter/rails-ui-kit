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

## In progress

None.

## Last green checkpoint

2026-11-21, `feature/modal-content-component`: `bundle exec rake test`, `bundle exec rake test:system`
and `bundle exec rubocop` green. `specline check` reports nothing for this scope.

## Dead ends

None.

## Corrections

None.
