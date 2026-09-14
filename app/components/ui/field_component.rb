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
    # Distinguishes `model: nil`, which is a bug worth raising on, from no model at all.
    NO_MODEL = Object.new.freeze

    data_slot 'field'

    class_variants(base: 'grid gap-2')

    renders_one :label, ->(**attributes) { Ui::Field::LabelComponent.new(field: self, **attributes) }

    # An invalid field's description gives way to its error. It stays in the DOM, hidden:
    # aria-describedby still names it, and ui--field animates it back when a morph makes
    # the field valid.
    renders_one :description, lambda { |**attributes|
      Ui::Field::DescriptionComponent.new(id: description_id, **(invalid? ? { hidden: true } : {}), **attributes)
    }

    # The control is any component that takes HTML attributes — Ui::InputComponent by
    # default, or a textarea, select or other custom control through the block form.
    renders_one :control, lambda { |component = Ui::InputComponent, **attributes|
      Ui::Field::ControlComponent.new(field: self, component: component, **attributes)
    }

    attr_reader :name, :control_id, :errors

    # `errors` takes a plain array of messages — `@user.errors[:email]` from an
    # ActiveModel object, or any array — so nothing here depends on an ORM. The
    # HTML `name` (`user[email]`) is not the model attribute (`email`).
    def initialize(name: nil, errors: nil, control_id: nil, model: NO_MODEL, attribute: nil, required: nil, **html_attributes)
      @model_binding = bind(model, attribute, name)
      @name = (name || field_name(@model_binding.param_key, @model_binding.attribute)).to_s
      @errors = Array(errors.nil? ? @model_binding&.errors : errors).map(&:to_s).reject(&:empty?)
      @control_id = (control_id || derive_control_id).to_s
      @required = required
      super(**html_attributes)
    end

    # A control that isn't a labelable element, such as a `div role="combobox"`, can't be
    # named by `for=`, so it points `aria-labelledby` here instead.
    def label_id
      "#{control_id}-label"
    end

    def description_id
      "#{control_id}-description"
    end

    def error_id
      "#{control_id}-error"
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

    # The control's own attributes, resolved at render time and merged with whatever
    # the caller passed to `with_control`, which wins on conflict. `required` is the one
    # exception: it is always the resolved value, so the control can't disagree with
    # the label and the wrapper.
    def control_attributes(**overrides)
      attributes = { id: control_id, name: name }
      aria = { describedby: described_by, invalid: (true if invalid?) }.compact
      attributes[:aria] = aria if aria.any?

      merge_attributes(attributes, overrides).except(:required).merge(required? ? { required: true } : {})
    end

    private

    def bind(model, attribute, name)
      return Ui::Field::ModelBinding.new(model, attribute) unless model.equal?(NO_MODEL)
      raise ArgumentError, "Ui::FieldComponent's attribute: needs model:, the record it belongs to." unless attribute.nil?
      raise ArgumentError, 'Ui::FieldComponent needs name: (an HTML name such as "user[email]"), or model: with attribute:.' if name.nil?

      nil
    end

    # ui--field is joined with a caller's own controllers rather than replaced by them.
    def wrapper_attributes
      attributes = root_attributes(data: { invalid: (true if invalid?), required: (true if required?) })
      controllers = ['ui--field', *attributes[:data][:controller].to_s.split].uniq.join(' ')
      attributes.merge(data: attributes[:data].merge(controller: controllers))
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

    # Only the parts that actually render are named, in reading order.
    def described_by
      [(description_id if description?), (error_id if invalid?)].compact.join(' ').presence
    end

    # Rails' own id derivation, so `user[email]` yields the `user_email` that
    # `form_with` would have produced for the same field.
    def derive_control_id
      name.delete(']').tr('^-a-zA-Z0-9:.', '_')
    end
  end
end
