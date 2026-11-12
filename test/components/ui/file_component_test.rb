# frozen_string_literal: true

require 'test_helper'

module Ui
  # Ui::FileComponent's markup: the native input is the control and carries everything a form and
  # a Field need; the two states are server-rendered; the buttons under the input are never a
  # second control.
  class FileComponentTest < ViewComponent::TestCase
    def input
      page.find("input[type='file']", visible: :all)
    end

    test 'the native input carries the name, the derived id, accept and required' do
      render_inline(Ui::FileComponent.new(name: 'form[pdf]', accept: 'application/pdf,.pdf', required: true))

      assert_equal 'form[pdf]', input[:name]
      assert_equal 'form_pdf', input[:id]
      assert_equal 'application/pdf,.pdf', input[:accept]
      assert input[:required]
      assert_equal 'ui--file', page.find("[data-slot='file']")['data-controller']
    end

    test 'with nothing chosen it renders the drop area, its sentence and the caller meta line' do
      render_inline(Ui::FileComponent.new(name: 'pdf', meta: 'PDF, up to 20 MB'))

      root = page.find("[data-slot='file']")
      assert_equal 'empty', root['data-state']
      assert_selector "[data-slot='file-drop']:not([hidden])", text: 'Drop a file here or'
      assert_selector "[data-slot='file-drop'] button", text: 'Choose file'
      assert_selector "[data-slot='file-meta']", text: 'PDF, up to 20 MB'
      assert_selector "[data-slot='file-row'][hidden]", visible: :all
    end

    test 'filename: renders the file row with its meta, and the drop area hidden' do
      render_inline(Ui::FileComponent.new(name: 'pdf', filename: 'acord_125.pdf', file_meta: '372 KB · 4 pages'))

      assert_equal 'chosen', page.find("[data-slot='file']")['data-state']
      assert_selector "[data-slot='file-row']:not([hidden])", text: 'acord_125.pdf'
      assert_selector "[data-ui--file-target='meta']", text: '372 KB · 4 pages'
      assert_selector "[data-slot='file-row'] button", text: 'Change'
      assert_selector "[data-slot='file-drop'][hidden]", visible: :all
    end

    test 'the buttons are aria-hidden and out of the tab order: the input is the one control' do
      render_inline(Ui::FileComponent.new(name: 'pdf', filename: 'a.pdf'))

      buttons = page.all('button', visible: :all)
      assert_equal 2, buttons.size
      buttons.each do |button|
        assert_equal 'true', button['aria-hidden']
        assert_equal '-1', button['tabindex']
        assert_equal 'button', button['type']
      end
    end

    test 'the chrome strings resolve from the locale and take a per-instance override' do
      render_inline(Ui::FileComponent.new(name: 'pdf', drop_label: 'Drop a PDF here or', choose_label: 'Choose PDF',
                                          change_label: 'Replace'))

      assert_text 'Drop a PDF here or'
      assert_selector 'button', text: 'Choose PDF'
      assert_selector 'button', text: 'Replace', visible: :all
    end

    test 'inside a Field, the label names the input and the description and error describe it' do
      render_inline(Ui::FieldComponent.new(name: 'form[pdf]', errors: ['is missing'], required: true)) do |field|
        field.with_label { 'PDF' }
        field.with_control(Ui::FileComponent, accept: '.pdf')
        field.with_description { 'One PDF.' }
      end

      assert_selector "label[for='form_pdf']", text: 'PDF'
      assert_equal 'form_pdf', input[:id]
      assert_equal 'form[pdf]', input[:name]
      assert_equal 'true', input['aria-invalid']
      assert_equal 'form_pdf-description form_pdf-error', input['aria-describedby']
      assert input[:required]
      assert_nil page.find("[data-slot='file']")['aria-describedby'], 'the aria goes to the input, not the box'
    end

    test 'a model-bound Field never renders a value onto the file input' do
      record = Struct.new(:pdf) do
        include ActiveModel::API

        def self.name = 'Upload'
        def errors = ActiveModel::Errors.new(self)
      end.new(pdf: 'old.pdf')
      render_inline(Ui::FieldComponent.new(model: record, attribute: :pdf)) do |field|
        field.with_control(Ui::FileComponent)
      end

      assert_nil input[:value]
      assert_equal 'upload[pdf]', input[:name]
    end

    test 'disabled: disables the input' do
      render_inline(Ui::FileComponent.new(name: 'pdf', disabled: true))

      assert input.disabled?
    end

    test 'a caller class merges onto the box, and data attributes stay on it' do
      render_inline(Ui::FileComponent.new(name: 'pdf', class: 'rounded-xl', data: { testid: 'upload' }))

      root = page.find("[data-slot='file']")
      assert_includes root[:class].split, 'rounded-xl'
      refute_includes root[:class].split, 'rounded-md'
      assert_equal 'upload', root['data-testid']
    end
  end
end
