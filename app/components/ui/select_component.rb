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
    include Ui::Chrome

    data_slot 'select'

    # The aria that describes or names the control itself follows it onto whichever element is
    # playing that part, because the select and the combobox are one control in two renderings.
    # Every other aria and data attribute the caller passes stays on the root, which is where
    # the select's change events bubble to (§ Behavior, item 12).
    CONTROL_ARIA = %i[describedby invalid label labelledby].freeze

    class_variants(base: 'group/select relative w-full')

    # The three strings Select says in its own voice; the options themselves are the caller's
    # content, translated by the host (ui-localization § Behavior, items 1 and 2).
    chrome_string :search_placeholder, key: 'select.search_placeholder'
    chrome_string :no_results, key: 'select.no_results'
    chrome_plural :results, key: 'select.results'

    attr_reader :name, :control_id, :option_set, :size, :primitives, :box

    def initialize(name:, id: nil, required: false, disabled: false, form: nil, autofocus: false,
                   search: false, native_on_touch: true, size: :default,
                   search_placeholder: nil, no_results: nil, results: nil, **attributes)
      assign_chrome(search_placeholder, no_results, results)
      @name = name.to_s
      @control_id = (id || derive_control_id).to_s
      assign_flags(required: required, disabled: disabled, autofocus: autofocus, search: search,
                   native_on_touch: native_on_touch)
      @size = resolve_size(size)
      @box = Ui::Select::Box.new(size: @size, search: @search, native_on_touch: primitives.native_on_touch?)
      @form = form
      @option_set = Ui::OptionSet.new(component: self.class.name, **option_keywords(attributes))
      super(**attributes)
      extract_control_aria!
    end

    def search?
      @search
    end

    def native_options
      option_set.native_options(self)
    end

    # Every part is named after the control, so the ids a re-render produces are the ids the
    # previous one produced and aria-controls keeps resolving (Ui::Select::ListboxComponent
    # derives the listbox's the same way). `combobox` is select-only mode's control; `trigger` and
    # `search` are search mode's two elements, one for each job (§ Behavior, item 17).
    %i[listbox combobox trigger search popup empty status].each do |part|
      define_method(:"#{part}_id") { "#{control_id}-#{part}" }
    end

    # The same decorative chevron in both modes: the control is one box, whichever element plays it.
    def render_chevron
      render_glyph(tag.path(d: 'm6 9 6 6 6-6'))
    end

    # The search row's glyph, which is what says "this field filters" without a second label.
    def render_search_glyph
      render_glyph(safe_join([tag.circle(cx: 11, cy: 11, r: 8), tag.path(d: 'm21 21-4.3-4.3')]),
                   css: 'size-4 shrink-0 text-muted-foreground')
    end

    # What makes this a form control, plus the aria the control carries wherever it renders.
    def select_attributes
      {
        id: control_id, name: name, required: @required, disabled: @disabled,
        form: @form, autofocus: @autofocus, class: select_class, aria: @control_aria.presence,
        data: { 'ui--select-target': 'select' }
      }.compact
    end

    # Select-only mode's control: the combobox itself, a div that owns the listbox and keeps DOM
    # focus throughout (§ Behavior, item 16). `hidden` is what keeps it out of the unenhanced page.
    def combobox_attributes
      {
        id: combobox_id, hidden: true, role: 'combobox', class: control_class,
        aria: { controls: listbox_id, expanded: 'false', required: @required.presence }.merge(@control_aria),
        data: { 'ui--select-target': 'combobox', 'ui--overlay-target': 'trigger',
                'ui--anchor-target': 'anchor', 'ui--roving-focus-target': 'input',
                action: primitives.control_actions },
        tabindex: 0
      }
    end

    # Search mode's control: a button in the same box, showing the value. It is not the combobox —
    # the field in its popup is — so it is named with aria-haspopup and never carries
    # aria-activedescendant. `type="button"` is what keeps Enter from submitting (§ Behavior,
    # item 17).
    #
    # aria-required is not on it, and can't be: ARIA doesn't allow the attribute on `button`, and a
    # browser drops it rather than announcing it. It goes on the search field instead, which is the
    # combobox and the element the user is on while choosing (see search_attributes).
    def trigger_attributes
      {
        id: trigger_id, type: 'button', hidden: true, class: control_class,
        aria: { haspopup: 'listbox', controls: listbox_id, expanded: 'false' }.merge(@control_aria),
        data: { 'ui--select-target': 'trigger', 'ui--overlay-target': 'trigger',
                'ui--anchor-target': 'anchor', action: primitives.control_actions }
      }
    end

    # The only role="combobox" in the widget. No name, so it never submits: the select beside it is
    # what posts, and what the user types here is a query, never the value. It carries
    # aria-expanded for the same listbox the trigger does, because the role requires it and
    # because a widget that claims a closed list is open is a lie a screen reader acts on;
    # ui--select keeps it in step, since this field is not ui--overlay's trigger.
    def search_attributes
      {
        id: search_id, type: 'text', role: 'combobox', autocomplete: 'off',
        placeholder: search_placeholder, class: Ui::Select::Box::SEARCH_FIELD,
        aria: { autocomplete: 'list', controls: listbox_id, expanded: 'false',
                required: @required.presence }.merge(@control_aria.slice(:label, :labelledby)),
        data: { 'ui--select-target': 'search', 'ui--roving-focus-target': 'input',
                action: primitives.search_actions }
      }
    end

    # The count is only known once the filter runs, so the forms and the locale that produced
    # them go over and ui--select picks one (ui-localization § Behavior, items 6 and 7). Only
    # search mode announces a count.
    def results_data
      return {} unless search?

      { 'ui--select-results-value': results.to_json, 'ui--select-locale-value': chrome_locale }
    end

    def popup_attributes
      {
        id: popup_id, hidden: true, class: Ui::Select::Box::POPUP,
        data: { 'ui--select-target': 'popup', 'ui--overlay-target': 'content',
                'ui--anchor-target': 'floating' }
      }
    end

    # The caller's `class:` merges onto the visible control, as it does for Input
    # (ui-component-library § Business rules, rule 5) — both renderings of it, since they are
    # the same box.
    def control_class
      merge_box(box.control(caller_class))
    end

    def select_class
      merge_box(box.native_select(caller_class))
    end

    def search_row_class
      Ui::Select::Box::SEARCH_ROW
    end

    # Variant classes only: the caller's class went to the control.
    def root_class
      self.class.variants.render.presence
    end

    private

    def merge_box(classes)
      MERGER.merge(classes.compact.join(' '))
    end

    # One 24×24 line glyph, drawn the way every other icon in the kit is.
    def render_glyph(paths, css: 'size-4')
      attributes = { class: css, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor',
                     'stroke-width': 2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round',
                     aria: { hidden: true } }

      tag.svg(paths, **attributes)
    end

    # The strings Select says in its own voice, each falling through to the locale file when the
    # call site leaves it out (ui-localization § Behavior, item 2).
    def assign_chrome(search_placeholder, no_results, results)
      @search_placeholder = search_placeholder
      @no_results = no_results
      @results = results
    end

    # Every boolean a caller may spell as a string, and the primitive configuration two of them
    # decide (ui-select § Behavior, items 2 and 17).
    def assign_flags(required:, disabled:, autofocus:, search:, native_on_touch:)
      @required = boolean_attribute?(required)
      @disabled = boolean_attribute?(disabled)
      @autofocus = boolean_attribute?(autofocus)
      @search = boolean_attribute?(search)
      @primitives = Ui::Select::Primitives.new(search: @search,
                                               native_on_touch: boolean_attribute?(native_on_touch))
    end

    # An unknown size fails exactly as an unknown variant does on every other component, through
    # Ui::Base's own handling: raised in development and test, the default elsewhere.
    def resolve_size(value)
      key = (value.presence || :default).to_sym
      sizes = Ui::Select::Box::SIZES
      sizes.key?(key) ? key : (unknown_variant(:size, value, sizes.keys) || :default)
    end

    def option_keywords(attributes)
      attributes.extract!(*Ui::OptionSet::KEYS).merge(required: @required)
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
