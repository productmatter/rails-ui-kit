# frozen_string_literal: true

require 'test_helper'

module Ui
  class BaseTest < ViewComponent::TestCase
    # Throwaway component that exists only to exercise Ui::Base directly.
    class ProbeComponent < Ui::Base
      data_slot 'probe'

      class_variants(
        base: 'inline-flex rounded-md',
        variants: {
          background: {
            primary: 'bg-primary text-primary-foreground',
            muted: 'bg-muted text-muted-foreground'
          },
          size: {
            sm: 'h-8 px-3',
            lg: 'h-10 px-6'
          }
        },
        defaults: { background: :primary, size: :sm }
      )

      def initialize(background: :primary, size: :sm, **html_attributes)
        @background = background
        @size = size
        super(**html_attributes)
      end

      def variant_values
        { background: @background, size: @size }
      end

      def call
        content_tag(:div, content, root_attributes(data: { controller: 'probe' }))
      end
    end

    # Inherits Ui::Base without declaring variants or a data-slot.
    class BareComponent < Ui::Base
      def call
        content_tag(:span, content, root_attributes)
      end
    end

    def probe_classes
      page.find('[data-slot=probe]')['class'].split
    end

    test 'caller_class_wins over a conflicting variant default' do
      render_inline(ProbeComponent.new(background: :primary, class: 'bg-red-500')) { 'x' }

      assert_includes probe_classes, 'bg-red-500'
      assert_not_includes probe_classes, 'bg-primary'
    end

    test 'caller_class_wins on every conflicting axis at once' do
      render_inline(ProbeComponent.new(background: :primary, size: :lg, class: 'bg-red-500 h-16 px-1')) { 'x' }

      assert_includes probe_classes, 'bg-red-500'
      assert_includes probe_classes, 'h-16'
      assert_includes probe_classes, 'px-1'
      assert_not_includes probe_classes, 'bg-primary'
      assert_not_includes probe_classes, 'h-10'
      assert_not_includes probe_classes, 'px-6'
    end

    test 'caller_class_wins without dropping non-conflicting variant classes' do
      render_inline(ProbeComponent.new(class: 'bg-red-500')) { 'x' }

      assert_includes probe_classes, 'inline-flex'
      assert_includes probe_classes, 'rounded-md'
      assert_includes probe_classes, 'text-primary-foreground'
    end

    test 'renders variant defaults when no class is passed' do
      render_inline(ProbeComponent.new) { 'x' }

      assert_includes probe_classes, 'bg-primary'
      assert_includes probe_classes, 'h-8'
    end

    test 'resolves the requested variant over the default' do
      render_inline(ProbeComponent.new(background: :muted, size: :lg)) { 'x' }

      assert_includes probe_classes, 'bg-muted'
      assert_includes probe_classes, 'h-10'
      assert_not_includes probe_classes, 'bg-primary'
    end

    test 'stamps the declared data-slot on the root element' do
      render_inline(ProbeComponent.new) { 'x' }

      assert_selector "div[data-slot='probe']"
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(ProbeComponent.new(id: 'probe-1', tabindex: 2, title: 'Hello')) { 'x' }

      assert_selector "div#probe-1[tabindex='2'][title='Hello']"
    end

    test 'merges caller data attributes with the component own data attributes' do
      render_inline(ProbeComponent.new(data: { testid: 'probe', action: 'click->probe#go' })) { 'x' }

      assert_selector "div[data-slot='probe'][data-controller='probe'][data-testid='probe'][data-action='click->probe#go']"
    end

    test 'expands a caller aria hash onto the root element' do
      render_inline(ProbeComponent.new(aria: { label: 'Probe', hidden: true })) { 'x' }

      assert_selector "div[aria-label='Probe'][aria-hidden='true']"
    end

    test 'a caller data attribute overrides the component own value for the same key' do
      render_inline(ProbeComponent.new(data: { controller: 'other' })) { 'x' }

      assert_selector "div[data-controller='other']"
    end

    test 'renders content inside the root element' do
      render_inline(ProbeComponent.new) { 'Probe body' }

      assert_selector '[data-slot=probe]', text: 'Probe body'
    end

    test 'a component without variants or a data-slot renders no class attribute' do
      render_inline(BareComponent.new) { 'x' }

      assert_selector 'span', text: 'x'
      assert_nil page.find('span')['class']
      assert_no_selector 'span[data-slot]'
    end

    test 'a component without variants still merges a caller class' do
      render_inline(BareComponent.new(class: 'bg-red-500 bg-blue-500')) { 'x' }

      assert_equal 'bg-blue-500', page.find('span')['class']
    end

    test 'one merger instance is shared by every component' do
      assert_same Ui::Base::MERGER, Ui::ButtonComponent::MERGER
    end
  end
end
