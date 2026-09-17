# frozen_string_literal: true

require 'test_helper'

module Ui
  class TextareaComponentTest < ViewComponent::TestCase
    def textarea_classes
      page.find('[data-slot=textarea]')['class'].split
    end

    test 'renders a textarea element' do
      render_inline(Ui::TextareaComponent.new)

      assert_selector 'textarea'
    end

    test 'stamps data-slot on the root element' do
      render_inline(Ui::TextareaComponent.new)

      assert_selector "textarea[data-slot='textarea']"
    end

    test 'renders block content as its value' do
      render_inline(Ui::TextareaComponent.new) { 'Existing notes' }

      assert_selector 'textarea', text: 'Existing notes'
    end

    test 'renders shared control classes matching Input' do
      render_inline(Ui::TextareaComponent.new)

      assert_includes textarea_classes, 'border-input'
      assert_includes textarea_classes, 'bg-background'
      assert_includes textarea_classes, 'rounded-md'
    end

    test 'draws its focus indicator as an offset outline from the ring token, not a box-shadow ring' do
      render_inline(Ui::TextareaComponent.new)

      assert_includes textarea_classes, 'focus-visible:outline-2'
      assert_includes textarea_classes, 'focus-visible:outline-offset-2'
      assert_includes textarea_classes, 'focus-visible:outline-ring'
      assert_empty textarea_classes.grep(/ring-\[|:ring-ring/)
    end

    test 'carries disabled styling hooks' do
      render_inline(Ui::TextareaComponent.new)

      assert_includes textarea_classes, 'disabled:opacity-50'
      assert_includes textarea_classes, 'disabled:pointer-events-none'
    end

    test 'carries invalid styling hooks driven by aria-invalid' do
      render_inline(Ui::TextareaComponent.new)

      assert_includes textarea_classes, 'aria-invalid:border-destructive'
      assert_includes textarea_classes, 'aria-invalid:focus-visible:outline-destructive'
    end

    test 'reflects disabled on the textarea element' do
      render_inline(Ui::TextareaComponent.new(disabled: true))

      assert_selector 'textarea[disabled]'
    end

    test 'reflects aria-invalid on the textarea element' do
      render_inline(Ui::TextareaComponent.new(aria: { invalid: true }))

      assert_selector "textarea[aria-invalid='true']"
    end

    test 'caller class wins over a conflicting default' do
      render_inline(Ui::TextareaComponent.new(class: 'bg-red-500'))

      assert_includes textarea_classes, 'bg-red-500'
      assert_not_includes textarea_classes, 'bg-background'
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(Ui::TextareaComponent.new(id: 'notes', name: 'notes', placeholder: 'Add a note'))

      assert_selector "textarea#notes[name='notes'][placeholder='Add a note']"
    end

    test 'forwards data and aria attributes to the root element' do
      render_inline(Ui::TextareaComponent.new(data: { controller: 'field' }, aria: { describedby: 'notes-hint' }))

      assert_selector "textarea[data-slot='textarea'][data-controller='field'][aria-describedby='notes-hint']"
    end
  end
end
