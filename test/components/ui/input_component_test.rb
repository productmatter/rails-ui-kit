# frozen_string_literal: true

require 'test_helper'

module Ui
  class InputComponentTest < ViewComponent::TestCase
    def input_classes
      page.find('[data-slot=input]')['class'].split
    end

    test 'renders an input element with a text type by default' do
      render_inline(Ui::InputComponent.new)

      assert_selector "input[type='text']"
    end

    test 'stamps data-slot on the root element' do
      render_inline(Ui::InputComponent.new)

      assert_selector "input[data-slot='input']"
    end

    test 'renders shared control classes' do
      render_inline(Ui::InputComponent.new)

      assert_includes input_classes, 'border-input'
      assert_includes input_classes, 'bg-background'
      assert_includes input_classes, 'rounded-md'
    end

    test 'draws its focus indicator as an offset outline from the ring token, not a box-shadow ring' do
      render_inline(Ui::InputComponent.new)

      assert_includes input_classes, 'focus-visible:outline-2'
      assert_includes input_classes, 'focus-visible:border-ring'
      assert_not_includes input_classes, 'focus-visible:outline-offset-2', 'a bordered control draws the fused line, not the stand-off ring'
      assert_includes input_classes, 'focus-visible:outline-ring'
      assert_empty input_classes.grep(/ring-\[|:ring-ring/)
    end

    test 'carries disabled styling hooks' do
      render_inline(Ui::InputComponent.new)

      assert_includes input_classes, 'disabled:opacity-50'
      assert_includes input_classes, 'disabled:pointer-events-none'
    end

    test 'carries invalid styling hooks driven by aria-invalid' do
      render_inline(Ui::InputComponent.new)

      assert_includes input_classes, 'aria-invalid:border-destructive'
      assert_includes input_classes, 'aria-invalid:focus-visible:outline-destructive'
    end

    test 'reflects disabled on the input element' do
      render_inline(Ui::InputComponent.new(disabled: true))

      assert_selector 'input[disabled]'
    end

    test 'reflects aria-invalid on the input element' do
      render_inline(Ui::InputComponent.new(aria: { invalid: true }))

      assert_selector "input[aria-invalid='true']"
    end

    test 'switches type' do
      render_inline(Ui::InputComponent.new(type: 'email'))

      assert_selector "input[type='email']"
    end

    test 'accepts a string type' do
      render_inline(Ui::InputComponent.new(type: 'password'))

      assert_selector "input[type='password']"
    end

    test 'caller class wins over a conflicting default' do
      render_inline(Ui::InputComponent.new(class: 'bg-red-500'))

      assert_includes input_classes, 'bg-red-500'
      assert_not_includes input_classes, 'bg-background'
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(Ui::InputComponent.new(id: 'email', name: 'email', value: 'jane@example.com', placeholder: 'you@example.com'))

      assert_selector "input#email[name='email'][value='jane@example.com'][placeholder='you@example.com']"
    end

    test 'forwards data and aria attributes to the root element' do
      render_inline(Ui::InputComponent.new(data: { controller: 'field' }, aria: { describedby: 'email-hint' }))

      assert_selector "input[data-slot='input'][data-controller='field'][aria-describedby='email-hint']"
    end
  end
end
