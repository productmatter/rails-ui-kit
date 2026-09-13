# frozen_string_literal: true

require 'test_helper'

module Ui
  class SeparatorComponentTest < ViewComponent::TestCase
    def separator_classes
      page.find('[data-slot=separator]')['class'].split
    end

    test 'renders a div with the separator data-slot' do
      render_inline(Ui::SeparatorComponent.new)

      assert_selector "div[data-slot='separator']"
    end

    test 'is decorative by default: role=none and no aria-orientation' do
      render_inline(Ui::SeparatorComponent.new)

      assert_selector "div[role='none']"
      assert_nil page.find('[data-slot=separator]')['aria-orientation']
    end

    test 'a non-decorative separator gets role=separator and aria-orientation' do
      render_inline(Ui::SeparatorComponent.new(decorative: false))

      assert_selector "div[role='separator'][aria-orientation='horizontal']"
    end

    test 'defaults to horizontal orientation classes' do
      render_inline(Ui::SeparatorComponent.new)

      assert_includes separator_classes, 'h-px'
      assert_includes separator_classes, 'w-full'
    end

    test 'renders vertical orientation classes' do
      render_inline(Ui::SeparatorComponent.new(orientation: :vertical))

      assert_includes separator_classes, 'h-full'
      assert_includes separator_classes, 'w-px'
      assert_not_includes separator_classes, 'h-px'
    end

    test 'a non-decorative vertical separator reports its orientation' do
      render_inline(Ui::SeparatorComponent.new(orientation: :vertical, decorative: false))

      assert_selector "div[role='separator'][aria-orientation='vertical']"
    end

    test 'accepts a string orientation value' do
      render_inline(Ui::SeparatorComponent.new(orientation: 'vertical'))

      assert_includes separator_classes, 'w-px'
    end

    test 'nil orientation falls back to the default' do
      render_inline(Ui::SeparatorComponent.new(orientation: nil))

      assert_includes separator_classes, 'h-px'
    end

    test 'an unknown orientation raises in development and test' do
      assert_raises(Ui::Base::UnknownVariantError) { render_inline(Ui::SeparatorComponent.new(orientation: :diagonal)) }
    end

    test 'caller class wins over a conflicting variant class' do
      render_inline(Ui::SeparatorComponent.new(class: 'w-1/2'))

      assert_includes separator_classes, 'w-1/2'
      assert_not_includes separator_classes, 'w-full'
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(Ui::SeparatorComponent.new(id: 'section-rule'))

      assert_selector "div#section-rule[data-slot='separator']"
    end

    test 'forwards data and aria attributes to the root element' do
      render_inline(Ui::SeparatorComponent.new(data: { testid: 'rule' }))

      assert_selector "div[data-slot='separator'][data-testid='rule']"
    end
  end
end
