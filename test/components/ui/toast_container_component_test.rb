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

    test 'each per-type template contains a renderable toast skeleton' do
      html = render_inline(Ui::ToastContainerComponent.new).to_html

      assert_includes html, 'data-controller="ui--toast"'
      assert_includes html, 'data-ui--toast-target="title"'
      assert_includes html, 'data-ui--toast-target="body"'
    end

    test 'error template carries error styling and aria attributes' do
      html = render_inline(Ui::ToastContainerComponent.new).to_html

      error_template = html[%r{<template[^>]*data-toast-type="error"[^>]*>.*?</template>}m]
      refute_nil error_template, 'expected an error template to be rendered'
      assert_includes error_template, 'role="alert"'
      assert_includes error_template, 'aria-live="assertive"'
      assert_includes error_template, 'bg-red-100'
    end

    test 'accepts a custom container class' do
      render_inline(Ui::ToastContainerComponent.new(container_class: 'fixed bottom-4 left-4'))

      assert_selector "div[data-controller='ui--toast-container'].fixed.bottom-4.left-4"
    end
  end
end
