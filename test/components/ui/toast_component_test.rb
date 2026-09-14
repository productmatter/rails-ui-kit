# frozen_string_literal: true

require 'test_helper'

module Ui
  class ToastComponentTest < ViewComponent::TestCase
    test 'renders a toast with title from a string message' do
      render_inline(Ui::ToastComponent.new(type: :success, message: 'Saved!'))

      assert_selector "div[data-controller='ui--toast']"
      assert_selector "[data-ui--toast-target='title']", text: 'Saved!'
      assert_selector "div[data-ui--toast-type-value='success']"
    end

    test 'renders title and body from a hash message' do
      render_inline(Ui::ToastComponent.new(type: :error, message: { title: 'Oops', body: 'Try again.' }))

      assert_selector "[data-ui--toast-target='title']", text: 'Oops'
      assert_selector "[data-ui--toast-target='body']", text: 'Try again.'
      assert_selector "div[data-ui--toast-type-value='error']"
    end

    test 'the toast itself carries no live-region role, only the container does' do
      render_inline(Ui::ToastComponent.new(type: :error, message: 'Boom'))

      assert_no_selector '[role]'
      assert_no_selector '[aria-live]'
    end

    test 'default timeout is 3000ms for non-error types' do
      render_inline(Ui::ToastComponent.new(type: :info, message: 'Hi'))

      assert_selector "div[data-ui--toast-self-destruct-value='3000']"
    end

    test 'default timeout is 20000ms for error type' do
      render_inline(Ui::ToastComponent.new(type: :error, message: 'Boom'))

      assert_selector "div[data-ui--toast-self-destruct-value='20000']"
    end

    test 'explicit timeout in message hash overrides default' do
      render_inline(Ui::ToastComponent.new(type: :info, message: { title: 'x', timeout: 1500 }))

      assert_selector "div[data-ui--toast-self-destruct-value='1500']"
    end

    test 'explicit timeout of 0 persists instead of falling back to the default' do
      render_inline(Ui::ToastComponent.new(type: :info, message: { title: 'x', timeout: 0 }))

      assert_selector "div[data-ui--toast-self-destruct-value='0']"
    end

    test 'unknown types fall back to :info' do
      render_inline(Ui::ToastComponent.new(type: :weird, message: 'x'))

      assert_selector "div[data-ui--toast-type-value='info']"
    end

    test 'a message that is neither a Hash nor a String falls back to a translated generic title' do
      render_inline(Ui::ToastComponent.new(type: :info, message: nil))

      assert_selector "[data-ui--toast-target='title']", text: I18n.t('rails_ui_kit.toast.default_title')
    end

    test 'the close button has one name, from the locale file' do
      render_inline(Ui::ToastComponent.new(type: :info, message: 'Saved!'))

      close_button = page.find('button')
      assert_equal I18n.t('rails_ui_kit.toast.close_label'), close_button['aria-label']
      # The sr-only twin is gone: aria-label wins the accessible-name computation, so a second
      # string there was never announced and never seen (ui-localization § Behavior, item 4).
      assert_no_selector 'button span.sr-only'
    end

    test 'switching I18n.locale changes the default title and the close button name' do
      I18n.with_locale(:fr) do
        render_inline(Ui::ToastComponent.new(type: :info, message: nil))

        assert_selector "[data-ui--toast-target='title']", text: 'Avis'
        assert_equal 'Fermer la notification', page.find('button')['aria-label']
      end
    end
  end
end
