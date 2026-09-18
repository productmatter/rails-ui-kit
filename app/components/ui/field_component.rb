# frozen_string_literal: true

module Ui
  # Wires a label, a control, optional description text and optional error text into
  # one accessible unit. The caller supplies a name and, when the record is invalid,
  # its messages; every id — the control's, the label's, the description's, the
  # error's — is derived from the name here, so no id is ever written twice.
  #
  # Or the caller supplies the record: `model: @user, attribute: :email` derives the name,
  # the errors, the label text, the value and `required` from it (Ui::Field::ModelBinding).
  # Anything the caller states instead wins, one value at a time.
  #
  # Ids are handed down two ways. The description is a lambda slot, so the field stamps
  # `id=` on it as it is set and the caller's `class:` and attributes still merge on top.
  # The label and control cannot be built that early: the label's required marker and the
  # control's `aria-describedby` depend on parts the block may set later. So their slots
  # record what to build, and Ui::Field::LabelComponent and Ui::Field::ControlComponent
  # build it during render, by which time every part is known whatever order the caller
  # used.
  class FieldComponent < Ui::Base
    include Ui::Chrome

    # Distinguishes `model: nil`, which is a bug worth raising on, from no model at all.
    NO_MODEL = Object.new.freeze

    data_slot 'field'

    class_variants(base: 'grid gap-2')

    # Said only inside the hidden span search mode's Select trigger names itself with
    # (Ui::Field::LabelComponent); every other required control states "required" itself.
    chrome_string :required_label, key: 'field.required_label'

    # The character counter's three strings. Rendered here rather than by Textarea, because
    # Field is what actually draws the count (the description part) and the status region --
    # the same reason `required_label` above lives here rather than on Select
    # (ui-character-counter § Behavior, items 10-11).
    chrome_string :count, key: 'character_counter.count'
    chrome_plural :remaining, key: 'character_counter.remaining'
    chrome_plural :over, key: 'character_counter.over'

    renders_one :label, ->(**attributes) { Ui::Field::LabelComponent.new(field: self, **attributes) }

    # An invalid field's description gives way to its error. It stays in the DOM, hidden:
    # aria-describedby still names it, and ui--field animates it back when a morph makes
    # the field valid. When the bound control asked for a character counter, the count rides
    # along as the description's last child (ui-character-counter § Behavior, item 4).
    renders_one :description, ->(**attributes) { build_description(**attributes) }

    # The control is any component that takes HTML attributes — Ui::InputComponent by
    # default, or a textarea, select or other custom control through the block form.
    renders_one :control, lambda { |component = Ui::InputComponent, **attributes|
      Ui::Field::ControlComponent.new(field: self, component: component, **attributes)
    }

    attr_reader :name, :control_id, :errors

    # `errors` takes a plain array of messages — `@user.errors[:email]` from an
    # ActiveModel object, or any array — so nothing here depends on an ORM. The
    # HTML `name` (`user[email]`) is not the model attribute (`email`).
    def initialize(name: nil, errors: nil, control_id: nil, model: NO_MODEL, attribute: nil, required: nil,
                   required_label: nil, count: nil, remaining: nil, over: nil, **html_attributes)
      @model_binding = bind(model, attribute, name)
      @name = (name || field_name(@model_binding.param_key, @model_binding.attribute)).to_s
      @errors = Array(errors.nil? ? @model_binding&.errors : errors).map(&:to_s).reject(&:empty?)
      @control_id = (control_id || derive_control_id).to_s
      @required = required
      @required_label = required_label
      @count = count
      @remaining = remaining
      @over = over
      super(**html_attributes)
    end

    # A control that isn't a labelable element, such as a `div role="combobox"`, can't be
    # named by `for=`, so it points `aria-labelledby` here instead.
    def label_id
      "#{control_id}-label"
    end

    # Whether the label may name the control with `for`. A control component says so for itself;
    # a block-form control, which the field knows nothing about, is taken as labelable.
    def labelable_control?
      control.nil? || control.labelable?
    end

    def description_id
      "#{control_id}-description"
    end

    def error_id
      "#{control_id}-error"
    end

    # The polite status region ui--character-count announces the three thresholds into
    # (ui-character-counter § Behavior, item 10). Only rendered, and only ever targeted, when
    # counter? is true.
    def status_id
      "#{control_id}-status"
    end

    def invalid?
      errors.any?
    end

    def model_bound?
      !@model_binding.nil?
    end

    # One value for the label's marker, the wrapper's data-required and the control's
    # required: a `required:` given to with_control, else the field's, else the model's.
    def required?
      stated = [control&.stated_required, @required].find { |value| !value.nil? }
      stated.nil? ? model_bound? && @model_binding.required? : boolean_attribute?(stated)
    end

    # The label text form.label would render for the record, or nil without one.
    def label_text
      @model_binding&.label_text
    end

    # The value form.text_field would render for the record, or nil without one.
    def value
      @model_binding&.value
    end

    # Whether the bound control asked for a character counter, and its limit -- read straight
    # off with_control's raw attributes (Ui::Field::ControlComponent#stated_counter/stated_limit),
    # the same way required? reads stated_required, so nothing here has to build the control
    # early to find out.
    def counter?
      control? && boolean_attribute?(control.stated_counter)
    end

    def counter_limit
      control&.stated_limit&.to_i
    end

    # Code points, as Ruby's own String#length counts them (ui-character-counter § Behavior,
    # item 6).
    #
    # **Correction, verified in this repo's Rails/Turbo/Rack versions:** § Behavior, item 7
    # and § Assumptions expected the browser to submit CRLF for every LF a textarea's value
    # carries, so a line break would reach `validates length:` as two characters. Posting a
    # value with a line break through the Character Counter docs demo (a Turbo-intercepted
    # form, submitted as `FormData` over `fetch`) shows Rails receiving it as one -- the
    # `params` length equals the DOM value's own length, with no CRLF expansion. The
    # assumption's own escape hatch applies: follow what Rails actually does. Counting a line
    # break as one, not two, is what keeps this agreeing with the server (§ Business rules,
    # rule 2), which is the rule that actually matters; § Behavior items 6-7 are superseded by
    # this correction, not by a v2 of the counter.
    def character_count
      value.to_s.length
    end

    def character_over_limit?
      character_count > counter_limit
    end

    # The visible "N / limit" text, from the chrome template so a locale can change the
    # separator without a kit change (ui-character-counter § Behavior, item 11).
    def counter_text
      format(count, { count: character_count, limit: counter_limit })
    end

    # The bound record's class, for a control that infers model: from an enum: it was given
    # with no model: (Ui::Field::ControlComponent), or nil without a model-bound Field.
    def model_class
      @model_binding&.record&.class
    end

    # The attribute a model-bound Field edits, or nil without one -- what a control with no
    # option source at all checks against the record class's enums for silent enum: inference.
    def bound_attribute
      @model_binding&.attribute
    end

    # The control's own attributes, resolved at render time and merged with whatever
    # the caller passed to `with_control`, which wins on conflict. `required` is the one
    # exception: it is always the resolved value, so the control can't disagree with
    # the label and the wrapper.
    def control_attributes(**overrides)
      attributes = { id: control_id, name: name }
      aria = { describedby: described_by, invalid: (true if invalid?) }.compact
      attributes[:aria] = aria if aria.any?

      merge_attributes(attributes, normalize_attributes(overrides)).except(:required).merge(required? ? { required: true } : {})
    end

    private

    def bind(model, attribute, name)
      return Ui::Field::ModelBinding.new(model, attribute) unless model.equal?(NO_MODEL)
      raise ArgumentError, "Ui::FieldComponent's attribute: needs model:, the record it belongs to." unless attribute.nil?
      raise ArgumentError, 'Ui::FieldComponent needs name: (an HTML name such as "user[email]"), or model: with attribute:.' if name.nil?

      nil
    end

    def wrapper_attributes
      controllers = ['ui--field', ('ui--character-count' if counter?)].compact.join(' ')
      root_attributes(data: { controller: controllers, invalid: (true if invalid?),
                              required: (true if required?) }.merge(character_counter_data))
    end

    # The Stimulus values ui--character-count reads off the wrapper it connects on -- the same
    # shape select.results reaches ui--select in (ui-character-counter § Behavior, items 10-11):
    # the whole plural map for each announcement, and the locale that resolved them, so the
    # browser picks a category with Intl.PluralRules once the count is known.
    def character_counter_data
      return {} unless counter?

      { 'ui--character-count-limit-value': counter_limit, 'ui--character-count-format-value': count,
        'ui--character-count-remaining-value': remaining.to_json, 'ui--character-count-over-value': over.to_json,
        'ui--character-count-locale-value': chrome_locale }
    end

    # With a record, a Field the caller gave no label or control still renders both.
    def label_part
      return label if label?

      render(Ui::Field::LabelComponent.new(field: self)) if model_bound?
    end

    def control_part
      return control if control?

      render(Ui::Field::ControlComponent.new(field: self)) if model_bound?
    end

    # The description part, rendered even without with_description when the control asked for
    # a counter: help text is optional, but the count still needs somewhere to live
    # (ui-character-counter § Behavior, item 4).
    def description_part
      return description if description?
      return render(build_description) if counter?

      nil
    end

    # `field: self` is what lets Ui::Field::DescriptionComponent read the counter's state lazily,
    # inside its own `call` rather than here: this method runs the instant with_description is
    # called, which renders_one's lambda can do before with_control ever runs, so counter? has
    # to be asked later, not now (see the comment atop Ui::Field::DescriptionComponent).
    def build_description(**attributes)
      Ui::Field::DescriptionComponent.new(field: self, id: description_id, **(invalid? ? { hidden: true } : {}), **attributes)
    end

    # Only the parts that actually render are named, in reading order. A counter with no
    # description still renders the description part (above), so it is still named here.
    def described_by
      [(description_id if description? || counter?), (error_id if invalid?)].compact.join(' ').presence
    end

    # Rails' own id derivation, so `user[email]` yields the `user_email` that
    # `form_with` would have produced for the same field.
    def derive_control_id
      name.delete(']').tr('^-a-zA-Z0-9:.', '_')
    end
  end
end
