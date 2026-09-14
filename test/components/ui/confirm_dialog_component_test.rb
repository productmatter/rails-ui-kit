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

    test 'title, message and button labels resolve from the locale file' do
      render_inline(Ui::ConfirmDialogComponent.new)

      assert_equal I18n.t('rails_ui_kit.confirm_dialog.title'), page.find('[data-ui--dialog-title]').text
      assert_equal I18n.t('rails_ui_kit.confirm_dialog.message'), page.find('[data-ui--dialog-message]').text
      assert_equal I18n.t('rails_ui_kit.confirm_dialog.confirm'), page.find("button[value='confirm']").text.strip
      assert_equal I18n.t('rails_ui_kit.confirm_dialog.cancel'), page.find("button[value='cancel']").text.strip
    end

    test 'switching I18n.locale changes the rendered title, message and button labels' do
      I18n.with_locale(:fr) do
        render_inline(Ui::ConfirmDialogComponent.new)

        assert_selector '[data-ui--dialog-title]', text: 'Confirmation requise'
        assert_selector '[data-ui--dialog-message]', text: 'Êtes-vous sûr ?'
        assert_selector "button[value='confirm']", text: 'Confirmer'
        assert_selector "button[value='cancel']", text: 'Annuler'
      end
    end

    test 'a caller-supplied title and message override the translation' do
      render_inline(Ui::ConfirmDialogComponent.new(title: 'Delete this post?', message: "This can't be undone."))

      assert_selector '[data-ui--dialog-title]', text: 'Delete this post?'
      assert_selector '[data-ui--dialog-message]', text: "This can't be undone."
    end

    test 'the dialog carries its rendered title and message as data-default-* for the JS controller to read back' do
      render_inline(Ui::ConfirmDialogComponent.new(title: 'Delete this post?', message: "This can't be undone."))

      dialog = page.find('dialog')
      assert_equal 'Delete this post?', dialog['data-default-title']
      assert_equal "This can't be undone.", dialog['data-default-message']
    end
  end
end
