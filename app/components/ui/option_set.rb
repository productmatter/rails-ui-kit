# frozen_string_literal: true

module Ui
  # One option model, shared by the components that read a Rails option source: Select renders
  # it in two shapes, Choices renders its `items` as real inputs (ui-choices § Behavior, item 3).
  # Select's half: `native_options` goes through
  # Rails' own option helpers, so the <select> is what `collection_select`, `select` or
  # `grouped_collection_select` would have rendered for the same arguments; `items` is the
  # same list normalised for the listbox. They are deliberately two derivations of one
  # source (ui-select § Behavior, item 11), and `select_options_test.rb` holds them equal.
  #
  # Blank and prompt follow Rails' own rules (§ Behavior, item 10), including the blank a
  # required select gets when it has neither: ActionView::Helpers::Tags::Base#add_options
  # and #select_content_tag are what this matches, down to the `label=" "` on an empty
  # blank option and the prompt being dropped once something is selected.
  class OptionSet
    # `object` is the collection element the item came from, and nil for the array, hash and
    # enum sources, which have no object to call a method on. It is what a component's own
    # per-option methods -- Choices' description_method: and icon_method: -- are called with.
    Item = Struct.new(:text, :value, :disabled, :selected, :group, :object, keyword_init: true)

    # The keywords that describe options rather than markup, so a component can split its
    # own keyword arguments from the ones that belong here.
    KEYS = %i[collection options model enum value_method text_method group_method
              group_label_method selected include_blank prompt disabled_values required].freeze

    attr_reader :collection, :options, :model, :enum, :value_method, :text_method,
                :group_method, :group_label_method, :include_blank, :prompt

    # `component` is the class that is reading the options, so an ArgumentError names the
    # component the caller actually wrote rather than whichever one shares this model.
    def initialize(component:, collection: nil, options: nil, model: nil, enum: nil, value_method: nil,
                   text_method: nil, group_method: nil, group_label_method: nil, selected: nil,
                   include_blank: false, prompt: nil, disabled_values: nil, required: false)
      @component = component
      @collection = collection
      @options = options
      @model = model
      @enum = enum
      @value_method = value_method
      @text_method = text_method
      @group_method = group_method
      @group_label_method = group_label_method
      @selected_values = Array.wrap(selected).map(&:to_s)
      @include_blank = include_blank
      @prompt = prompt
      @disabled_values = Array.wrap(disabled_values).map(&:to_s)
      @required = required
      validate!
    end

    # Every option in render order, the blank and the prompt included, because the select
    # holds them too and the listbox has to offer the same choices.
    def items
      @items ||= placeholder_items + source_items
    end

    # `view` is the component itself: a ViewComponent is an ActionView::Base, so Rails'
    # option helpers are already there and this imports nothing.
    def native_options(view)
      view.safe_join([prompt_option(view), blank_option(view), source_options(view)].compact, "\n")
    end

    private

    attr_reader :component, :selected_values, :disabled_values, :required

    def validate!
      given = { collection: collection, options: options, enum: enum }.compact.keys
      raise ArgumentError, source_message(given) unless given.one?

      validate_source!
    end

    def validate_source!
      raise ArgumentError, "#{component}: enum: needs model:" if enum && model.nil?
      return unless collection && (value_method.nil? || text_method.nil?)

      raise ArgumentError, "#{component}: collection: needs value_method: and text_method:"
    end

    def source_message(given)
      "#{component} needs exactly one option source — collection:, options: or enum: — " \
        "got #{given.empty? ? 'none' : given.join(', ')}."
    end

    def source
      return :collection if collection

      options ? :options : :enum
    end

    # --- the normalised list ---

    def placeholder_items
      [(placeholder(prompt_text) if prompt_option?), (placeholder(blank_text) if blank_option?)].compact
    end

    def placeholder(text)
      Item.new(text: text, value: '', disabled: false, selected: false, group: nil, object: nil)
    end

    def source_items
      case source
      when :collection then collection_items
      when :options then option_items
      else pairs_to_items(enum_pairs)
      end
    end

    def collection_items
      return collection.map { |element| item(*pair_from(element), object: element) } unless group_method

      collection.flat_map do |group|
        label = call_on(group, group_label_method).to_s
        call_on(group, group_method).map { |element| item(*pair_from(element), group: label, object: element) }
      end
    end

    def option_items
      return pairs_to_items(options.map { |option| text_and_value(option) }) unless grouped_options?

      group_pairs.flat_map do |label, container|
        container.map { |option| item(*text_and_value(option), group: label.to_s) }
      end
    end

    def pairs_to_items(pairs)
      pairs.map { |text, value| item(text, value) }
    end

    def item(text, value, group: nil, object: nil)
      value = value.to_s
      Item.new(text: text.to_s, value: value, group: group, object: object,
               disabled: disabled_values.include?(value), selected: selected_values.include?(value))
    end

    def pair_from(element)
      [call_on(element, text_method), call_on(element, value_method)]
    end

    # Rails' own value_for_collection: a symbol names a method, a callable is called.
    def call_on(element, method)
      method.respond_to?(:call) ? method.call(element) : element.public_send(method)
    end

    # Rails' own option_text_and_value: a pair is [text, value], anything else is both.
    def text_and_value(option)
      return [option, option] if option.is_a?(String) || !option.respond_to?(:first)

      pair = option.is_a?(Array) ? option.grep_v(Hash) : option
      [pair.first, pair.last]
    end

    # The shape grouped_options_for_select takes: every group is a label paired with its
    # own container of options.
    def grouped_options?
      group_pairs.any? && group_pairs.all? { |pair| pair.is_a?(Array) && pair.size == 2 && pair.last.is_a?(Array) }
    end

    def group_pairs
      @group_pairs ||= options.is_a?(Hash) ? options.to_a : Array(options)
    end

    def enum_pairs
      enum_mapping.keys.map { |key| [model.human_attribute_name("#{enum}.#{key}"), key] }
    end

    # An ActiveRecord enum publishes its mapping under the pluralised attribute name,
    # in declaration order.
    def enum_mapping
      model.public_send(enum.to_s.pluralize)
    end

    # --- the native <option> tags ---

    def source_options(view)
      case source
      when :collection then collection_options(view)
      when :options then container_options(view)
      else view.options_for_select(enum_pairs, select_and_disable)
      end
    end

    def collection_options(view)
      return view.options_from_collection_for_select(collection, value_method, text_method, select_and_disable) unless group_method

      view.option_groups_from_collection_for_select(collection, group_method, group_label_method,
                                                    value_method, text_method, select_and_disable)
    end

    def container_options(view)
      return view.grouped_options_for_select(options, select_and_disable) if grouped_options?

      view.options_for_select(options, select_and_disable)
    end

    def select_and_disable
      { selected: selected_values, disabled: disabled_values }
    end

    def blank_option(view)
      return unless blank_option?

      content = include_blank if include_blank.is_a?(String)
      # Rails renders label=" " on an otherwise empty option, so a screen reader announces
      # a blank choice rather than nothing at all.
      view.content_tag('option', content, value: '', label: (' ' unless content))
    end

    def prompt_option(view)
      return unless prompt_option?

      view.content_tag('option', prompt_text, value: '')
    end

    # Rails' placeholder_required?: a required single select with no prompt gets the blank
    # option whether or not the caller asked for one, so it can start with no value.
    def blank_option?
      return true if include_blank.is_a?(String) || include_blank == true

      required && !prompt
    end

    def blank_text
      include_blank.is_a?(String) ? include_blank : ''
    end

    # A prompt is a placeholder, so it renders only while nothing is selected.
    def prompt_option?
      prompt.present? && selected_values.all?(&:empty?)
    end

    def prompt_text
      return prompt if prompt.is_a?(String)

      I18n.t('helpers.select.prompt', default: 'Please select')
    end
  end
end
