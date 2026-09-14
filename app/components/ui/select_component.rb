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
    CONTROL_CLASSES = 'flex w-full min-w-0 appearance-none items-center rounded-md border border-input ' \
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

    # The control's height at each step of the shared size scale, read from the same tokens as
    # Button, Input and Textarea (ui-control-sizing). Not a class_variants axis: variants render
    # onto this component's root, and the height belongs on the control and the show-options
    # button, which are not the root.
    SIZE_CLASSES = {
      sm: 'h-(--control-height-sm)',
      default: 'h-(--control-height)',
      lg: 'h-(--control-height-lg)'
    }.freeze

    class_variants(base: 'group/select relative w-full')

    attr_reader :name, :control_id, :option_set, :size, :primitives

    def initialize(name:, id: nil, required: false, disabled: false, form: nil, autofocus: false,
                   search: false, native_on_touch: true, size: :default, **attributes)
      @name = name.to_s
      @control_id = (id || derive_control_id).to_s
      @required = boolean_attribute?(required)
      @disabled = boolean_attribute?(disabled)
      @autofocus = boolean_attribute?(autofocus)
      @search = boolean_attribute?(search)
      @primitives = Ui::Select::Primitives.new(search: @search, native_on_touch: boolean_attribute?(native_on_touch))
      @size = resolve_size(size)
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

    def empty_id
      "#{control_id}-empty"
    end

    def status_id
      "#{control_id}-status"
    end

    def show_options_label
      I18n.t('rails_ui_kit.select.show_options')
    end

    def no_results_text
      I18n.t('rails_ui_kit.select.no_results')
    end

    # The same chevron in both modes: decorative in select-only, inside the show-options button
    # when searching.
    def render_chevron
      attributes = { class: 'size-4', viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor',
                     'stroke-width': 2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round',
                     aria: { hidden: true } }

      tag.svg(tag.path(d: 'm6 9 6 6 6-6'), **attributes)
    end

    # What makes this a form control, plus the aria the control carries wherever it renders.
    def select_attributes
      {
        id: control_id, name: name, required: @required, disabled: @disabled,
        form: @form, autofocus: @autofocus, class: select_class, aria: @control_aria.presence,
        data: { 'ui--select-target': 'select' }
      }.compact
    end

    # `hidden` is what keeps the combobox out of the unenhanced page; everything else is the
    # same in both modes except the element itself, which is a text field when searching.
    def combobox_attributes
      shared = {
        id: combobox_id, hidden: true, role: 'combobox', class: control_class,
        aria: { controls: listbox_id, expanded: 'false', required: @required.presence }.merge(@control_aria),
        data: { 'ui--select-target': 'combobox', 'ui--overlay-target': 'trigger',
                'ui--anchor-target': 'anchor', 'ui--roving-focus-target': 'input',
                action: primitives.combobox_actions }
      }
      return shared.merge(tabindex: 0) unless search?

      # No name, so the text field never submits: the select next to it is what posts.
      shared.deep_merge(type: 'text', autocomplete: 'off', aria: { autocomplete: 'list' })
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
      MERGER.merge([CONTROL_CLASSES, SIZE_CLASSES[size], caller_class].compact.join(' '))
    end

    def select_class
      MERGER.merge([CONTROL_CLASSES, SIZE_CLASSES[size], NATIVE_CLASSES, ENHANCED_CLASSES, caller_class].compact.join(' '))
    end

    # Spans the control's height at every step, so the chevron stays centred in the field.
    def show_options_class
      "absolute right-0 top-0 flex #{SIZE_CLASSES[size]} w-8 items-center justify-center text-muted-foreground"
    end

    # Variant classes only: the caller's class went to the control.
    def root_class
      self.class.variants.render.presence
    end

    private

    # An unknown size fails exactly as an unknown variant does on every other component, through
    # Ui::Base's own handling: raised in development and test, the default elsewhere.
    def resolve_size(value)
      key = (value.presence || :default).to_sym
      SIZE_CLASSES.key?(key) ? key : (unknown_variant(:size, value, SIZE_CLASSES.keys) || :default)
    end

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
