# frozen_string_literal: true

module Ui
  # A toast says what happened, and sometimes offers one thing to do about it (ui-toast).
  #
  #   render Ui::ToastComponent.new(type: :success, message: "Saved")          # the description
  #   render Ui::ToastComponent.new(type: :success, title: "Project archived",
  #     actions: [{ label: "Undo", href: unarchive_project_path(@project), method: "patch" }])
  #   render(Ui::ToastComponent.new(type: :success)) { t(".saved") }           # the description
  #
  # Content given without a name is the description. A Hash is a payload (Ui::Toast::Payload); a
  # Symbol is an I18n key whose translation is either. A String is always text.
  class ToastComponent < Ui::Base
    data_slot 'toast'

    TYPES = Ui::Toast::Payload::TYPES

    # Whole class names, so Tailwind sees them. notice and alert are Rails' flash keys, so they
    # read as Rails means them: notice is "it worked" and alert is the failure (decided
    # 2026-09-15). warning and info are the explicit types for anything else.
    ICON_CLASSES = { success: 'text-success', notice: 'text-success', error: 'text-destructive',
                     alert: 'text-destructive', warning: 'text-warning', info: 'text-info' }.freeze
    BAR_CLASSES = { success: 'bg-success', notice: 'bg-success', error: 'bg-destructive',
                    alert: 'bg-destructive', warning: 'bg-warning', info: 'bg-info' }.freeze
    TRACK_CLASSES = { success: 'bg-success/20', notice: 'bg-success/20', error: 'bg-destructive/20',
                      alert: 'bg-destructive/20', warning: 'bg-warning/20', info: 'bg-info/20' }.freeze

    ICONS = {
      success: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z',
      error: 'M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z',
      notice: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z',
      alert: 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z',
      warning: 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z',
      info: 'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z'
    }.freeze

    # Enter and exit are Primitive D's: data-state drives them, and reduced motion is honoured
    # there. No overflow clipping, so an action label too long for the card stays visible.
    class_variants(
      base: 'relative flex w-full flex-col gap-3 rounded-lg border border-border bg-popover p-4 text-sm ' \
            'text-popover-foreground shadow-lg pointer-events-auto transition-[opacity,translate] duration-300 ' \
            'ease-out data-[state=closed]:translate-y-2 data-[state=closed]:opacity-0 data-[state=closing]:opacity-0'
    )

    include Ui::Chrome

    chrome_string :close_label, key: 'toast.close_label'
    chrome_string :default_title, key: 'toast.default_title'
    chrome_string :actions_hint, key: 'toast.actions_hint'

    renders_one :icon

    PAYLOAD_KEYWORDS = %i[type title description actions duration icon body timeout].freeze

    # A payload from anywhere -- a Turbo Stream, flash, a container's toasts: -- with the chrome
    # strings the caller resolved.
    def self.from_payload(payload, **)
      new(message: payload.is_a?(Hash) ? payload : payload.to_h, **)
    end

    # The blank toast a container renders once per type for JavaScript to clone. Every part is
    # present, and the clone removes the ones a payload leaves out.
    def self.template(type, **chrome)
      new(type: type, id: 'ui-toast-template', **chrome).tap { |toast| toast.instance_variable_set(:@template, true) }
    end

    def initialize(message: nil, close_label: nil, default_title: nil, actions_hint: nil, **options)
      @message = message
      @keywords = options.slice(*PAYLOAD_KEYWORDS).compact
      @close_label = close_label
      @default_title = default_title
      @actions_hint = actions_hint
      super(**options.except(*PAYLOAD_KEYWORDS))
    end

    # Resolved at render, so the block's content and the locale in force are the ones used.
    def before_render
      payload
      return unless icon? && @keywords[:icon] == false

      Ui::Toast::Validation.invalid!('Ui::ToastComponent was given both an icon slot and icon: false. Pass one. ' \
                                     'The slot is rendered.')
    end

    def payload
      @payload ||= Ui::Toast::Payload.new(raw_payload)
    end

    delegate :type, :actions, :duration, to: :payload

    def template?
      @template == true
    end

    def id
      @id ||= html_attributes[:id] || "ui-toast-#{SecureRandom.hex(6)}"
    end

    def title_id = "#{id}-title"
    def description_id = "#{id}-description"

    # With neither a title nor a description, the chrome default is the title (§ Behavior, item 11).
    def title_text
      payload.title.presence || (default_title unless description?)
    end

    def title?
      template? || title_text.present?
    end

    def description?
      template? || payload.description.present?
    end

    def icon_cell?
      template? || icon? || payload.icon?
    end

    def actions?
      template? || actions.any?
    end

    def countdown?
      template? || payload.countdown?
    end

    def toast_attributes
      labelledby = title? ? title_id : description_id
      describedby = description_id if title? && description?
      { id: id, role: 'group', aria: { labelledby: labelledby, describedby: describedby }.compact,
        data: { controller: 'ui--toast', action: 'keydown->ui--toast#dismissOnEscape',
                'ui--toast-type-value': type, 'ui--toast-duration-value': duration } }
    end

    def close_button
      Ui::ButtonComponent.new(variant: :ghost, size: :icon, class: 'size-(--control-height-sm) -my-1.5 -me-2',
                              aria: { label: close_label }, data: { action: 'click->ui--toast#close' })
    end

    private

    def raw_payload
      base = message_payload
      base = base.merge(description: content) if content.present? && !base.key?(:description) && !@keywords.key?(:description)
      base.merge(@keywords)
    end

    def message_payload
      case @message
      when nil then {}
      when String then { description: @message }
      when Hash then @message.to_h.transform_keys(&:to_sym)
      when Symbol then translated_payload
      else Ui::Toast::Validation.invalid!("Toast message: must be a String, a Hash or an I18n key Symbol, got #{@message.class}.") || {}
      end
    end

    # Only a Symbol is looked up: a String is always what it says, so "date" is never swapped for
    # Rails' date translations (§ Behavior, item 2).
    def translated_payload
      return Ui::Toast::Validation.invalid!("Toast message: #{@message.inspect} is not an I18n key.") || {} unless I18n.exists?(@message)

      translation = I18n.t(@message)
      translation.is_a?(Hash) ? translation.transform_keys(&:to_sym) : { description: translation.to_s }
    end
  end
end
