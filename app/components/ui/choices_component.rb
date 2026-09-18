# frozen_string_literal: true

module Ui
  # A radio or checkbox group over real inputs. It renders the names, ids, values and hidden
  # empty field `collection_radio_buttons` and `collection_check_boxes` render for the same
  # arguments (ui-choices § Behavior, items 1–5), so unchecking every box clears the attribute
  # instead of silently keeping the old one.
  #
  # The behaviour is the platform's: radios sharing a name already give arrow keys, single
  # selection and `required`; a <label> wrapping the input makes the whole card the target; the
  # checked, focused and disabled styling is CSS. `ui--choices` is attached for one job the
  # browser has no constraint for — "at least one of these checkboxes" (item 14).
  #
  # The group is a <fieldset> named, described and marked invalid through Ui::FieldComponent
  # (item 10): `aria-labelledby` points at the field's label, which for this control renders
  # without `for`, because `for` has to name one labelable element and a group is not one.
  class ChoicesComponent < Ui::Base
    include Ui::Chrome

    data_slot 'choices'

    # A stacking grid by default, so columns are the caller's `class:` and choices stack at phone
    # widths unless they say otherwise. `min-w-0` resets the UA's `min-inline-size: min-content`,
    # which Tailwind's preflight doesn't touch and which otherwise holds a fieldset open at its
    # longest word (§ Behavior, item 18). The named group is what the choices read the invalid
    # state from (item 16).
    class_variants(base: 'group/choices grid min-w-0 gap-2')

    # Rails' option keywords Choices has no rendering for. A blank option, a prompt and groups
    # each mean something in a <select> and nothing here: the collection helpers have no blank
    # option, a "none" choice is one the caller adds, and a group inside a radiogroup would own
    # elements that aren't radios (§ Behavior, item 3).
    REFUSED_KEYS = %i[include_blank prompt group_method group_label_method].freeze

    # The one string Choices says in its own voice: what the visual `*` means on a group the
    # browser can't mark required (§ Behavior, item 14).
    chrome_string :required_message, key: 'choices.required_message'

    # The label's `for` names one labelable element; a group of inputs is not one, so Field's
    # label renders with `id` alone and this fieldset carries `aria-labelledby`.
    def self.labelable?
      false
    end

    attr_reader :name, :control_id, :option_set, :size, :variant, :style

    def initialize(name:, id: nil, multiple: false, checked: nil, disabled_values: nil, include_hidden: true,
                   required: false, disabled: false, form: nil, size: :default, variant: :list,
                   description_method: nil, icon_method: nil, required_message: nil, **attributes)
      @required_message = required_message
      @multiple = boolean_attribute?(multiple)
      assign_names(name, id)
      assign_flags(required: required, disabled: disabled, include_hidden: include_hidden, form: form)
      assign_option_methods(description_method, icon_method)
      @option_set = Ui::OptionSet.new(component: self.class.name, selected: checked,
                                      disabled_values: disabled_values, **option_keywords(attributes))
      assign_style(size, variant)
      super(**attributes)
      extract_described_by!
      validate_items!
    end

    def multiple?
      @multiple
    end

    def items
      option_set.items
    end

    def include_hidden?
      @include_hidden
    end

    # The hint, and with it `ui--choices`, exist only where the browser has no constraint of its
    # own: a required checkbox group. A required radio group is `required` on every radio.
    def required_hint?
      multiple? && @required
    end

    def fieldset_attributes
      root_attributes(id: control_id, role: ('radiogroup' unless multiple?), disabled: @disabled,
                      data: choices_data, aria: { labelledby: labelledby, describedby: described_by }.compact)
    end

    # Rails' own blank entry: what empties an association when the user unchecks everything
    # (§ Behavior, item 5). Disabled with the group, unlike Rails' collection helpers, so a
    # disabled group submits nothing at all (item 12).
    def hidden_field_attributes
      { type: 'hidden', name: name, value: '', form: @form }.compact
    end

    # A value that is checked and locked can't submit through its own disabled input, so it is
    # carried here and the save keeps what the form showed (item 7). Before every input, so a
    # radio the user chooses is the later value and wins.
    def carriers
      items.select { |item| item.selected && item.disabled }
           .map { |item| hidden_field_attributes.merge(value: item.value) }
    end

    def input_attributes(item)
      { type: multiple? ? 'checkbox' : 'radio', id: input_id(item), name: name, value: item.value,
        checked: item.selected, disabled: item.disabled, required: (true if @required && !multiple?),
        form: @form, class: style.input_class, data: input_data, aria: input_aria(item) }.compact
    end

    # Named by its own text and described by its own description line: a wrapping label would
    # otherwise name the input with every word inside it (§ Behavior, item 9).
    def input_aria(item)
      { labelledby: text_id(item), describedby: (description_id(item) if description_for(item)) }.compact
    end

    def input_data
      { 'ui--choices-target': 'checkbox' } if required_hint?
    end

    def description_for(item)
      call_on(item, @description_method)
    end

    def icon_for(item)
      call_on(item, @icon_method)
    end

    def input_id(item)
      "#{control_id}_#{sanitized_value(item.value)}"
    end

    def text_id(item)
      "#{input_id(item)}-label"
    end

    def description_id(item)
      "#{input_id(item)}-description"
    end

    def required_id
      "#{control_id}-required"
    end

    private

    # The id is derived from the name before `[]` is appended, so `user[role_ids]` yields
    # `user_role_ids` and each input `user_role_ids_1`, exactly as Rails would.
    def assign_names(name, id)
      @control_id = (id || derive_control_id(name)).to_s
      @name = group_name(name)
    end

    def assign_option_methods(description_method, icon_method)
      @description_method = description_method
      @icon_method = icon_method
    end

    # An unknown step or variant fails the way an unknown variant does everywhere else.
    def assign_style(size, variant)
      @size = resolve_key(:size, size, Ui::Choices::Variant::SIZES)
      @variant = resolve_key(:variant, variant, Ui::Choices::Variant::VARIANTS)
      @style = Ui::Choices::Variant.new(variant: @variant, multiple: multiple?, described: described?)
    end

    # Whether the group renders a description line at all -- decided once, since every choice in
    # the group shares the same alignment (Ui::Choices::Variant#align_class).
    def described?
      items.any? { |item| description_for(item) }
    end

    def assign_flags(required:, disabled:, include_hidden:, form:)
      @required = boolean_attribute?(required)
      @disabled = boolean_attribute?(disabled)
      @include_hidden = boolean_attribute?(include_hidden)
      @form = form
    end

    # `ui--choices` is attached only where it has a job (§ Business rules, rule 4).
    def choices_data
      return { required: (true if @required) }.compact unless required_hint?

      { required: true, controller: 'ui--choices', action: 'change->ui--choices#derive' }
    end

    # Rails appends `[]` for a multiple select, and `collection_check_boxes` posts an array; a
    # name that already says so is left alone.
    def group_name(name)
      name = name.to_s
      multiple? && !name.end_with?('[]') ? "#{name}[]" : name
    end

    def option_keywords(attributes)
      refused = attributes.keys & REFUSED_KEYS
      raise ArgumentError, refused_message(refused) if refused.any?

      attributes.extract!(*(Ui::OptionSet::KEYS - REFUSED_KEYS - %i[selected disabled_values required]))
    end

    def refused_message(refused)
      "#{self.class.name} has no #{refused.map { |key| "#{key}:" }.join(', ')} — " \
        'a group of real inputs has no blank option, prompt or option groups.'
    end

    # Field hands the group its description and error ids; the required hint is Choices' own, and
    # reads last. Taken off the forwarded attributes so the caller's value is added to rather
    # than replaced.
    def extract_described_by!
      aria = html_attributes[:aria] || {}
      @described_by = aria.delete(:describedby)
      html_attributes.delete(:aria) if aria.empty?
    end

    def described_by
      [@described_by, (required_id if required_hint?)].compact.join(' ').presence
    end

    # Inside a Field the label is `#{control_id}-label`, derived the way Field derives it. A
    # caller who named the group themselves keeps their own name.
    def labelledby
      aria = html_attributes[:aria] || {}
      "#{control_id}-label" unless aria[:label] || aria[:labelledby]
    end

    # A grouped source only shows up once the items are built, and per-option methods need an
    # object to call: both are caller errors rather than a silent half-rendering.
    def validate_items!
      raise ArgumentError, refused_message([:group_method]) if items.any?(&:group)
      return unless (@description_method || @icon_method) && items.all? { |item| item.object.nil? }

      raise ArgumentError,
            "#{self.class.name}: description_method: and icon_method: need collection:, " \
            'because an array, hash or enum source has no object to call them on.'
    end

    def call_on(item, method)
      return if method.nil? || item.object.nil?

      method.respond_to?(:call) ? method.call(item.object) : item.object.public_send(method)
    end

    def resolve_key(axis, value, classes)
      key = (value.presence || :default).to_sym
      return key if classes.key?(key)

      unknown_variant(axis, value, classes.keys) || classes.keys.first
    end

    # ActionView's Tags::Base#sanitized_value, so an id here is the id Rails would have written.
    def sanitized_value(value)
      value.to_s.gsub(/[\s.]/, '_').gsub(/[^-[[:word:]]]/, '').downcase
    end

    # Rails' own id derivation, the same one Ui::FieldComponent and Select use.
    def derive_control_id(name)
      name.to_s.delete(']').tr('^-a-zA-Z0-9:.', '_')
    end
  end
end
