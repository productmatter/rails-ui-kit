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
      # The control's height at each step of the shared size scale, read from the same tokens as
      # Button, Input and Textarea (ui-control-sizing). Not a class_variants axis: variants render
      # onto the component's root, and the height belongs on the control, which is not the root.
      SIZES = {
        sm: 'h-(--control-height-sm)',
        default: 'h-(--control-height)',
        lg: 'h-(--control-height-lg)'
      }.freeze

      # The visible control's box, shared by the select and whatever takes over from it. Filled in
      # both modes, as Input is, so it reads as a control on any surface; the popup is bg-popover,
      # a different token, so the open list never blends into the box it hangs from.
      CONTROL = 'flex w-full min-w-0 appearance-none items-center rounded-md border border-input ' \
                'bg-background dark:bg-muted/50 ps-3 pe-8 text-sm shadow-xs transition-colors ' \
                'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring ' \
                'disabled:pointer-events-none disabled:opacity-50 ' \
                'aria-disabled:pointer-events-none aria-disabled:opacity-50 ' \
                'aria-invalid:border-destructive aria-invalid:focus-visible:outline-destructive'

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

      POPUP = 'overflow-visible rounded-md border border-border bg-popover text-popover-foreground ' \
              'shadow-md outline-none transition duration-100 ease-out origin-top ' \
              'data-[state=closed]:opacity-0 data-[state=closed]:scale-95 ' \
              'data-[state=closing]:opacity-0 data-[state=closing]:scale-95'

      # The search row, first in the popup: a glyph, the field, and a rule under both. Its height
      # is the list's, not the control's, so it stays put as `size:` moves the trigger — a list's
      # density is its own (ui-control-sizing § Behavior).
      SEARCH_ROW = 'flex h-9 items-center gap-2 border-b border-border ps-3 pe-2'
      SEARCH_FIELD = 'h-full w-full min-w-0 bg-transparent text-sm outline-none ' \
                     'placeholder:text-muted-foreground'

      def initialize(size:, search:, native_on_touch:)
        @size = size
        @search = search
        @native_on_touch = native_on_touch
      end

      # The visible control: select-only mode's combobox, or search mode's trigger button.
      def control(caller_class)
        [CONTROL, SIZES[@size], (TOUCH_CONTROL if @native_on_touch), (TRIGGER if @search), caller_class]
      end

      # The native select, in the same box, which gives it up only where the control is showing.
      def native_select(caller_class)
        [CONTROL, SIZES[@size], NATIVE, @native_on_touch ? TOUCH_ENHANCED : ENHANCED, caller_class]
      end
    end
  end
end
