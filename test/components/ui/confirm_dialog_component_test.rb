# frozen_string_literal: true

require 'test_helper'

module Ui
  class ConfirmDialogComponentTest < ViewComponent::TestCase
    test 'renders a dialog with default-confirm id' do
      render_inline(Ui::ConfirmDialogComponent.new)

      assert_selector "dialog#default-confirm[data-ui--dialog-target='dialog']"
      assert_selector '[data-ui--dialog-title]', text: 'Confirmation required'
      assert_selector '[data-ui--dialog-message]', text: 'Are you sure?'
    end

    test 'respects custom id' do
      render_inline(Ui::ConfirmDialogComponent.new(id: 'delete-confirm'))

      assert_selector 'dialog#delete-confirm'
      assert_selector 'h3#delete-confirm-title'
    end

    test 'applies custom button classes and labels' do
      render_inline(Ui::ConfirmDialogComponent.new(
                      confirm_class: 'btn-danger',
                      cancel_class: 'btn-ghost',
                      confirm_label: 'Yes, delete',
                      cancel_label: 'Keep it'
                    ))

      assert_selector 'button.btn-danger', text: 'Yes, delete'
      assert_selector 'button.btn-ghost', text: 'Keep it'
    end

    test 'title and message classes are applied' do
      render_inline(Ui::ConfirmDialogComponent.new(title_class: 'my-title', message_class: 'my-msg'))

      assert_selector 'h3.my-title'
      assert_selector 'p.my-msg'
    end
  end
end
