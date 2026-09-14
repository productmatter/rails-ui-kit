# frozen_string_literal: true

module Ui
  # Wires a label, a control, optional description text and optional error text into
  # one accessible unit. The caller supplies a name and, when the record is invalid,
  # its messages; every id — the control's, the description's, the error's — is
  # derived from the name here, so no id is ever written twice.
  #
  # Ids are handed down two ways. The label and description are lambda slots, so the
  # field stamps `for=` and `id=` on them as they are set and the caller's `class:`
  # and attributes still merge on top. The control cannot be built that early: its
  # `aria-describedby` has to name only the parts that exist, and the block may set
  # the description after the control. So `with_control` records what to build and
  # Ui::Field::ControlComponent builds it during render, by which time every part is
  # known and the list is exact whatever order the caller used.
  class FieldComponent < Ui::Base
    data_slot 'field'

    class_variants(base: 'grid gap-2')

    renders_one :label, ->(**attributes) { Ui::LabelComponent.new(for: control_id, **attributes) }

    renders_one :description, lambda { |**attributes|
      Ui::Field::DescriptionComponent.new(id: description_id, **attributes)
    }

    # The control is any component that takes HTML attributes — Ui::InputComponent by
    # default, or a textarea, select or other custom control through the block form.
    renders_one :control, lambda { |component = Ui::InputComponent, **attributes|
      Ui::Field::ControlComponent.new(field: self, component: component, **attributes)
    }

    attr_reader :name, :control_id, :errors

    # `errors` takes a plain array of messages — `@user.errors[:email]` from an
    # ActiveModel object, or any array — so nothing here depends on ActiveRecord. The
    # HTML `name` (`user[email]`) is not the model attribute (`email`); a form builder
    # holding both passes `object.errors[method]` here.
    def initialize(name:, errors: nil, control_id: nil, **html_attributes)
      @name = name.to_s
      @errors = Array(errors).map(&:to_s).reject(&:empty?)
      @control_id = (control_id || derive_control_id).to_s
      super(**html_attributes)
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

    # The control's own attributes, resolved at render time and merged with whatever
    # the caller passed to `with_control`, which wins on conflict.
    def control_attributes(**overrides)
      attributes = { id: control_id, name: name }
      aria = { describedby: described_by, invalid: (true if invalid?) }.compact
      attributes[:aria] = aria if aria.any?

      merge_attributes(attributes, overrides)
    end

    private

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
