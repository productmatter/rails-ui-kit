# frozen_string_literal: true

module Ui
  # The one place toasts appear, rendered once per layout:
  #
  #   <%= render Ui::ToastContainerComponent.new(flash: flash) %>
  #
  # flash: maps Rails' own notice: and alert:, which every scaffold and Devise set, and a toast:
  # payload for anything richer (ui-toast § Behavior, item 3). toasts: takes payloads directly.
  # A Turbo Stream appends into the stack (turbo_stream.ui_toast), and JavaScript clones the
  # templates below (window.triggerToast), so all three render the same markup.
  class ToastContainerComponent < Ui::Base
    data_slot 'toast-container'

    DEFAULT_CLASSES = 'fixed top-4 inset-e-4 z-[70] w-80 max-w-[calc(100vw-2rem)] pointer-events-none'
    STACK_ID = 'ui-toasts'

    # Rails' flash keys and the toast type each becomes. Any other flash key is the host's own.
    FLASH_TYPES = { 'notice' => :notice, 'alert' => :alert }.freeze
    FLASH_PAYLOAD_KEY = 'toast'

    class_variants(base: DEFAULT_CLASSES)

    include Ui::Chrome

    # All four are here because a toast JavaScript creates is a clone of a template this renders,
    # so this is the only place its strings can come from (ui-toast § Behavior, item 16).
    chrome_string :default_title, key: 'toast.default_title'
    chrome_string :close_label, key: 'toast.close_label'
    chrome_string :actions_hint, key: 'toast.actions_hint'
    chrome_string :region_label, key: 'toast.region_label'

    # container_class: adds to the defaults, as class: does (§ Behavior, item 17).
    def initialize(toasts: [], flash: nil, container_class: nil, default_title: nil, close_label: nil,
                   actions_hint: nil, region_label: nil, **html_attributes)
      @payloads = Array(toasts) + flash_payloads(flash)
      @default_title = default_title
      @close_label = close_label
      @actions_hint = actions_hint
      @region_label = region_label
      classes = [container_class, html_attributes.delete(:class)].compact
      super(**html_attributes, **(classes.any? ? { class: classes } : {}))
    end

    def toasts
      @payloads.map { |payload| Ui::ToastComponent.new(message: payload, **chrome) }
    end

    def chrome
      { close_label: close_label, default_title: default_title, actions_hint: actions_hint }
    end

    def template_types
      Ui::ToastComponent::TYPES
    end

    def action_templates
      Ui::Toast::Action.variants.flat_map do |variant|
        %i[link form button].map { |kind| [kind, variant, Ui::Toast::ActionComponent.template(kind, variant)] }
      end
    end

    def container_attributes
      { data: { controller: 'ui--toast-container',
                'ui--toast-container-default-title-value': default_title,
                'ui--toast-container-actions-hint-value': actions_hint,
                'ui--toast-container-strict-value': Ui::Toast::Validation.strict? } }
    end

    private

    def flash_payloads(flash)
      return [] if flash.nil?

      entries = flash.to_hash.transform_keys(&:to_s)
      notices = FLASH_TYPES.filter_map do |key, type|
        { type: type, description: entries[key] } if entries[key].present?
      end
      notices + Array.wrap(entries[FLASH_PAYLOAD_KEY])
    end
  end
end
