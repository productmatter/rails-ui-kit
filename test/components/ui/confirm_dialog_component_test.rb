# frozen_string_literal: true

require 'test_helper'

module Ui
  class ConfirmDialogComponentTest < ViewComponent::TestCase
    # A host renders the component and nothing else: the controller that installs
    # window.defaultConfirmDialog has to come with it, not from a wrapper the host must know to add.
    test 'the dialog carries its own ui--dialog controller' do
      render_inline(Ui::ConfirmDialogComponent.new)

      assert_equal %w[ui--overlay ui--dialog], page.find('dialog')['data-controller'].split
    end

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

    test 'a class keyword beats the default it conflicts with, and keeps the defaults it does not' do
      render_inline(Ui::ConfirmDialogComponent.new(wrapper_class: 'rounded-none', footer_class: 'bg-card',
                                                   confirm_label: 'Yes, delete', cancel_label: 'Keep it'))

      wrapper = classes_of('[data-slot=confirm-dialog] > div > div')
      assert_includes wrapper, 'rounded-none'
      assert_not_includes wrapper, 'rounded-lg', 'the caller\'s radius did not replace the default radius'
      assert_includes wrapper, 'bg-popover', 'a default the caller did not contradict was dropped'

      footer = classes_of("form[method='dialog']")
      assert_includes footer, 'bg-card'
      assert_not_includes footer, 'bg-muted'
      assert_includes footer, 'sm:justify-end'

      assert_selector "button[value='confirm']", text: 'Yes, delete'
      assert_selector "button[value='cancel']", text: 'Keep it'
    end

    test 'title, message, confirm and cancel class keywords merge onto their parts' do
      render_inline(Ui::ConfirmDialogComponent.new(title_class: 'text-lg', message_class: 'text-base',
                                                   confirm_class: 'sm:w-full', cancel_class: 'sm:w-full'))

      assert_includes classes_of('h3'), 'text-lg'
      assert_not_includes classes_of('h3'), 'text-base'
      assert_includes classes_of('p[data-ui--dialog-message]'), 'text-base'
      assert_not_includes classes_of('p[data-ui--dialog-message]'), 'text-sm'
      %w[confirm cancel].each do |value|
        assert_includes classes_of("form button[value='#{value}']"), 'sm:w-full'
        assert_not_includes classes_of("form button[value='#{value}']"), 'sm:w-auto'
      end
    end

    test 'icon_class: is gone with the glyph it styled, and says so' do
      error = assert_raises(ArgumentError) { Ui::ConfirmDialogComponent.new(icon_class: 'size-6 text-red-600') }

      assert_match(/icon_class/, error.message)
      assert_match(/icon slot/, error.message)
    end

    test 'no icon is rendered unless a caller provides one' do
      render_inline(Ui::ConfirmDialogComponent.new)

      assert_no_selector 'svg'
      assert_no_selector '[data-slot=confirm-dialog-icon]'
    end

    test 'the icon slot renders inside an aria-hidden cell the component only sizes and places' do
      render_inline(Ui::ConfirmDialogComponent.new) do |dialog|
        dialog.with_icon { '<svg id="mine"></svg>'.html_safe }
      end

      assert_selector "[data-slot=confirm-dialog-icon][aria-hidden='true'] svg#mine"
      cell = classes_of('[data-slot=confirm-dialog-icon]')
      assert_includes cell, 'size-12'
      assert_includes cell, 'sm:size-10'
      assert_not_includes cell, 'bg-destructive/10', 'the cell owns colour it should leave to the caller'
    end

    test 'the body slot replaces the message paragraph inside the same aria-describedby target' do
      render_inline(Ui::ConfirmDialogComponent.new(id: 'rich')) do |dialog|
        dialog.with_body { '<p>Two</p><p>paragraphs</p>'.html_safe }
      end

      assert_no_selector 'p[data-ui--dialog-message]'
      assert_selector '#rich-message[data-ui--dialog-body] p', count: 2
      assert_equal 'rich-message', page.find('dialog')['aria-describedby']
    end

    test 'Confirm is a destructive Button by default, Cancel an outline one, with the dialog layout merged on' do
      # Rendered before the dialog: render_inline replaces the page, so the expectation has to be
      # taken first.
      confirm = button_classes(:destructive, :confirm)
      cancel = button_classes(:outline, :cancel)
      render_inline(Ui::ConfirmDialogComponent.new)

      assert_equal confirm, classes_of("form button[value='confirm']")
      assert_equal cancel, classes_of("form button[value='cancel']")
    end

    test 'confirm_variant: picks any Button variant, and an unknown one is loud' do
      primary = button_classes(:default, :confirm)
      render_inline(Ui::ConfirmDialogComponent.new(confirm_variant: :default))

      assert_equal primary, classes_of("form button[value='confirm']")
      assert_equal 'default', page.find("form button[value='confirm']")['data-ui--dialog-confirm-variant']

      error = assert_raises(Ui::Base::UnknownVariantError) { Ui::ConfirmDialogComponent.new(confirm_variant: :danger) }
      assert_match(/confirm_variant/, error.message)
    end

    test 'every confirm variant ships as a template Ui::ButtonComponent rendered' do
      expected = Ui::ConfirmDialogComponent::CONFIRM_VARIANTS.to_h { |variant| [variant, button_classes(variant, :confirm)] }
      html = render_inline(Ui::ConfirmDialogComponent.new).to_html

      expected.each do |variant, classes|
        # Read out of the raw HTML: a <template>'s content is a separate document fragment, so it
        # is not reachable through the parsed page -- which is the point of using one.
        template = html[%r{<template data-ui--dialog-confirm-template="#{variant}">(.*?)</template>}m, 1]
        assert template, "no template for the #{variant} confirm variant"
        assert_equal classes, CGI.unescape_html(template[/class="([^"]*)"/, 1]).split.sort
        assert_includes template, 'value="confirm"'
      end
    end

    test 'the dialog carries every rendered default, and the strict flag JavaScript reads' do
      render_inline(Ui::ConfirmDialogComponent.new(confirm_variant: :default))

      dialog = page.find('dialog')
      assert_equal I18n.t('rails_ui_kit.confirm_dialog.confirm_label'), dialog['data-default-confirm-label']
      assert_equal I18n.t('rails_ui_kit.confirm_dialog.cancel_label'), dialog['data-default-cancel-label']
      assert_equal 'default', dialog['data-default-confirm-variant']
      assert_equal 'true', dialog['data-strict'], 'the strict flag is decided in Ruby, never inferred in the browser'
    end

    test 'a non-String text value is loud in test, as every payload rule is' do
      error = assert_raises(ArgumentError) { Ui::ConfirmDialogComponent.new(title: { html: '<b>no</b>' }) }

      assert_match(/title/, error.message)
    end

    test "class: merges onto the dialog's own root classes" do
      render_inline(Ui::ConfirmDialogComponent.new(class: 'absolute'))

      root = classes_of('dialog')
      assert_includes root, 'absolute'
      assert_not_includes root, 'fixed', "the caller's position did not win"
      assert_includes root, 'backdrop:bg-black/50', 'a default the caller did not contradict was dropped'
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

      # Scoped to the form: the dialog also carries a <template> per confirm variant, which is
      # inert markup rather than a second button on the page.
      assert_equal(%w[cancel confirm], page.all('dialog form button').map { |button| button[:value] })
      assert_selector "button[value='cancel'][autofocus]"
      assert_no_selector "button[value='confirm'][autofocus]"
    end

    test 'Cancel shows a focus-visible outline by default' do
      render_inline(Ui::ConfirmDialogComponent.new)

      assert_includes page.find("form button[value='cancel']")[:class], 'focus-visible:outline-2'
    end

    test 'title, message and button labels resolve from the locale file' do
      render_inline(Ui::ConfirmDialogComponent.new)

      assert_equal I18n.t('rails_ui_kit.confirm_dialog.title'), page.find('[data-ui--dialog-title]').text
      assert_equal I18n.t('rails_ui_kit.confirm_dialog.message'), page.find('[data-ui--dialog-message]').text
      assert_equal I18n.t('rails_ui_kit.confirm_dialog.confirm_label'), page.find("form button[value='confirm']").text.strip
      assert_equal I18n.t('rails_ui_kit.confirm_dialog.cancel_label'), page.find("form button[value='cancel']").text.strip
    end

    test 'switching I18n.locale changes the rendered title, message and button labels' do
      I18n.with_locale(:fr) do
        render_inline(Ui::ConfirmDialogComponent.new)

        assert_selector '[data-ui--dialog-title]', text: 'Confirmation requise'
        assert_selector '[data-ui--dialog-message]', text: 'Êtes-vous sûr ?'
        assert_selector "form button[value='confirm']", text: 'Confirmer'
        assert_selector "form button[value='cancel']", text: 'Annuler'
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

    private

    def classes_of(selector)
      page.find(selector, visible: :all)[:class].split.sort
    end

    # What Ui::ButtonComponent itself renders for that variant, with the dialog's own layout
    # classes merged on: the dialog composes no button classes of its own.
    def button_classes(variant, part)
      layout = Ui::ConfirmDialogComponent::DEFAULT_CLASSES.fetch(part)
      rendered = render_inline(Ui::ButtonComponent.new(variant: variant, type: 'submit', class: layout))
      rendered.css('button').first['class'].split.sort
    end
  end
end
