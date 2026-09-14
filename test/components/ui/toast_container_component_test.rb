# frozen_string_literal: true

require 'test_helper'

module Ui
  class ToastContainerComponentTest < ViewComponent::TestCase
    test 'renders the container with stack and one template per type' do
      render_inline(Ui::ToastContainerComponent.new)

      assert_selector "div[data-controller='ui--toast-container']"
      assert_selector "div[data-ui--toast-container-target='stack']"

      Ui::ToastComponent::TYPES.each do |type|
        assert_selector "template[data-ui--toast-container-target='template'][data-toast-type='#{type}']", visible: :all
      end
    end

    test 'renders persistent polite and assertive live regions ahead of any toast' do
      render_inline(Ui::ToastContainerComponent.new)

      assert_selector "div[data-ui--toast-container-target='politeRegion'][role='status'][aria-live='polite'][aria-atomic='true'].sr-only", visible: :all
      assert_selector "div[data-ui--toast-container-target='assertiveRegion'][role='alert'][aria-live='assertive'][aria-atomic='true'].sr-only", visible: :all
    end

    test 'each per-type template contains a renderable toast skeleton' do
      html = render_inline(Ui::ToastContainerComponent.new).to_html

      assert_includes html, 'data-controller="ui--toast"'
      assert_includes html, 'data-ui--toast-target="title"'
      assert_includes html, 'data-ui--toast-target="body"'
    end

    test 'error template carries error styling but no live-region role of its own' do
      html = render_inline(Ui::ToastContainerComponent.new).to_html

      error_template = html[%r{<template[^>]*data-toast-type="error"[^>]*>.*?</template>}m]
      refute_nil error_template, 'expected an error template to be rendered'
      assert_includes error_template, 'data-ui--toast-type-value="error"'
      assert_includes error_template, 'bg-red-100'
      refute_includes error_template, 'role='
      refute_includes error_template, 'aria-live='
    end

    test 'accepts a custom container class' do
      render_inline(Ui::ToastContainerComponent.new(container_class: 'fixed bottom-4 left-4'))

      assert_selector "div[data-controller='ui--toast-container'].fixed.bottom-4.left-4"
    end

    test 'carries the translated default title for window.triggerToast(type) called with no message' do
      render_inline(Ui::ToastContainerComponent.new)

      assert_selector "div[data-ui--toast-container-default-title-value='#{I18n.t('rails_ui_kit.toast.default_title')}']"
    end

    test 'switching I18n.locale changes the default title value' do
      I18n.with_locale(:fr) do
        render_inline(Ui::ToastContainerComponent.new)

        assert_selector "div[data-ui--toast-container-default-title-value='Avis']"
      end
    end
  end
end
