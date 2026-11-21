# frozen_string_literal: true

require 'test_helper'

module Ui
  # Ui::ModalContentComponent: a modal's header, body and footer as one turbo frame whose id is
  # the same in every state (docs/specs/ui-modal-content). The layout it promises is measured in
  # the browser, in test/system/modal_content_test.rb.
  class ModalContentComponentTest < ViewComponent::TestCase
    test 'the root is always a turbo-frame carrying the id and data-slot' do
      render_inline(Ui::ModalContentComponent.new(id: 'project_modal_content')) { 'Body' }

      frame = page.find("turbo-frame#project_modal_content[data-slot='modal-content']")
      assert_equal %w[flex min-h-full flex-col], frame[:class].split
      assert_selector "turbo-frame > [data-slot='modal-content-body']", text: 'Body'
    end

    test 'title renders the heading with title_id, and title_id is derived from the id' do
      component = Ui::ModalContentComponent.new(id: 'project_modal_content', title: 'Edit project')
      render_inline(component)

      assert_equal 'project_modal_content_title', component.title_id
      assert_selector "[data-slot='modal-content-header'] h2#project_modal_content_title", text: 'Edit project'
    end

    test 'description renders a muted line under the title' do
      render_inline(Ui::ModalContentComponent.new(id: 'c', title: 'Invite', description: 'They get an email.'))

      assert_selector "[data-slot='modal-content-header'] h2 + p[data-slot='modal-content-description']", text: 'They get an email.'
      assert_includes page.find("[data-slot='modal-content-description']")[:class], 'text-muted-foreground'
    end

    test 'without a title there is no heading, and title_id names nothing' do
      render_inline(Ui::ModalContentComponent.new(id: 'c'))

      assert_no_selector 'h2'
      assert_no_selector '#c_title'
    end

    test 'the header has a close button wired to ui--modal#close and named by the chrome string' do
      render_inline(Ui::ModalContentComponent.new(id: 'c', title: 'Edit'))

      button = page.find("[data-slot='modal-content-header'] button[data-action='click->ui--modal#close']")
      assert_equal I18n.t('rails_ui_kit.modal.close_label'), button['aria-label']
      assert_equal 'button', button[:type]
      assert_selector "[data-slot='modal-content-header'] button svg[aria-hidden='true']"
    end

    test 'the close label resolves per render from the locale, and a call-site label wins' do
      I18n.with_locale(:fr) { render_inline(Ui::ModalContentComponent.new(id: 'c')) }
      assert_selector "button[aria-label='Fermer la boîte de dialogue']"

      render_inline(Ui::ModalContentComponent.new(id: 'c', close_label: 'Dismiss'))
      assert_selector "button[aria-label='Dismiss']"
    end

    test 'close: false drops the close button, and with nothing else the header' do
      render_inline(Ui::ModalContentComponent.new(id: 'c', title: 'Edit', close: false))
      assert_selector "[data-slot='modal-content-header'] h2"
      assert_no_selector 'button'

      render_inline(Ui::ModalContentComponent.new(id: 'c', close: false)) { 'Body' }
      assert_no_selector "[data-slot='modal-content-header']"
      assert_selector "[data-slot='modal-content-body']", text: 'Body'
    end

    test 'the header slot replaces the heading and close button inside the sticky header' do
      render_inline(Ui::ModalContentComponent.new(id: 'c', title: 'Ignored')) do |content|
        content.with_header { '<span id="custom">Cancel · New task · Save</span>'.html_safe }
        'Body'
      end

      assert_selector "[data-slot='modal-content-header'] #custom"
      assert_no_selector "[data-slot='modal-content-header'] h2"
      assert_no_selector "[data-slot='modal-content-header'] button"
      assert_includes page.find("[data-slot='modal-content-header']")[:class].split, 'sticky'
    end

    test 'no footer without the slot; the footer slot renders a sticky, end-aligned footer last' do
      render_inline(Ui::ModalContentComponent.new(id: 'c', title: 'Edit'))
      assert_no_selector "[data-slot='modal-content-footer']"

      render_inline(Ui::ModalContentComponent.new(id: 'c', title: 'Edit')) do |content|
        content.with_footer { '<button type="submit">Save</button>'.html_safe }
        'Body'
      end

      footer = page.find("turbo-frame > [data-slot='modal-content-footer']:last-child")
      assert_includes footer[:class].split, 'sticky'
      assert_includes footer[:class].split, 'bottom-0'
      assert_includes footer[:class].split, 'justify-end'
      assert_selector "[data-slot='modal-content-footer'] button", text: 'Save'
    end

    test 'the layout contract: a sticky header, a flex-1 body' do
      render_inline(Ui::ModalContentComponent.new(id: 'c', title: 'Edit')) { 'Body' }

      header = page.find("[data-slot='modal-content-header']")[:class].split
      assert_empty %w[sticky top-0 border-b bg-popover] - header
      assert_includes page.find("[data-slot='modal-content-body']")[:class].split, 'flex-1'
    end

    test 'form: wraps header, body and footer in one form carrying ui--form-change' do
      project = Project.new(id: 1, name: 'Acme', summary: 'A rebrand')
      render_inline(Ui::ModalContentComponent.new(id: 'c', title: 'Edit', form: { model: project })) do |content|
        content.with_footer { '<button type="submit">Save</button>'.html_safe }
        '<input name="project[name]">'.html_safe
      end

      form = page.find("turbo-frame#c > form[data-controller='ui--form-change']")
      assert_equal '/demos/projects/1', form[:action]
      assert_equal %w[flex flex-1 flex-col], form[:class].split
      assert_selector "turbo-frame > form > [data-slot='modal-content-header']"
      assert_selector "turbo-frame > form > [data-slot='modal-content-body'] input[name='project[name]']"
      assert_selector "turbo-frame > form > [data-slot='modal-content-footer'] button[type=submit]"
      assert_equal 1, page.all('form').size
    end

    test "form: joins ui--form-change with the caller's controller and keeps its other data and class" do
      render_inline(Ui::ModalContentComponent.new(
                      id: 'c', form: { url: '/demos/invitations', data: { controller: 'autosave', action: 'turbo:submit-end->ui--modal#closeOnSuccess' },
                                       class: 'gap-2' }
                    ))

      form = page.find('form[action="/demos/invitations"]')
      assert_equal 'ui--form-change autosave', form['data-controller']
      assert_equal 'turbo:submit-end->ui--modal#closeOnSuccess', form['data-action']
      assert_includes form[:class].split, 'gap-2'
      assert_includes form[:class].split, 'flex-1'
    end

    test 'attributes forward to the frame, and class merges over its defaults' do
      render_inline(Ui::ModalContentComponent.new(id: 'c', target: '_top', data: { testid: 'content' },
                                                  class: 'min-h-0 bg-muted'))

      frame = page.find("turbo-frame#c[target='_top'][data-testid='content'][data-slot='modal-content']")
      classes = frame[:class].split
      assert_includes classes, 'min-h-0'
      assert_includes classes, 'bg-muted'
      refute_includes classes, 'min-h-full'
    end

    test 'the part class keywords merge over each part, the caller winning a conflict' do
      render_inline(Ui::ModalContentComponent.new(id: 'c', title: 'Edit', header_class: 'px-4', body_class: 'p-0',
                                                  footer_class: 'justify-between')) do |content|
        content.with_footer { 'Actions' }
        'Body'
      end

      header = page.find("[data-slot='modal-content-header']")[:class].split
      assert_includes header, 'px-4'
      refute_includes header, 'px-6'
      assert_includes header, 'sticky'
      assert_equal %w[flex-1 p-0], page.find("[data-slot='modal-content-body']")[:class].split
      footer = page.find("[data-slot='modal-content-footer']")[:class].split
      assert_includes footer, 'justify-between'
      refute_includes footer, 'justify-end'
    end

    test 'an undeclared class keyword raises rather than becoming an HTML attribute' do
      assert_raises(ArgumentError) { Ui::ModalContentComponent.new(id: 'c', title_class: 'text-lg') }
    end

    test 'id is required' do
      assert_raises(ArgumentError) { Ui::ModalContentComponent.new(title: 'Edit') }
    end
  end
end
