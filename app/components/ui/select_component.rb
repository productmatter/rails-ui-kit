# frozen_string_literal: true

module Ui
  # A select built from a Rails collection. The real <select> is the only place the value
  # lives (ui-select § Business rules, rule 1): it carries the id, name, required, disabled
  # and form attributes, it is what submits, validates and resets, and everything the user
  # sees is derived from it.
  #
  # Server-rendered, that select is the visible control, styled as the kit's form control
  # with a decorative chevron — which is also the state a page keeps when JavaScript never
  # arrives (§ Behavior, item 2).
  class SelectComponent < Ui::Base
    data_slot 'select'

    # The visible control's box. The combobox that takes over once enhanced uses the same
    # list, so the swap between them shifts nothing.
    CONTROL_CLASSES = 'flex h-9 w-full min-w-0 appearance-none items-center rounded-md border border-input ' \
                      'bg-transparent dark:bg-muted/50 pl-3 pr-8 text-sm shadow-xs transition-colors ' \
                      'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring ' \
                      'disabled:pointer-events-none disabled:opacity-50 ' \
                      'aria-invalid:border-destructive aria-invalid:focus-visible:outline-destructive ' \
                      '[&_option]:bg-popover [&_option]:text-popover-foreground ' \
                      '[&_optgroup]:bg-popover [&_optgroup]:text-popover-foreground'

    # aria-describedby and aria-invalid describe the control itself, so they follow it onto
    # whichever element is playing that part. Every other aria and data attribute the caller
    # passes stays on the root, which is where the select's change events bubble to
    # (§ Behavior, item 12).
    CONTROL_ARIA = %i[describedby invalid].freeze

    class_variants(base: 'relative w-full')

    attr_reader :name, :control_id, :option_set

    def initialize(name:, id: nil, required: false, disabled: false, form: nil, autofocus: false,
                   search: false, **attributes)
      @name = name.to_s
      @control_id = (id || derive_control_id).to_s
      @required = boolean_attribute?(required)
      @disabled = boolean_attribute?(disabled)
      @autofocus = boolean_attribute?(autofocus)
      @search = boolean_attribute?(search)
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

    # What makes this a form control, plus the aria the control carries wherever it renders.
    def select_attributes
      {
        id: control_id, name: name, required: @required, disabled: @disabled,
        form: @form, autofocus: @autofocus, class: control_class, aria: @control_aria.presence
      }.compact
    end

    # The caller's `class:` merges onto the visible control, as it does for Input
    # (ui-component-library § Business rules, rule 5), not onto the positioning wrapper.
    def control_class
      MERGER.merge([CONTROL_CLASSES, caller_class].compact.join(' '))
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
