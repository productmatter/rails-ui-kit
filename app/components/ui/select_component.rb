# frozen_string_literal: true

module Ui
  # A select built from a Rails collection. The real <select> is the only place the value
  # lives (ui-select § Business rules, rule 1): it carries the id, name, required, disabled
  # and form attributes, it is what submits, validates and resets, and everything the user
  # sees is derived from it.
  #
  # Server-rendered, that select is the visible control, styled as the kit's form control
  # with a decorative chevron — which is also the state a page keeps when JavaScript never
  # arrives (§ Behavior, item 2). Once `ui--select` connects, the combobox takes over the
  # same box and the select is laid over it, transparent and out of the accessibility tree.
  class SelectComponent < Ui::Base
    data_slot 'select'

    # The visible control's box, shared by the select and the combobox that takes over from
    # it, so the swap between them shifts nothing.
    CONTROL_CLASSES = 'flex h-9 w-full min-w-0 appearance-none items-center rounded-md border border-input ' \
                      'bg-transparent dark:bg-muted/50 pl-3 pr-8 text-sm shadow-xs transition-colors ' \
                      'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring ' \
                      'disabled:pointer-events-none disabled:opacity-50 ' \
                      'aria-disabled:pointer-events-none aria-disabled:opacity-50 ' \
                      'aria-invalid:border-destructive aria-invalid:focus-visible:outline-destructive'

    # Native <option>s don't inherit the select's classes, so the popup colours reach them
    # through a descendant selector rather than by asking the caller to class each one.
    NATIVE_CLASSES = '[&_option]:bg-popover [&_option]:text-popover-foreground ' \
                     '[&_optgroup]:bg-popover [&_optgroup]:text-popover-foreground'

    # Enhanced, the select stays rendered and keeps its box — it is what the browser anchors a
    # validation bubble to — but it is transparent, unfocusable by pointer, and laid exactly
    # over the combobox.
    ENHANCED_CLASSES = 'group-data-[enhanced=true]/select:absolute group-data-[enhanced=true]/select:inset-0 ' \
                       'group-data-[enhanced=true]/select:h-full group-data-[enhanced=true]/select:w-full ' \
                       'group-data-[enhanced=true]/select:opacity-0 ' \
                       'group-data-[enhanced=true]/select:pointer-events-none'

    POPUP_CLASSES = 'overflow-visible rounded-md border border-border bg-popover text-popover-foreground ' \
                    'shadow-md outline-none transition duration-100 ease-out origin-top ' \
                    'data-[state=closed]:opacity-0 data-[state=closed]:scale-95 ' \
                    'data-[state=closing]:opacity-0 data-[state=closing]:scale-95'

    # The aria that describes or names the control itself follows it onto whichever element is
    # playing that part, because the select and the combobox are one control in two renderings.
    # Every other aria and data attribute the caller passes stays on the root, which is where
    # the select's change events bubble to (§ Behavior, item 12).
    CONTROL_ARIA = %i[describedby invalid label labelledby].freeze

    # A page of options is ten, which is what the APG select-only combobox example jumps.
    PAGE_STEP = 10

    class_variants(base: 'group/select relative w-full')

    attr_reader :name, :control_id, :option_set

    def initialize(name:, id: nil, required: false, disabled: false, form: nil, autofocus: false,
                   search: false, native_on_touch: true, **attributes)
      @name = name.to_s
      @control_id = (id || derive_control_id).to_s
      @required = boolean_attribute?(required)
      @disabled = boolean_attribute?(disabled)
      @autofocus = boolean_attribute?(autofocus)
      @search = boolean_attribute?(search)
      @native_on_touch = boolean_attribute?(native_on_touch)
      @form = form
      @option_set = Ui::Select::OptionSet.new(**option_keywords(attributes))
      super(**attributes)
      extract_control_aria!
    end

    def search?
      @search
    end

    def native_options
      option_set.native_options(self)
    end

    def listbox_id
      "#{control_id}-listbox"
    end

    def combobox_id
      "#{control_id}-combobox"
    end

    # The primitives Select composes. ui--media-query is what tells select-only mode it is on a
    # touch screen, where the platform picker is the better control.
    def root_data
      {
        controller: 'ui--media-query ui--select ui--overlay ui--anchor ui--roving-focus',
        action: 'change->ui--select#render ui--roving-focus:activated->ui--select#markActive ' \
                'ui--overlay:opened->ui--select#opened ui--overlay:closed->ui--select#closed',
        'ui--media-query-query-value': '(pointer: coarse)',
        'ui--select-search-value': search?,
        'ui--select-native-on-touch-value': @native_on_touch
      }.merge(popup_data, navigation_data)
    end

    # A layer in the top layer, anchored under the control and matching its width. It opens
    # without taking focus, because a combobox keeps DOM focus on its own control, and it is
    # positioned against the viewport, because the top layer is.
    def popup_data
      {
        'ui--overlay-mode-value': 'layer',
        'ui--overlay-scroll-lock-value': false,
        'ui--overlay-move-focus-value': false,
        'ui--anchor-placement-value': 'bottom-start',
        'ui--anchor-match-width-value': true,
        'ui--anchor-strategy-value': 'fixed'
      }
    end

    # Each mode's APG example, as primitive values: virtual focus either way, then select-only
    # clamps at the ends and owns typing and the page keys, while search mode wraps and leaves
    # every editing key to its text field.
    def navigation_data
      {
        'ui--roving-focus-focus-model-value': 'activedescendant',
        'ui--roving-focus-loop-value': search?,
        'ui--roving-focus-typeahead-value': !search?,
        'ui--roving-focus-page-step-value': search? ? 0 : PAGE_STEP,
        'ui--roving-focus-active-class': 'bg-accent text-accent-foreground'
      }
    end

    # What makes this a form control, plus the aria the control carries wherever it renders.
    def select_attributes
      {
        id: control_id, name: name, required: @required, disabled: @disabled,
        form: @form, autofocus: @autofocus, class: select_class, aria: @control_aria.presence,
        data: { 'ui--select-target': 'select' }
      }.compact
    end

    # tabindex="0" is written here rather than by the controller so the combobox is operable
    # the instant it is revealed; `hidden` is what keeps it out of the unenhanced page.
    def combobox_attributes
      {
        id: combobox_id, role: 'combobox', tabindex: 0, hidden: true, class: control_class,
        aria: { controls: listbox_id, expanded: 'false' }.merge(@control_aria),
        data: { 'ui--select-target': 'combobox', 'ui--overlay-target': 'trigger',
                'ui--anchor-target': 'anchor', 'ui--roving-focus-target': 'input',
                action: 'click->ui--select#toggle keydown->ui--select#keydown' }
      }
    end

    def popup_attributes
      {
        id: "#{control_id}-popup", hidden: true, class: POPUP_CLASSES,
        data: { 'ui--select-target': 'popup', 'ui--overlay-target': 'content',
                'ui--anchor-target': 'floating' }
      }
    end

    # The caller's `class:` merges onto the visible control, as it does for Input
    # (ui-component-library § Business rules, rule 5) — both renderings of it, since they are
    # the same box.
    def control_class
      MERGER.merge([CONTROL_CLASSES, caller_class].compact.join(' '))
    end

    def select_class
      MERGER.merge([CONTROL_CLASSES, NATIVE_CLASSES, ENHANCED_CLASSES, caller_class].compact.join(' '))
    end

    # Variant classes only: the caller's class went to the control.
    def root_class
      self.class.variants.render.presence
    end

    private

    def option_keywords(attributes)
      attributes.extract!(*Ui::Select::OptionSet::KEYS).merge(required: @required)
    end

    def extract_control_aria!
      aria = html_attributes[:aria] || {}
      @control_aria = aria.slice(*CONTROL_ARIA)
      remaining = aria.except(*CONTROL_ARIA)
      remaining.empty? ? html_attributes.delete(:aria) : html_attributes[:aria] = remaining
    end

    # Rails' own id derivation, the same one Ui::FieldComponent uses, so `post[author_id]`
    # yields the `post_author_id` that form_with would have produced.
    def derive_control_id
      name.delete(']').tr('^-a-zA-Z0-9:.', '_')
    end
  end
end
