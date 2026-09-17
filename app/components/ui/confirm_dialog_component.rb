# frozen_string_literal: true

module Ui
  # The confirmation the kit answers `data-turbo-confirm` and `window.defaultConfirmDialog` with.
  #
  # The template is a title, a message and two actions. Everything else is content: the icon is a
  # slot that is empty unless a caller fills it, the message can be replaced by a rich `body` slot,
  # and the confirm button's variant is the caller's choice (ui-confirm-dialog § Behavior, item 1).
  class ConfirmDialogComponent < Ui::Base
    data_slot 'confirm-dialog'

    # One modal backdrop in the kit: Modal's own backdrop classes, read from it rather than
    # restated here, so the two can't drift (§ Behavior, item 10).
    BACKDROP_CLASSES = Ui::ModalComponent::BASE_CLASSES.grep(/backdrop:/).freeze

    class_variants(base: "fixed inset-0 size-auto max-h-none max-w-none overflow-y-auto bg-transparent #{BACKDROP_CLASSES.join(' ')}")

    # The scroll area between the backdrop and the panel: bottom-anchored on a phone, centred
    # from `sm` up, as it has been since 0.2.0.
    VIEWPORT_CLASSES = 'flex min-h-full items-end justify-center p-4 text-center focus:outline-none sm:items-center sm:p-0'

    # Each of these is the default a matching `*_class:` keyword merges onto, never replaces
    # (§ Behavior, item 10). The icon cell owns size and placement only: its glyph, and any tint
    # behind it, are the caller's.
    DEFAULT_CLASSES = {
      wrapper: 'relative w-full transform overflow-hidden rounded-lg bg-popover text-popover-foreground ' \
               'text-start shadow-xl outline outline-border transition-all sm:my-8 sm:max-w-lg',
      body: 'px-4 pt-5 pb-4 sm:p-6 sm:pb-4',
      footer: 'bg-muted px-4 py-3 sm:flex sm:justify-end sm:px-6',
      title: 'text-base font-semibold text-popover-foreground',
      message: 'text-sm text-muted-foreground',
      confirm: 'mt-3 w-full sm:mt-0 sm:ms-3 sm:w-auto',
      cancel: 'w-full sm:w-auto',
      icon_wrapper: 'mx-auto flex size-12 shrink-0 items-center justify-center sm:mx-0 sm:size-10'
    }.freeze

    CLASS_KEYWORDS = DEFAULT_CLASSES.keys.to_h { |part| [:"#{part}_class", part] }.freeze

    CONFIRM_VARIANTS = Ui::ButtonComponent.variant_options[:variant].freeze

    # The four text keywords are chrome: each falls through to rails_ui_kit.confirm_dialog.* when
    # it isn't given, resolved per render, so a locale switch between renders takes effect.
    # dialog_controller.js reads them back off the rendered markup (data-default-*) rather than
    # keeping its own copy, so this is the only place they're defined.
    include Ui::Chrome

    chrome_string :title, key: 'confirm_dialog.title'
    chrome_string :message, key: 'confirm_dialog.message'
    chrome_string :confirm_label, key: 'confirm_dialog.confirm_label'
    chrome_string :cancel_label, key: 'confirm_dialog.cancel_label'

    # Content a caller adds, never a glyph the kit picks (§ Business rules, rule 1). Neither
    # crosses JavaScript: rich content comes from a Ruby render, opened with customConfirmDialog.
    renders_one :icon
    renders_one :body

    attr_reader :id, :confirm_variant

    def initialize(id: 'default-confirm', title: nil, message: nil, confirm_label: nil, cancel_label: nil,
                   confirm_variant: :destructive, **overrides)
      @id = id
      @title = validate_text(:title, title)
      @message = validate_text(:message, message)
      @confirm_label = validate_text(:confirm_label, confirm_label)
      @cancel_label = validate_text(:cancel_label, cancel_label)
      @confirm_variant = resolve_confirm_variant(confirm_variant)
      @class_overrides = extract_class_overrides(overrides)
      super(**overrides)
    end

    # A part's defaults with the caller's classes merged on top, so a class that conflicts with a
    # default wins and the defaults it doesn't contradict stay.
    def classes_for(part)
      MERGER.merge([DEFAULT_CLASSES.fetch(part), @class_overrides[part]].compact.join(' '))
    end

    def dialog_attributes
      {
        role: 'alertdialog', 'aria-labelledby': "#{id}-title", 'aria-describedby': "#{id}-message",
        data: {
          'ui--dialog-target': 'dialog', 'ui--overlay-target': 'content',
          controller: 'ui--overlay ui--dialog', 'ui--overlay-mode-value': 'modal', 'ui--overlay-scroll-lock-value': true,
          # What every confirmation resets to, and the flag that decides whether an invalid option
          # throws or warns (§ Behavior, items 7 and 9).
          default_title: title, default_message: message, default_confirm_label: confirm_label,
          default_cancel_label: cancel_label, default_confirm_variant: confirm_variant,
          strict: self.class.raise_on_unknown_variant?
        }
      }
    end

    # The confirm button as a variant renders it. The dialog renders one of these and a <template>
    # of each of the others, so a confirmation that picks another variant swaps in markup
    # Ui::ButtonComponent produced rather than a class list JavaScript wrote.
    def confirm_button(variant)
      Ui::ButtonComponent.new(variant: variant, type: 'submit', value: 'confirm', class: classes_for(:confirm),
                              data: { 'ui--dialog-confirm-variant': variant })
                         .with_content(confirm_label)
    end

    def cancel_button
      Ui::ButtonComponent.new(variant: :outline, type: 'submit', value: 'cancel', autofocus: true,
                              class: classes_for(:cancel), data: { 'ui--dialog-cancel': '' })
                         .with_content(cancel_label)
    end

    # The text column sits beside the icon cell from `sm` up, and below it on a phone. With no
    # icon it starts at the panel's own padding.
    def text_column_classes
      icon? ? 'mt-3 text-center sm:mt-0 sm:ms-4 sm:text-start' : 'text-center sm:text-start'
    end

    private

    # icon_class: is gone with the glyph it styled. It would otherwise be forwarded to the root
    # element as an HTML attribute, silently, so it's named here instead (§ Behavior, item 10).
    def extract_class_overrides(overrides)
      if overrides.key?(:icon_class)
        raise ArgumentError, 'unknown keyword: :icon_class. The kit renders no glyph to style; ' \
                             'put your icon, and its classes, in the icon slot.'
      end

      CLASS_KEYWORDS.filter_map { |keyword, part| [part, overrides.delete(keyword)] if overrides.key?(keyword) }.to_h
    end

    # A payload value that isn't text is a bug in the call site, loud where that can be seen and
    # safe where it can't (ui-toast § Business rules, rule 4).
    def validate_text(name, value)
      return value if value.nil? || value.is_a?(String)

      message = "#{self.class.name}: #{name}: must be a String, got #{value.class}."
      raise ArgumentError, message if self.class.raise_on_unknown_variant?

      Rails.logger&.warn("[rails_ui_kit] #{message} Using the default instead.")
      nil
    end

    def resolve_confirm_variant(variant)
      match = CONFIRM_VARIANTS.find { |option| option.to_s == variant.to_s }
      return match if match

      message = "#{self.class.name} has no confirm_variant: #{variant.inspect}. " \
                "Expected one of: #{CONFIRM_VARIANTS.map(&:inspect).join(', ')}."
      raise Ui::Base::UnknownVariantError, message if self.class.raise_on_unknown_variant?

      Rails.logger&.warn("[rails_ui_kit] #{message} Rendering the default instead.")
      :destructive
    end
  end
end
