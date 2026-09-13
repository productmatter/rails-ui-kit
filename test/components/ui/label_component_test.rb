# frozen_string_literal: true

require 'test_helper'

module Ui
  class LabelComponentTest < ViewComponent::TestCase
    def label_classes
      page.find('[data-slot=label]')['class'].split
    end

    test 'renders a label element with its content' do
      render_inline(Ui::LabelComponent.new) { 'Email' }

      assert_selector 'label', text: 'Email'
    end

    test 'stamps data-slot on the root element' do
      render_inline(Ui::LabelComponent.new) { 'Email' }

      assert_selector "label[data-slot='label']"
    end

    test 'renders shared classes' do
      render_inline(Ui::LabelComponent.new) { 'Email' }

      assert_includes label_classes, 'text-sm'
      assert_includes label_classes, 'font-medium'
    end

    test 'carries dimming hooks for a disabled peer control and a disabled group' do
      render_inline(Ui::LabelComponent.new) { 'Email' }

      assert_includes label_classes, 'peer-disabled:opacity-50'
      assert_includes label_classes, 'group-data-[disabled=true]:opacity-50'
    end

    test 'for flows through attribute forwarding' do
      render_inline(Ui::LabelComponent.new(for: 'email')) { 'Email' }

      assert_selector "label[for='email']"
    end

    test 'caller class wins over a conflicting default' do
      render_inline(Ui::LabelComponent.new(class: 'text-lg')) { 'Email' }

      assert_includes label_classes, 'text-lg'
      assert_not_includes label_classes, 'text-sm'
    end

    test 'forwards data and aria attributes to the root element' do
      render_inline(Ui::LabelComponent.new(data: { controller: 'field' }, aria: { hidden: 'true' })) { 'Email' }

      assert_selector "label[data-slot='label'][data-controller='field'][aria-hidden='true']"
    end
  end
end
