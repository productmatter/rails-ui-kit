# frozen_string_literal: true

module Ui
  module Select
    # The boxes Select paints, as the class list each element needs. Held apart from the component
    # the way Ui::Select::Primitives is — and Ui::Choices::Variant from Choices — so the component
    # stays about names, values and wiring. It is also where the one thing both renderings of the
    # control have to agree on, the box itself, is written once: the native select and whichever
    # element replaces it share CONTROL and the step's height, so the swap shifts nothing
    # (ui-select § Behavior, item 2).
    class Box
      # Each step's full box, read from the same tokens as Button, Input and Textarea
      # (ui-control-sizing): the height token, plus the step's own inline padding, text size and
      # radius (§ Behavior's table). Not a class_variants axis: variants render onto the
      # component's root, and the box belongs on the control, which is not the root.
      #
      # The end side widens past the table's own value, by a constant five spacing units, to clear
      # the chevron: the glyph is absolutely positioned (`inset-e-2.5 size-4` in the template) and
      # doesn't move with the step, so the padding needed to keep text clear of it is the step's
      # own value plus that fixed headroom, never less.
      SIZES = {
        xs: 'h-(--control-height-xs) ps-2 pe-7 text-xs rounded-sm',
        sm: 'h-(--control-height-sm) ps-2 pe-7 text-sm rounded-sm',
        default: 'h-(--control-height) ps-2.5 pe-7.5 text-sm rounded-md',
        lg: 'h-(--control-height-lg) ps-3 pe-8 text-sm rounded-md',
        xl: 'h-(--control-height-xl) ps-3.5 pe-8.5 text-sm rounded-md'
      }.freeze

      # The visible control's box, shared by the select and whatever takes over from it. Filled in
      # both modes, as Input is, so it reads as a control on any surface; the popup is bg-popover,
      # a different token, so the open list never blends into the box it hangs from.
      CONTROL = 'flex w-full min-w-0 appearance-none items-center border border-input ' \
                'bg-background dark:bg-muted/50 shadow-xs transition-colors ' \
                'focus-visible:border-ring focus-visible:outline-2 focus-visible:outline-ring ' \
                'disabled:pointer-events-none disabled:opacity-50 ' \
                'aria-disabled:pointer-events-none aria-disabled:opacity-50 ' \
                'aria-invalid:border-destructive aria-invalid:focus-visible:border-destructive ' \
                'aria-invalid:focus-visible:outline-destructive'

      # Search mode's control is a <button>, whose text the user agent centres; the label it shows
      # reads from the start of the box, like the select's and the combobox's.
      TRIGGER = 'text-start'

      # Native <option>s don't inherit the select's classes, so the popup colours reach them
      # through a descendant selector rather than by asking the caller to class each one.
      NATIVE = '[&_option]:bg-popover [&_option]:text-popover-foreground ' \
               '[&_optgroup]:bg-popover [&_optgroup]:text-popover-foreground'

      # Enhanced, the select stays rendered and keeps its box — it is what the browser anchors a
      # validation bubble to — but it is transparent, unfocusable by pointer, and laid exactly over
      # the control.
      ENHANCED = 'group-data-[enhanced=true]/select:absolute group-data-[enhanced=true]/select:inset-0 ' \
                 'group-data-[enhanced=true]/select:h-full group-data-[enhanced=true]/select:w-full ' \
                 'group-data-[enhanced=true]/select:opacity-0 ' \
                 'group-data-[enhanced=true]/select:pointer-events-none'

      # Select-only mode keeps the platform picker on a touch screen (ui-select open-questions.md),
      # and the browser makes that swap itself, live: the combobox is display:none wherever the
      # primary pointer is coarse, and the select gives up its box only wherever it isn't. The two
      # media queries are exact complements, so exactly one control is ever the visible one.
      # ui--select flips what CSS can't reach: the select's aria-hidden and tabindex.
      TOUCH_CONTROL = 'pointer-coarse:hidden'
      TOUCH_ENHANCED = 'group-data-[enhanced=true]/select:not-pointer-coarse:absolute ' \
                       'group-data-[enhanced=true]/select:not-pointer-coarse:inset-0 ' \
                       'group-data-[enhanced=true]/select:not-pointer-coarse:h-full ' \
                       'group-data-[enhanced=true]/select:not-pointer-coarse:w-full ' \
                       'group-data-[enhanced=true]/select:not-pointer-coarse:opacity-0 ' \
                       'group-data-[enhanced=true]/select:not-pointer-coarse:pointer-events-none'

      # The clear button, in the control's box at the inline-end and before the chevron: a fixed
      # 24×24 target (WCAG 2.5.8), fixed rather than a step of the scale above, because the
      # smallest control is 24px tall itself, so a target that shrank with the step would fall
      # under the floor. No border and no fill, so the focus ring is a flush outline — never a
      # box-shadow, which forced-colors mode drops.
      CLEAR = 'absolute inset-e-7 top-1/2 flex size-6 -translate-y-1/2 items-center justify-center ' \
              'rounded-sm bg-transparent text-muted-foreground transition-colors ' \
              'hover:text-foreground focus-visible:outline-2 focus-visible:outline-ring'

      # The room the control gives that button, taken only while ui--select is showing it, so the
      # label underneath is never run over and never padded for a button that isn't there. A fixed
      # value, like the button and its offset: what has to be cleared doesn't move with the step.
      CLEAR_ROOM = 'group-data-[clearable=true]/select:pe-14'

      POPUP = 'overflow-visible rounded-md border border-border bg-popover text-popover-foreground ' \
              'shadow-md outline-none transition duration-100 ease-out origin-top ' \
              'data-[state=closed]:opacity-0 data-[state=closed]:scale-95 ' \
              'data-[state=closing]:opacity-0 data-[state=closing]:scale-95'

      # The search row, first in the popup: a glyph, the field, and a rule under both. Its height
      # is the list's, not the control's, so it stays put as `size:` moves the trigger — a list's
      # density is its own (ui-control-sizing § Behavior).
      #
      # The field itself has no visible focus treatment (SEARCH_FIELD is outline-none, so the
      # caret is the only cue while it's focused) -- a defect. This draws the focus on the row
      # instead, so the glyph and the field read as one focused thing: an inset outline, never a
      # box-shadow (forced-colors mode drops shadows), so the popup can't clip it, with the
      # popup's own top corner radius so the line's corners match.
      SEARCH_ROW = 'flex h-8 items-center gap-2 rounded-t-md border-b border-border ps-3 pe-2 ' \
                   'has-[:focus-visible]:outline-2 has-[:focus-visible]:-outline-offset-2 ' \
                   'has-[:focus-visible]:outline-ring'
      SEARCH_FIELD = 'h-full w-full min-w-0 bg-transparent text-sm outline-none ' \
                     'placeholder:text-muted-foreground'

      def initialize(size:, search:, native_on_touch:)
        @size = size
        @search = search
        @native_on_touch = native_on_touch
      end

      # The visible control: select-only mode's combobox, or search mode's trigger button.
      def control(caller_class, clear: false)
        [CONTROL, SIZES[@size], (TOUCH_CONTROL if @native_on_touch), (TRIGGER if @search),
         (CLEAR_ROOM if clear), caller_class]
      end

      # The button beside the control that returns it to the prompt. It leaves with the control on
      # a coarse pointer, under the same media query: the platform picker showing there lists the
      # prompt itself (§ Behavior, items 2 and 10).
      def clear_button
        [CLEAR, (TOUCH_CONTROL if @native_on_touch)]
      end

      # The native select, in the same box, which gives it up only where the control is showing.
      def native_select(caller_class)
        [CONTROL, SIZES[@size], NATIVE, @native_on_touch ? TOUCH_ENHANCED : ENHANCED, caller_class]
      end
    end
  end
end
