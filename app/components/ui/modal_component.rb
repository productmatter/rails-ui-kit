# frozen_string_literal: true

module Ui
  class ModalComponent < ViewComponent::Base
    BASE_CLASSES = %w[
      fixed z-[61] p-0 m-0 max-h-none max-w-none
      backdrop:bg-transparent bg-white dark:bg-gray-900 shadow-2xl
      opacity-0 transition-all duration-300 ease-in-out
    ].freeze

    DEFAULT_WIDE = 'w-full sm:w-[42rem]'
    DEFAULT_NARROW = 'w-full sm:w-[32rem]'
    MAX_WIDE = 'max-w-full sm:max-w-[42rem]'
    MAX_NARROW = 'max-w-full sm:max-w-[32rem]'

    POSITION_CLASSES = {
      center: [
        'top-1/2', 'left-1/2', 'modal-center-hidden',
        :width_wide, MAX_WIDE, 'max-h-[90vh]',
        'rounded-none sm:rounded-lg', 'overflow-y-auto'
      ].freeze,
      full_screen: [
        'inset-4', 'sm:inset-6', 'modal-full-screen-hidden',
        'w-auto', 'h-auto', 'rounded-lg', 'overflow-y-auto'
      ].freeze,
      right: [
        'inset-y-0', 'right-0', 'left-auto', 'modal-right-hidden',
        'h-screen', 'min-h-screen', :width_narrow, MAX_NARROW,
        'rounded-none', 'overflow-y-auto'
      ].freeze,
      left: [
        'inset-y-0', 'left-0', 'right-auto', 'modal-left-hidden',
        'h-screen', 'min-h-screen', :width_narrow, MAX_NARROW,
        'rounded-none', 'overflow-y-auto'
      ].freeze,
      top: [
        'top-0', 'left-1/2', 'modal-top-hidden',
        :width_wide, MAX_WIDE,
        'rounded-none sm:rounded-b-lg', 'overflow-y-auto'
      ].freeze,
      top_full: [
        'top-0', 'left-0', 'right-0', 'modal-top-full-hidden',
        'w-full', 'rounded-b-lg', 'overflow-y-auto'
      ].freeze,
      bottom: [
        'bottom-0', 'top-auto', 'left-1/2', 'modal-bottom-hidden',
        :width_wide, MAX_WIDE,
        'rounded-none sm:rounded-t-lg', 'overflow-y-auto'
      ].freeze,
      bottom_full: [
        'bottom-0', 'top-auto', 'left-0', 'right-0', 'modal-bottom-full-hidden',
        'w-full', 'rounded-t-lg', 'overflow-y-auto'
      ].freeze
    }.freeze

    POSITIONS = POSITION_CLASSES.keys.freeze

    attr_reader :position, :track_changes, :close_on_backdrop, :max_width

    def initialize(position: :center, track_changes: false, close_on_backdrop: true, max_width: nil)
      super()
      @position = POSITIONS.include?(position.to_sym) ? position.to_sym : :center
      @track_changes = track_changes
      @close_on_backdrop = close_on_backdrop
      @max_width = max_width
    end

    def controller_data
      {
        data: {
          controller: 'ui--modal',
          'ui--modal-position-value': position,
          'ui--modal-track-changes-value': track_changes,
          'ui--modal-close-on-backdrop-value': close_on_backdrop,
          action: 'click->ui--modal#closeOnBackdropClick keydown->ui--modal#closeOnEscape'
        }
      }
    end

    def dialog_classes
      width = max_width || (POSITION_CLASSES[position].include?(:width_narrow) ? DEFAULT_NARROW : DEFAULT_WIDE)
      position_classes = POSITION_CLASSES[position].map do |token|
        case token
        when :width_wide, :width_narrow then width
        else token
        end
      end

      (BASE_CLASSES + position_classes).join(' ')
    end
  end
end
