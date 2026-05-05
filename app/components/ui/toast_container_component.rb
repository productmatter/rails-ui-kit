# frozen_string_literal: true

module Ui
  class ToastContainerComponent < ViewComponent::Base
    DEFAULT_CLASSES = 'fixed top-20 right-4 z-[70] max-w-sm pointer-events-none'

    attr_reader :container_class

    def initialize(container_class: DEFAULT_CLASSES)
      super()
      @container_class = container_class
    end

    def template_types
      ToastComponent::TYPES
    end

    def template_toast(type)
      ToastComponent.new(type: type, message: { title: '__TITLE__', body: '__BODY__' })
    end
  end
end
