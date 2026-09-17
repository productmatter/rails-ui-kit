# frozen_string_literal: true

require 'test_helper'

module Ui
  # Payload and layout in Ruby (docs/specs/ui-toast, § Acceptance checks).
  class ToastComponentTest < ViewComponent::TestCase
    UNDO = { label: 'Undo', href: '/projects/7/unarchive', method: 'patch' }.freeze

    test 'a String message is the description, and renders no title' do
      render_inline(Ui::ToastComponent.new(type: :success, message: 'Saved!'))

      assert_selector '[data-slot=toast-description]', text: 'Saved!'
      assert_no_selector '[data-slot=toast-title]'
      assert_selector "[data-slot=toast][data-ui--toast-type-value='success']"
    end

    test 'block content is the description, and renders no title' do
      render_inline(Ui::ToastComponent.new(type: :success)) { 'Saved from a block' }

      assert_selector '[data-slot=toast-description]', text: 'Saved from a block'
      assert_no_selector '[data-slot=toast-title]'
    end

    test 'a title renders before the description, and names the group the description describes' do
      render_inline(Ui::ToastComponent.new(type: :error, title: 'Oops', description: 'Try again.'))

      title, description = page.all('[data-slot=toast-content] p').map { |part| part['data-slot'] }
      assert_equal %w[toast-title toast-description], [title, description]
      root = page.find('[data-slot=toast]')
      assert_equal page.find('[data-slot=toast-title]')['id'], root['aria-labelledby']
      assert_equal page.find('[data-slot=toast-description]')['id'], root['aria-describedby']
    end

    test 'a description alone names the group, with nothing describing it' do
      render_inline(Ui::ToastComponent.new(type: :info, message: 'Hi'))

      root = page.find('[data-slot=toast]')
      assert_equal page.find('[data-slot=toast-description]')['id'], root['aria-labelledby']
      assert_nil root['aria-describedby']
    end

    test 'with neither a title nor a description, the chrome default is the title' do
      render_inline(Ui::ToastComponent.new(type: :info))

      assert_selector '[data-slot=toast-title]', text: I18n.t('rails_ui_kit.toast.default_title')
      assert_no_selector '[data-slot=toast-description]'
    end

    test 'a Hash message is a payload, and string keys and string values are accepted' do
      render_inline(Ui::ToastComponent.new(message: { 'type' => 'error', 'title' => 'Oops', 'description' => 'Try again.' }))

      assert_selector "[data-slot=toast][data-ui--toast-type-value='error']"
      assert_selector '[data-slot=toast-title]', text: 'Oops'
      assert_selector '[data-slot=toast-description]', text: 'Try again.'
    end

    test 'a String that happens to be an I18n key is text, never a translation' do
      render_inline(Ui::ToastComponent.new(type: :info, message: 'date'))
      assert_selector '[data-slot=toast-description]', text: 'date'

      render_inline(Ui::ToastComponent.new(type: :info, message: 'number.currency.format.unit'))
      assert_selector '[data-slot=toast-description]', text: 'number.currency.format.unit'
    end

    test 'a Symbol message is looked up: a String translation is the description, a Hash one a payload' do
      I18n.backend.store_translations(:en, toast_test: { saved: 'Saved via I18n', archived: { title: 'Archived', description: 'Gone' } })

      render_inline(Ui::ToastComponent.new(type: :success, message: :'toast_test.saved'))
      assert_selector '[data-slot=toast-description]', text: 'Saved via I18n'

      render_inline(Ui::ToastComponent.new(type: :success, message: :'toast_test.archived'))
      assert_selector '[data-slot=toast-title]', text: 'Archived'
      assert_selector '[data-slot=toast-description]', text: 'Gone'
    end

    test 'each action renders exactly what Ui::ButtonComponent renders at size: :sm' do
      link = button_html(variant: :outline, href: '/p/7')
      button = button_html(variant: :ghost, type: 'button')
      render_inline(Ui::ToastComponent.new(type: :success, title: 'x',
                                           actions: [{ label: 'View', href: '/p/7' }, { label: 'Got it', variant: 'ghost' }]))

      assert_equal link, attributes_of(page.find('[data-slot=toast-actions] a'))
      assert_equal button, attributes_of(page.find("[data-slot=toast-actions] button[type='button']"))
    end

    test 'a get href is a link, a patch href a post form with _method and no authenticity field' do
      render_inline(Ui::ToastComponent.new(type: :success, title: 'x', actions: [{ label: 'View', href: '/p/7' }, UNDO]))

      assert_selector "[data-slot=toast-actions] a[href='/p/7']", text: 'View'
      form = page.find("[data-slot=toast-actions] form[method='post'][action='/projects/7/unarchive'][data-turbo='true']")
      assert form.has_selector?("input[type='hidden'][name='_method'][value='patch']", visible: :all)
      assert form.has_selector?("button[type='submit']", text: 'Undo')
      assert_no_selector "input[name='authenticity_token']", visible: :all
    end

    test 'a post action sends no _method field' do
      render_inline(Ui::ToastComponent.new(type: :success, title: 'x', actions: [{ label: 'Retry', href: '/retry', method: 'POST' }]))

      assert_selector "form[action='/retry']"
      assert_no_selector "input[name='_method']", visible: :all
    end

    test 'an action with no href is a button that only dismisses' do
      render_inline(Ui::ToastComponent.new(type: :success, title: 'x', actions: [{ label: 'Got it' }]))

      assert_selector "[data-slot=toast-actions] button[type='button'][data-ui--toast-dismiss-param='true']", text: 'Got it'
    end

    test "an action's class beats Button's own conflicting class" do
      render_inline(Ui::ToastComponent.new(type: :success, title: 'x', actions: [{ label: 'Undo', class: 'h-12' }]))

      classes = page.find('[data-slot=toast-actions] button')[:class].split
      assert_includes classes, 'h-12'
      assert_not_includes classes, 'h-(--control-height-sm)'
    end

    test 'no action renders no footer' do
      render_inline(Ui::ToastComponent.new(type: :success, message: 'Saved'))

      assert_no_selector '[data-slot=toast-actions]'
    end

    test "the type's glyph renders by default in an aria-hidden cell that sets the type's colour" do
      render_inline(Ui::ToastComponent.new(type: :warning, message: 'x'))

      cell = page.find("[data-slot=toast-icon][aria-hidden='true']")
      assert_includes cell[:class].split, 'text-warning'
      assert cell.has_selector?('svg')
    end

    # Rails' flash keys read as Rails means them: notice is "it worked", alert is the failure.
    test 'notice renders in the success colour with the success glyph, and alert in the error colour' do
      expected = { notice: ['text-success', Ui::ToastComponent::ICONS[:success]],
                   alert: ['text-destructive', nil], warning: ['text-warning', nil] }
      expected.each do |type, (colour, glyph)|
        render_inline(Ui::ToastComponent.new(type: type, message: 'x'))

        assert_includes page.find('[data-slot=toast-icon]')[:class].split, colour, "#{type} is not #{colour}"
        assert_equal glyph, page.find('[data-slot=toast-icon] path')['d'] if glyph
      end
    end

    test 'an icon slot replaces the glyph inside the same aria-hidden cell' do
      render_inline(Ui::ToastComponent.new(type: :success, message: 'x')) do |toast|
        toast.with_icon { '<svg id="mine" stroke="currentColor"></svg>'.html_safe }
      end

      assert_selector "[data-slot=toast-icon][aria-hidden='true'] svg#mine"
      assert_selector '[data-slot=toast-icon] svg', count: 1
    end

    test 'icon: false renders no icon cell and no svg outside the close button' do
      render_inline(Ui::ToastComponent.new(type: :success, message: 'x', icon: false))

      assert_no_selector '[data-slot=toast-icon]'
      assert_empty(page.all('svg').reject { |svg| svg.native.ancestors('button').any? })
      assert_selector 'button svg', count: 1
    end

    test 'the root is a group, never a live region, on tokens, with class: merged' do
      render_inline(Ui::ToastComponent.new(type: :error, message: 'Boom', class: 'shadow-none'))

      root = page.find('[data-slot=toast]')
      assert_equal 'group', root['role']
      assert_no_selector '[role=status], [role=alert], [aria-live]'
      classes = root[:class].split
      assert_includes classes, 'bg-popover'
      assert_includes classes, 'shadow-none'
      assert_not_includes classes, 'shadow-lg'
    end

    test 'the close button is a ghost icon Button at the small control height, named from the locale' do
      render_inline(Ui::ToastComponent.new(type: :info, message: 'Saved!'))

      close = page.find("button[data-action='click->ui--toast#close']")
      assert_equal I18n.t('rails_ui_kit.toast.close_label'), close['aria-label']
      assert_includes close[:class].split, 'size-(--control-height-sm)'
      assert_no_selector 'button span.sr-only'
    end

    test 'switching I18n.locale changes the default title and the close button name' do
      I18n.with_locale(:fr) do
        render_inline(Ui::ToastComponent.new(type: :info))

        assert_selector '[data-slot=toast-title]', text: 'Avis'
        assert_equal 'Fermer la notification', page.find('button')['aria-label']
      end
    end

    test 'the type accepts a symbol or a string' do
      render_inline(Ui::ToastComponent.new(type: 'alert', message: 'x'))

      assert_selector "[data-slot=toast][data-ui--toast-type-value='alert']"
      assert_includes page.find('[data-slot=toast-icon]')[:class].split, 'text-destructive'
    end

    private

    def button_html(variant:, **element)
      render_inline(Ui::ButtonComponent.new(variant: variant, size: :sm,
                                            data: { action: 'click->ui--toast#activate', 'ui--toast-dismiss-param': true },
                                            **element).with_content('label'))
      attributes_of(page.find('[data-slot=button]'))
    end

    def attributes_of(element)
      element.native.attributes.except('href').transform_values(&:value)
    end
  end
end
