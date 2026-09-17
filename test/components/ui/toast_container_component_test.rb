# frozen_string_literal: true

require 'test_helper'

module Ui
  # The container: the stack every entry point renders into, the flash mapping, and the templates
  # JavaScript clones (docs/specs/ui-toast, § Behavior, items 3, 7, 12 and 16).
  class ToastContainerComponentTest < ViewComponent::TestCase
    test 'an empty stack is a hidden region with the id a Turbo Stream appends to' do
      render_inline(Ui::ToastContainerComponent.new)

      stack = page.find('#ui-toasts', visible: :all)
      assert_equal 'region', stack['role']
      assert_equal I18n.t('rails_ui_kit.toast.region_label'), stack['aria-label']
      assert_equal 'F8', stack['aria-keyshortcuts']
      assert stack[:hidden], 'an empty stack should be hidden'
    end

    test 'toasts: renders each payload in the stack, string keys included, and the stack is shown' do
      render_inline(Ui::ToastContainerComponent.new(toasts: [{ 'type' => 'success', 'title' => 'Archived' }, 'Saved']))

      stack = page.find('#ui-toasts')
      assert_nil stack[:hidden]
      assert_selector '#ui-toasts [data-slot=toast]', count: 2
      assert_selector "#ui-toasts [data-ui--toast-type-value='success'] [data-slot=toast-title]", text: 'Archived'
      assert_selector '#ui-toasts [data-slot=toast-description]', text: 'Saved'
    end

    test "flash: maps Rails' notice and alert, and a toast payload, and ignores the host's other keys" do
      flash = ActionDispatch::Flash::FlashHash.new
      flash[:notice] = 'Post was successfully created.'
      flash[:alert] = 'You need to sign in first.'
      flash[:toast] = { 'type' => 'success', 'title' => 'Project archived',
                        'actions' => [{ 'label' => 'Undo', 'href' => '/undo', 'method' => 'patch' }] }
      flash[:tracking_id] = 'abc123'

      render_inline(Ui::ToastContainerComponent.new(flash: flash))

      assert_selector "[data-ui--toast-type-value='notice'] [data-slot=toast-description]", text: 'Post was successfully created.'
      assert_selector "[data-ui--toast-type-value='alert'] [data-slot=toast-description]", text: 'You need to sign in first.'
      assert_selector "[data-ui--toast-type-value='success'] [data-slot=toast-actions] form[action='/undo']"
      assert_selector '#ui-toasts [data-slot=toast]', count: 3
      assert_not_includes rendered_content, 'abc123'
    end

    test 'flash: works with a plain Hash, and an empty flash renders nothing' do
      render_inline(Ui::ToastContainerComponent.new(flash: { notice: '' }))
      assert_no_selector '#ui-toasts [data-slot=toast]', visible: :all

      render_inline(Ui::ToastContainerComponent.new(flash: { 'notice' => 'Hi' }))
      assert_selector '#ui-toasts [data-slot=toast-description]', text: 'Hi'
    end

    test 'container_class: and class: add to the defaults instead of replacing them' do
      render_inline(Ui::ToastContainerComponent.new(container_class: 'top-20', class: 'w-96'))

      classes = page.find('[data-slot=toast-container]')[:class].split
      assert_includes classes, 'top-20'
      assert_includes classes, 'w-96'
      assert_not_includes classes, 'top-4'
      assert_not_includes classes, 'w-80'
      assert_includes classes, 'inset-e-4'
      assert_includes classes, 'max-w-[calc(100vw-2rem)]'
    end

    test 'the container renders what JavaScript reads: chrome, the strict flag, one template per type, one per action kind and variant' do
      render_inline(Ui::ToastContainerComponent.new(actions_hint: 'Press F8.', default_title: 'Heads up', close_label: 'Dismiss'))

      root = page.find('[data-slot=toast-container]')
      assert_equal 'Press F8.', root['data-ui--toast-container-actions-hint-value']
      assert_equal 'Heads up', root['data-ui--toast-container-default-title-value']
      assert_equal 'true', root['data-ui--toast-container-strict-value']

      html = rendered_content
      Ui::ToastComponent::TYPES.each { |type| assert_includes html, %(data-toast-type="#{type}") }
      Ui::Toast::Action.variants.product(%w[link form button]).each do |variant, kind|
        assert_includes html, %(data-action-kind="#{kind}" data-action-variant="#{variant}")
      end
      assert_includes html, 'aria-label="Dismiss"'
    end
    # Restored from 0.2.0's container test, with selectors updated only for the renamed
    # description target and the token colour.

    test 'renders the container with stack and one template per type' do
      render_inline(Ui::ToastContainerComponent.new)

      assert_selector "div[data-controller='ui--toast-container']"
      assert_selector "div[data-ui--toast-container-target='stack']", visible: :all

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
      assert_includes html, 'data-ui--toast-target="description"'
    end

    test 'error template carries error styling but no live-region role of its own' do
      html = render_inline(Ui::ToastContainerComponent.new).to_html

      error_template = html[%r{<template[^>]*data-toast-type="error"[^>]*>.*?</template>}m]
      refute_nil error_template, 'expected an error template to be rendered'
      assert_includes error_template, 'data-ui--toast-type-value="error"'
      assert_includes error_template, 'text-destructive'
      refute_includes error_template, 'role="status"'
      refute_includes error_template, 'role="alert"'
      refute_includes error_template, 'aria-live='
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
