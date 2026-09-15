# frozen_string_literal: true

require 'test_helper'

module Ui
  class ModalComponentTest < ViewComponent::TestCase
    test 'renders a dialog with default center position' do
      render_inline(Ui::ModalComponent.new) { 'hello' }

      assert_selector "div[data-controller~='ui--modal'][data-controller~='ui--overlay']" \
                      "[data-ui--overlay-mode-value='modal'][data-ui--overlay-open-value='true']" \
                      "[data-ui--overlay-scroll-lock-value='true']"
      assert_selector "dialog[data-ui--overlay-target='content']"
      assert_includes page.find('dialog')[:class], 'backdrop:bg-black/50'
      assert_includes page.find('dialog')[:class], 'modal-center-hidden'
      assert_text 'hello'
    end

    test 'applies position-specific class for :right' do
      render_inline(Ui::ModalComponent.new(position: :right))

      assert_includes page.find('dialog')[:class], 'modal-right-hidden'
    end

    test 'honors custom max_width' do
      assert_deprecated(RailsUiKit.deprecator) { render_inline(Ui::ModalComponent.new(max_width: 'max-w-2xl')) }

      assert_includes page.find('dialog')[:class], 'max-w-2xl'
    end

    # Behaves as Ui::ModalComponent does outside development and test.
    class LenientModalComponent < Ui::ModalComponent
      def self.raise_on_unknown_variant?
        false
      end
    end

    test 'an unknown position raises in development and test, naming the positions' do
      error = assert_raises(Ui::Base::UnknownVariantError) { render_inline(Ui::ModalComponent.new(position: :nope)) }

      assert_includes error.message, 'position: :nope'
      assert_includes error.message, ':bottom_full'
    end

    test 'outside development and test an unknown position logs and renders center' do
      log = StringIO.new
      original_logger = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(log)

      render_inline(LenientModalComponent.new(position: :nope))

      assert_includes page.find('dialog')[:class], 'modal-center-hidden'
      assert_match(/position: :nope/, log.string)
    ensure
      Rails.logger = original_logger
    end

    test 'a position given as a string resolves' do
      render_inline(Ui::ModalComponent.new(position: 'right'))

      assert_includes page.find('dialog')[:class], 'modal-right-hidden'
    end

    test 'the dialog carries data-slot and a caller class merged over its defaults' do
      render_inline(Ui::ModalComponent.new(class: 'sm:w-96 sm:rounded-none'))

      classes = page.find("dialog[data-slot='modal']")[:class].split
      assert_includes classes, 'sm:w-96'
      refute_includes classes, 'sm:w-[42rem]'
      refute_includes classes, 'sm:rounded-lg'
    end

    test 'data and aria attributes forward to the dialog without detaching its overlay target' do
      render_inline(Ui::ModalComponent.new(data: { testid: 'edit' }, aria: { describedby: 'hint' }))

      assert_selector "dialog[data-testid='edit'][aria-describedby='hint'][data-ui--overlay-target='content']"
    end

    test 'max_width is deprecated, and merges ahead of class' do
      assert_deprecated(/max_width: is deprecated; pass class:/, RailsUiKit.deprecator) do
        render_inline(Ui::ModalComponent.new(max_width: 'max-w-md sm:max-w-md', class: 'sm:max-w-lg'))
      end

      classes = page.find('dialog')[:class].split
      assert_includes classes, 'max-w-md'
      assert_includes classes, 'sm:max-w-lg'
      refute_includes classes, 'max-w-full'
      refute_includes classes, 'sm:max-w-md'
    end

    test 'passes track_changes through to data values' do
      render_inline(Ui::ModalComponent.new(track_changes: true))

      assert_selector "div[data-ui--modal-track-changes-value='true']"
    end

    test 'names the dialog from a heading id via aria labelledby' do
      render_inline(Ui::ModalComponent.new(aria: { labelledby: 'edit-title' })) { '<h2 id="edit-title">Edit</h2>'.html_safe }

      assert_selector "dialog[aria-labelledby='edit-title']"
      assert_no_selector 'dialog[aria-label]'
    end

    test 'renders no aria naming attributes by default' do
      render_inline(Ui::ModalComponent.new)

      assert_no_selector 'dialog[aria-labelledby], dialog[aria-label]'
    end

    test 'names the dialog with an aria label when there is no visible title' do
      render_inline(Ui::ModalComponent.new(aria: { label: 'Command palette' }))

      assert_selector "dialog[aria-label='Command palette']"
      assert_no_selector 'dialog[aria-labelledby]'
    end

    test 'carries the translated unsaved-changes confirm title and message for ui--modal to read' do
      render_inline(Ui::ModalComponent.new(track_changes: true)) { 'hello' }

      assert_selector "div[data-ui--modal-unsaved-changes-title-value='#{I18n.t('rails_ui_kit.modal.unsaved_changes_title')}']"
      assert_selector "div[data-ui--modal-unsaved-changes-message-value='#{I18n.t('rails_ui_kit.modal.unsaved_changes_message')}']"
    end

    test 'switching I18n.locale changes the confirm title and message values' do
      I18n.with_locale(:fr) do
        render_inline(Ui::ModalComponent.new(track_changes: true)) { 'hello' }

        assert_selector "div[data-ui--modal-unsaved-changes-title-value='Modifications non enregistrées']"
        assert_selector "div[data-ui--modal-unsaved-changes-message-value='Vous avez des modifications non enregistrées. Voulez-vous vraiment fermer ?']"
      end
    end
  end
end
