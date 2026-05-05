# frozen_string_literal: true

module Ui
  class ToastComponent < ViewComponent::Base
    TYPES = %i[success error notice alert info].freeze

    ICONS = {
      success: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z',
      error: 'M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z',
      notice: 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z',
      alert: 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z',
      info: 'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z'
    }.freeze

    attr_reader :type, :data

    def initialize(type:, message:)
      super()
      @type = normalize_type(type)
      @data = normalize_message(message)
    end

    def bg_light_class
      case type
      when :success then 'bg-green-100 dark:bg-green-900/30'
      when :error then 'bg-red-100 dark:bg-red-900/30'
      when :notice, :alert then 'bg-orange-100 dark:bg-orange-900/30'
      else 'bg-blue-100 dark:bg-blue-900/30'
      end
    end

    def bg_dark_class
      case type
      when :success then 'bg-green-400 dark:bg-green-500'
      when :error then 'bg-red-400 dark:bg-red-500'
      when :notice, :alert then 'bg-orange-400 dark:bg-orange-500'
      else 'bg-blue-400 dark:bg-blue-500'
      end
    end

    def text_color_class
      case type
      when :success then 'text-green-400 dark:text-green-500'
      when :error then 'text-red-400 dark:text-red-500'
      when :notice, :alert then 'text-orange-400 dark:text-orange-500'
      else 'text-blue-400 dark:text-blue-500'
      end
    end

    def icon_path
      ICONS[type]
    end

    def timeout
      return data[:timeout] if data[:timeout].present?

      type == :error ? 20_000 : 3_000
    end

    def title
      data[:title]
    end

    def body
      data[:body]
    end

    def aria_role
      type == :error ? 'alert' : 'status'
    end

    def aria_live
      type == :error ? 'assertive' : 'polite'
    end

    private

    def normalize_type(type)
      type = type.to_sym
      TYPES.include?(type) ? type : :info
    end

    def normalize_message(message)
      case message
      when Hash
        message.deep_symbolize_keys
      when String
        if I18n.exists?(message, raise: false)
          translation = I18n.t(message)
          translation.is_a?(Hash) ? translation.deep_symbolize_keys : { title: translation }
        else
          { title: message }
        end
      else
        { title: 'Notification' }
      end
    end
  end
end
