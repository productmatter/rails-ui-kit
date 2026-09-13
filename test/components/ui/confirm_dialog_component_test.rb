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

    test 'is an alertdialog described by its message' do
      render_inline(Ui::ConfirmDialogComponent.new(id: 'delete-confirm'))

      assert_selector "dialog[role='alertdialog'][aria-labelledby='delete-confirm-title']" \
                      "[aria-describedby='delete-confirm-message']"
      assert_selector 'p#delete-confirm-message'
    end

    test 'buttons close the dialog through a method=dialog form, with no inline handlers' do
      render_inline(Ui::ConfirmDialogComponent.new)

      assert_selector "dialog form[method='dialog'] button[type='submit'][value='confirm']"
      assert_selector "dialog form[method='dialog'] button[type='submit'][value='cancel']"
      assert_no_selector '[onclick]'
    end

    test 'Cancel comes first in the DOM and takes initial focus' do
      render_inline(Ui::ConfirmDialogComponent.new)

      assert_equal(%w[cancel confirm], page.all('dialog button').map { |button| button[:value] })
      assert_selector "button[value='cancel'][autofocus]"
      assert_no_selector "button[value='confirm'][autofocus]"
    end

    test 'Cancel shows a focus-visible outline by default' do
      render_inline(Ui::ConfirmDialogComponent.new)

      assert_includes page.find("button[value='cancel']")[:class], 'focus-visible:outline-2'
    end
  end
end
