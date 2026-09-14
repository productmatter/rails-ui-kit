# frozen_string_literal: true

module Ui
  class ConfirmDialogComponent < ViewComponent::Base
    DEFAULTS = {
      id: 'default-confirm',
      wrapper_class: 'relative transform overflow-hidden rounded-lg bg-white text-start shadow-xl ' \
                     'outline outline-black/10 dark:bg-gray-800 dark:outline-white/10 ' \
                     'transition-all sm:my-8 sm:w-full sm:max-w-lg',
      body_class: 'px-4 pt-5 pb-4 sm:p-6 sm:pb-4',
      footer_class: 'bg-gray-100 dark:bg-gray-700/25 px-4 py-3 sm:flex sm:justify-end sm:px-6',
      title_class: 'text-base font-semibold text-gray-900 dark:text-white',
      message_class: 'text-sm text-gray-500 dark:text-gray-400',
      confirm_class: 'inline-flex w-full justify-center rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white hover:bg-red-500 mt-3 sm:mt-0 sm:ms-3 sm:w-auto',
      cancel_class: 'inline-flex w-full justify-center rounded-md bg-white dark:bg-white/10 ' \
                    'px-3 py-2 text-sm font-semibold text-gray-900 dark:text-white ' \
                    'outline outline-gray-300 dark:outline-white/10 ' \
                    'focus-visible:outline-2 focus-visible:outline-offset-2 ' \
                    'focus-visible:outline-gray-900 dark:focus-visible:outline-white ' \
                    'hover:bg-gray-50 dark:hover:bg-white/20 sm:w-auto',
      icon_wrapper_class: 'mx-auto flex size-12 shrink-0 items-center justify-center rounded-full bg-red-100 dark:bg-red-500/10 sm:mx-0 sm:size-10',
      icon_class: 'size-6 text-red-600 dark:text-red-400'
    }.freeze

    # The four text keywords are chrome: each falls through to rails_ui_kit.confirm_dialog.*
    # when it isn't given, resolved per render rather than baked into the frozen DEFAULTS, so a
    # locale switch between renders takes effect. dialog_controller.js reads the rendered
    # title/message back off this component's own markup (data-default-title/data-default-message)
    # instead of keeping its own copy of these strings, so this is the only place they're defined.
    include Ui::Chrome

    chrome_string :title, key: 'confirm_dialog.title'
    chrome_string :message, key: 'confirm_dialog.message'
    chrome_string :confirm_label, key: 'confirm_dialog.confirm_label'
    chrome_string :cancel_label, key: 'confirm_dialog.cancel_label'

    attr_reader(*DEFAULTS.keys)

    # The class keywords stay a splat: they are theming, and a host overrides them wholesale.
    def initialize(title: nil, message: nil, confirm_label: nil, cancel_label: nil, **overrides)
      super()
      DEFAULTS.merge(overrides).each do |key, value|
        instance_variable_set(:"@#{key}", value)
      end
      @title = title
      @message = message
      @confirm_label = confirm_label
      @cancel_label = cancel_label
    end
  end
end
