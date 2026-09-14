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
      render_inline(Ui::ModalComponent.new(max_width: 'max-w-2xl'))

      assert_includes page.find('dialog')[:class], 'max-w-2xl'
    end

    test 'falls back to :center for invalid positions' do
      render_inline(Ui::ModalComponent.new(position: :nope))

      assert_includes page.find('dialog')[:class], 'modal-center-hidden'
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
  end
end
