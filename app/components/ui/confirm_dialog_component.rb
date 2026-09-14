# frozen_string_literal: true

module Ui
  class ConfirmDialogComponent < ViewComponent::Base
    DEFAULTS = {
      id: 'default-confirm',
      wrapper_class: 'relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl ' \
                     'outline outline-black/10 dark:bg-gray-800 dark:outline-white/10 ' \
                     'transition-all sm:my-8 sm:w-full sm:max-w-lg',
      body_class: 'px-4 pt-5 pb-4 sm:p-6 sm:pb-4',
      footer_class: 'bg-gray-100 dark:bg-gray-700/25 px-4 py-3 sm:flex sm:justify-end sm:px-6',
      title_class: 'text-base font-semibold text-gray-900 dark:text-white',
      message_class: 'text-sm text-gray-500 dark:text-gray-400',
      confirm_class: 'inline-flex w-full justify-center rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white hover:bg-red-500 mt-3 sm:mt-0 sm:ml-3 sm:w-auto',
      cancel_class: 'inline-flex w-full justify-center rounded-md bg-white dark:bg-white/10 ' \
                    'px-3 py-2 text-sm font-semibold text-gray-900 dark:text-white ' \
                    'outline outline-gray-300 dark:outline-white/10 ' \
                    'focus-visible:outline-2 focus-visible:outline-offset-2 ' \
                    'focus-visible:outline-gray-900 dark:focus-visible:outline-white ' \
                    'hover:bg-gray-50 dark:hover:bg-white/20 sm:w-auto',
      icon_wrapper_class: 'mx-auto flex size-12 shrink-0 items-center justify-center rounded-full bg-red-100 dark:bg-red-500/10 sm:mx-0 sm:size-10',
      icon_class: 'size-6 text-red-600 dark:text-red-400'
    }.freeze

    # title:/message:/confirm_label:/cancel_label: default from I18n (rails_ui_kit.confirm_dialog.*),
    # resolved per instance rather than baked into the frozen DEFAULTS, so a locale switch between
    # renders takes effect. dialog_controller.js reads the rendered title/message back off
    # this component's own markup (data-default-title/data-default-message) instead of keeping its
    # own copy of these strings, so this is the only place they're defined.
    TEXT_KEYS = %i[title message confirm_label cancel_label].freeze

    attr_reader(*DEFAULTS.keys, *TEXT_KEYS)

    def initialize(**overrides)
      super()
      DEFAULTS.merge(default_text).merge(overrides).each do |key, value|
        instance_variable_set(:"@#{key}", value)
      end
    end

    private

    def default_text
      {
        title: I18n.t('rails_ui_kit.confirm_dialog.title'),
        message: I18n.t('rails_ui_kit.confirm_dialog.message'),
        confirm_label: I18n.t('rails_ui_kit.confirm_dialog.confirm'),
        cancel_label: I18n.t('rails_ui_kit.confirm_dialog.cancel')
      }
    end
  end
end
