# frozen_string_literal: true

module Ui
  class ModalComponent < Ui::Base
    # Enter and exit are keyed off the data-state ui--presence sets, so the dialog and its
    # ::backdrop animate out before ui--overlay closes the dialog.
    BASE_CLASSES = %w[
      fixed p-0 m-0 max-h-none max-w-none
      bg-popover text-popover-foreground border border-border shadow-2xl
      opacity-0 data-[state=open]:opacity-100 transition-all duration-300 ease-in-out focus-visible:outline-none
      backdrop:bg-black/50 backdrop:backdrop-blur-sm backdrop:opacity-0 data-[state=open]:backdrop:opacity-100
      backdrop:transition-opacity backdrop:duration-300 backdrop:ease-in-out
    ].freeze

    DEFAULT_WIDE = 'w-full sm:w-[42rem]'
    DEFAULT_NARROW = 'w-full sm:w-[32rem]'
    MAX_WIDE = 'max-w-full sm:max-w-[42rem]'
    MAX_NARROW = 'max-w-full sm:max-w-[32rem]'

    # Centred horizontally with auto inline margins, not `left-1/2` and a translate: a fixed
    # element's `left` follows the inline start in a right-to-left document, which put a centred
    # Modal half off-screen (docs/specs/ui-stress-page/status.md).
    POSITION_CLASSES = {
      center: [
        'top-1/2', 'inset-x-0', 'mx-auto', 'modal-center-hidden',
        DEFAULT_WIDE, MAX_WIDE, 'max-h-[90vh]',
        'rounded-none sm:rounded-lg', 'overflow-y-auto'
      ].freeze,
      full_screen: [
        'inset-4', 'sm:inset-6', 'modal-full-screen-hidden',
        'w-auto', 'h-auto', 'rounded-lg', 'overflow-y-auto'
      ].freeze,
      right: [
        'inset-y-0', 'right-0', 'left-auto', 'modal-right-hidden',
        'h-screen', 'min-h-screen', DEFAULT_NARROW, MAX_NARROW,
        'rounded-none', 'overflow-y-auto'
      ].freeze,
      left: [
        'inset-y-0', 'left-0', 'right-auto', 'modal-left-hidden',
        'h-screen', 'min-h-screen', DEFAULT_NARROW, MAX_NARROW,
        'rounded-none', 'overflow-y-auto'
      ].freeze,
      top: [
        'top-0', 'inset-x-0', 'mx-auto', 'modal-top-hidden',
        DEFAULT_WIDE, MAX_WIDE,
        'rounded-none sm:rounded-b-lg', 'overflow-y-auto'
      ].freeze,
      top_full: [
        'top-0', 'left-0', 'right-0', 'modal-top-full-hidden',
        'w-full', 'rounded-b-lg', 'overflow-y-auto'
      ].freeze,
      bottom: [
        'bottom-0', 'top-auto', 'inset-x-0', 'mx-auto', 'modal-bottom-hidden',
        DEFAULT_WIDE, MAX_WIDE,
        'rounded-none sm:rounded-t-lg', 'overflow-y-auto'
      ].freeze,
      bottom_full: [
        'bottom-0', 'top-auto', 'left-0', 'right-0', 'modal-bottom-full-hidden',
        'w-full', 'rounded-t-lg', 'overflow-y-auto'
      ].freeze
    }.freeze

    POSITIONS = POSITION_CLASSES.keys.freeze

    # The <dialog> is the modal's root in Ui::Base's sense: `data-slot`, a caller's `class:` and any
    # forwarded attribute (aria: { labelledby: 'heading-id' } or { label: 'Command palette' } to name
    # it) land there. Its controllers sit on the wrapper, which is where ui--overlay's events fire.
    data_slot 'modal'

    class_variants(
      base: BASE_CLASSES.join(' '),
      variants: { position: POSITION_CLASSES.transform_values { |classes| classes.join(' ') } },
      defaults: { position: :center }
    )

    include Ui::Chrome

    # The prompt a dirty modal shows before it discards: chrome, so it falls through to
    # rails_ui_kit.modal.* when the call site doesn't name it (ui-localization § Behavior, item 2).
    chrome_string :unsaved_changes_title, key: 'modal.unsaved_changes_title'
    chrome_string :unsaved_changes_message, key: 'modal.unsaved_changes_message'

    attr_reader :position, :track_changes, :close_on_backdrop

    # max_width: is kept for one release, merged the way class: is rather than replacing the width.
    def initialize(position: :center, track_changes: false, close_on_backdrop: true, max_width: nil,
                   unsaved_changes_title: nil, unsaved_changes_message: nil, **html_attributes)
      @unsaved_changes_title = unsaved_changes_title
      @unsaved_changes_message = unsaved_changes_message
      @position = position
      @track_changes = track_changes
      @close_on_backdrop = close_on_backdrop
      # Ahead of the caller's class:, so a class: that contradicts max_width: wins.
      max_width = deprecated_class_keyword(:max_width, max_width, 'class:')
      super(**html_attributes, class: [max_width, html_attributes[:class]].compact_blank.presence)
    end

    def variant_values
      { position: position }
    end

    def controller_data
      {
        data: {
          controller: 'ui--modal ui--overlay',
          'ui--modal-track-changes-value': track_changes,
          'ui--modal-close-on-backdrop-value': close_on_backdrop,
          'ui--modal-unsaved-changes-title-value': unsaved_changes_title,
          'ui--modal-unsaved-changes-message-value': unsaved_changes_message,
          'ui--overlay-mode-value': 'modal',
          'ui--overlay-open-value': true,
          'ui--overlay-scroll-lock-value': true,
          action: 'ui--overlay:dismiss->ui--modal#guardDismiss:self ' \
                  'ui--overlay:closed->ui--modal#remove:self'
        }
      }
    end

    def dialog_attributes
      root_attributes(data: { 'ui--overlay-target': 'content' })
    end
  end
end
