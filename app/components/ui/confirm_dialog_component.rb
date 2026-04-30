# frozen_string_literal: true

module Ui
  class ConfirmDialogComponent < ViewComponent::Base
    DEFAULTS = {
      id: 'default-confirm',
      wrapper_class: 'relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl ' \
                     'outline outline-black/10 dark:bg-gray-800 dark:outline-white/10 ' \
                     'transition-all sm:my-8 sm:w-full sm:max-w-lg',
      body_class: 'px-4 pt-5 pb-4 sm:p-6 sm:pb-4',
      footer_class: 'bg-gray-100 dark:bg-gray-700/25 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6',
      title_class: 'text-base font-semibold text-gray-900 dark:text-white',
      message_class: 'text-sm text-gray-500 dark:text-gray-400',
      confirm_class: 'inline-flex w-full justify-center rounded-md bg-red-600 px-3 py-2 text-sm font-semibold text-white hover:bg-red-500 sm:ml-3 sm:w-auto',
      cancel_class: 'mt-3 inline-flex w-full justify-center rounded-md bg-white dark:bg-white/10 ' \
                    'px-3 py-2 text-sm font-semibold text-gray-900 dark:text-white ' \
                    'outline outline-gray-300 dark:outline-white/10 ' \
                    'hover:bg-gray-50 dark:hover:bg-white/20 sm:mt-0 sm:w-auto',
      icon_wrapper_class: 'mx-auto flex size-12 shrink-0 items-center justify-center rounded-full bg-red-100 dark:bg-red-500/10 sm:mx-0 sm:size-10',
      icon_class: 'size-6 text-red-600 dark:text-red-400',
      confirm_label: 'Confirm',
      cancel_label: 'Cancel'
    }.freeze

    attr_reader(*DEFAULTS.keys)

    def initialize(**overrides)
      super()
      DEFAULTS.merge(overrides).each do |key, value|
        instance_variable_set(:"@#{key}", value)
      end
    end
  end
end
