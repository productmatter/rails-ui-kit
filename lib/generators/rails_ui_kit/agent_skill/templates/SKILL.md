---
name: rails-ui-kit
description: Use when building or changing a form, a modal, a modal form, or any Turbo-driven overlay in this app — anything using Ui::FieldComponent, Ui::SelectComponent, Ui::ChoicesComponent, Ui::ModalComponent, the ui--modal Stimulus controller, or turbo_stream.ui_close_modal. Read the kit's own guide first; its model binding and Turbo wiring are easy to get subtly wrong.
---

# rails_ui_kit

This app uses the `rails_ui_kit` gem for its UI components. The kit ships the guide for each of
them inside the gem. **Read the guide for what you are building before you write the markup** —
from the installed gem, so the instructions always match the version this app actually has:

```bash
cat "$(bundle info --path rails_ui_kit)/docs/guides/forms.md"
cat "$(bundle info --path rails_ui_kit)/docs/guides/modal-and-turbo.md"
```

## Guides

| Building | Read |
|---|---|
| A form: fields bound to a model, an enum, a `belongs_to`, a `has_many`, nested attributes | `docs/guides/forms.md` |
| A modal, a modal form, or a Turbo-driven overlay | `docs/guides/modal-and-turbo.md` |

List what else is there with:

```bash
ls "$(bundle info --path rails_ui_kit)/docs/guides/"
```

## Rules

- Never copy a guide into this repository. `bundle info --path rails_ui_kit` resolves to the
  version installed right now; a copy goes stale the next time the gem is upgraded, and stale
  instructions are worse than none.
- If a guide and this app's existing code disagree, say so rather than silently following either.
