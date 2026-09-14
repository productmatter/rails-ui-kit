# frozen_string_literal: true

module Ui
  class ToastContainerComponent < ViewComponent::Base
    DEFAULT_CLASSES = 'fixed top-4 inset-e-4 z-[70] w-80 pointer-events-none'

    include Ui::Chrome

    # Backs data-ui--toast-container-default-title-value: window.triggerToast(type) called with
    # no message has no Ruby render call to source a title from, so the controller reads it
    # here. close_label: is here for the same reason -- a toast JavaScript creates is a clone of
    # one of the templates below, so this is the only place its close button can be named.
    chrome_string :default_title, key: 'toast.default_title'
    chrome_string :close_label, key: 'toast.close_label'

    attr_reader :container_class

    def initialize(container_class: DEFAULT_CLASSES, default_title: nil, close_label: nil)
      super()
      @container_class = container_class
      @default_title = default_title
      @close_label = close_label
    end

    def template_types
      ToastComponent::TYPES
    end

    def template_toast(type)
      ToastComponent.new(type: type, message: { title: '__TITLE__', body: '__BODY__' },
                         close_label: close_label)
    end
  end
end
