# frozen_string_literal: true

require 'test_helper'

module Ui
  class SpinnerComponentTest < ViewComponent::TestCase
    def spinner_classes
      page.find('[data-slot=spinner]')['class'].split
    end

    test 'renders a status role with a default accessible name' do
      render_inline(Ui::SpinnerComponent.new)

      assert_selector "[data-slot='spinner'][role='status']"
      assert_equal 'Loading', page.find('[data-slot=spinner] span.sr-only').text
    end

    test 'stamps data-slot on the root element' do
      render_inline(Ui::SpinnerComponent.new)

      assert_selector "[data-slot='spinner']"
    end

    test 'a caller overrides the accessible name through the block' do
      render_inline(Ui::SpinnerComponent.new) { 'Saving changes' }

      assert_equal 'Saving changes', page.find('[data-slot=spinner] span.sr-only').text
    end

    test 'renders an inline svg hidden from assistive technology' do
      render_inline(Ui::SpinnerComponent.new)

      assert_selector "[data-slot='spinner'] svg[aria-hidden='true']"
    end

    test 'the accessible name text is visually hidden' do
      render_inline(Ui::SpinnerComponent.new)

      assert_selector "[data-slot='spinner'] span.sr-only", text: 'Loading'
    end

    test 'renders shared base classes' do
      render_inline(Ui::SpinnerComponent.new)

      assert_includes spinner_classes, 'inline-flex'
      assert_includes spinner_classes, 'text-foreground'
    end

    test 'caller class wins over a conflicting default' do
      render_inline(Ui::SpinnerComponent.new(class: 'text-primary'))

      assert_includes spinner_classes, 'text-primary'
      assert_not_includes spinner_classes, 'text-foreground'
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(Ui::SpinnerComponent.new(id: 'save-spinner', data: { testid: 'spinner' }))

      assert_selector "[data-slot='spinner']#save-spinner[data-testid='spinner']"
    end
  end
end
