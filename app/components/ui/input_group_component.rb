# frozen_string_literal: true

module Ui
  # A control -- Input, Textarea or a Button addon -- with text/icon/Button addons
  # on any of its four sides. The control is the plain block content (as Card's
  # unslotted body is); addons are a call-ordered renders_many, each positioning
  # itself via its own `align` (rule 3). The group, not the control, carries the
  # boundary and the focus ring: rule 1's "same modifier wins" default is applied
  # here as `[&_[data-slot=input]]:` / `[&_[data-slot=textarea]]:` selectors on the
  # group, since the control renders through the caller, not through a part this
  # component owns, so there's no with_control(class:) to pass an override to.
  # Suppressing a border/shadow/fill is a value swap tailwind_merge can't help with
  # across that boundary; overriding just outline-width (`outline-0`, not
  # `outline-none` -- rule 4's forced-colors note -- and rules 2's box-shadow ban)
  # works because the group's descendant selector is more specific than the
  # control's own `focus-visible:outline-2`, so it wins on the cascade regardless
  # of source order. A caller who wants the control's own ring back passes
  # `class: "focus-visible:outline-2"` directly on it -- same modifier, same
  # specificity fight, and the control's own rule sits later in the stylesheet.
  class InputGroupComponent < Ui::Base
    data_slot 'input-group'

    class_variants(
      base: 'group/input-group relative flex w-full flex-wrap items-center rounded-md border border-input ' \
            'bg-transparent dark:bg-muted/50 shadow-xs transition-colors ' \
            'has-[[data-align=block-start]]:flex-col has-[[data-align=block-start]]:flex-nowrap ' \
            'has-[[data-align=block-end]]:flex-col has-[[data-align=block-end]]:flex-nowrap ' \
            'has-[[data-slot=input]:focus-visible]:outline-2 has-[[data-slot=input]:focus-visible]:outline-offset-2 ' \
            'has-[[data-slot=input]:focus-visible]:outline-ring ' \
            'has-[[data-slot=textarea]:focus-visible]:outline-2 has-[[data-slot=textarea]:focus-visible]:outline-offset-2 ' \
            'has-[[data-slot=textarea]:focus-visible]:outline-ring ' \
            'has-[[data-slot=input][aria-invalid=true]]:border-destructive ' \
            'has-[[data-slot=textarea][aria-invalid=true]]:border-destructive ' \
            'has-[[data-slot=input][aria-invalid=true]:focus-visible]:outline-destructive ' \
            'has-[[data-slot=textarea][aria-invalid=true]:focus-visible]:outline-destructive ' \
            '[&_[data-slot=input]]:min-w-0 [&_[data-slot=input]]:flex-1 [&_[data-slot=input]]:border-transparent ' \
            '[&_[data-slot=input]]:bg-transparent [&_[data-slot=input]]:shadow-none [&_[data-slot=input]]:focus-visible:outline-0 ' \
            '[&_[data-slot=textarea]]:min-w-0 [&_[data-slot=textarea]]:w-full [&_[data-slot=textarea]]:border-transparent ' \
            '[&_[data-slot=textarea]]:bg-transparent [&_[data-slot=textarea]]:shadow-none [&_[data-slot=textarea]]:focus-visible:outline-0'
    )

    renders_many :addons, Ui::InputGroup::AddonComponent
  end
end
