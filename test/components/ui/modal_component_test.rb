# frozen_string_literal: true

require 'test_helper'

module Ui
  class ModalComponentTest < ViewComponent::TestCase
    test 'renders a dialog with default center position' do
      render_inline(Ui::ModalComponent.new) { 'hello' }

      assert_selector "div[data-controller='ui--modal']"
      assert_selector "dialog[data-ui--modal-target='dialog']"
      assert_selector "div[data-ui--modal-target='backdrop']"
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
  end
end
