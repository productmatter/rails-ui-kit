# Open questions — ui-field-model-binding

Scope-level only. Each binds this scope; none binds a sibling. The one question below is
decided and doesn't gate the build.

## Does a model-bound Field fill the control's value?

The directive listed five things Field derives from the model: name, id, errors, label
text and required. It didn't list the value. Without the value, the one-line form
`Ui::FieldComponent.new(model: @user, attribute: :email)` renders an empty input. On a
`422` re-render, the very case the model-bound form exists to handle, the user's typing
disappears. Every caller would need a block just to pass `value: @user.email`, and that
undoes most of what the model form saves.

Filling it isn't free, for two reasons. A value means something different to each
control: `value:` on Input, element content on Textarea, `selected:` on Select. So Field
has to know the kit's three controls by name. And Rails' value rule has a security edge.
`password_field` and `file_field` render no value, so a naïve derivation would echo a
submitted password back into the HTML.

decider: Jonathan Simmons
options: (a) Field derives the value `form.text_field` renders (the `_before_type_cast` reader when present, else the attribute) and hands it to Input as `value:` (none for `type: "password"` or `"file"`), to Textarea as content and to Select as `selected:`; any other control gets nothing and the block form reads `field.value`; a caller-supplied value always wins; (b) no value derivation, and the model form always needs a block that passes the value, so the one-liner is dropped from the docs; (c) Input only, with Textarea and Select passed explicitly
default: (a). It's specified in § Behavior, item 16. Without it, the headline form silently loses input on re-render. The password and file exclusions match Rails exactly. And a three-entry mapping for the kit's own controls is a smaller cost than every caller writing a block.
deadline: 2026-09-21
decided: (a), 2026-09-14, on the orchestrator's ruling relaying the decider. Without value filling, the one-liner loses what the user typed on a `422`, which is data loss in the feature pitched as Rails-aware, so it isn't optional. Field knowing the kit's own three controls by name is acceptable coupling. A custom control still receives its value through explicit attributes. Password and file inputs never get a value. Recorded in spec § Behavior, item 16.
