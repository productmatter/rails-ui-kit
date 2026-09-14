# frozen_string_literal: true

module Ui
  class ToastContainerComponent < ViewComponent::Base
    DEFAULT_CLASSES = 'fixed top-4 right-4 z-[70] w-80 pointer-events-none'

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

    # Backs data-ui--toast-container-default-title-value: window.triggerToast(type) called with no
    # message has no Ruby render call to source a title from, so the controller reads it here.
    def default_title
      I18n.t('rails_ui_kit.toast.default_title')
    end
  end
end
