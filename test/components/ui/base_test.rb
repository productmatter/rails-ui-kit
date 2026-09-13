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
        content_tag(:div, content, root_attributes(data: { controller: 'probe' }, aria: { live: 'polite' }))
      end
    end

    # Declares a boolean axis through class_variants' string shorthand.
    class ToggleComponent < Ui::Base
      class_variants(base: 'block', variants: { active: 'font-bold' })

      def initialize(active: false, **html_attributes)
        @active = active
        super(**html_attributes)
      end

      def variant_values
        { active: @active }
      end

      def call
        content_tag(:span, content, root_attributes)
      end
    end

    # Behaves as Ui::Base does outside development and test.
    class LenientProbeComponent < ProbeComponent
      def self.raise_on_unknown_variant?
        false
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

    # --- BASE1: a nil data:/aria: must not wipe the component's own attributes ---

    test 'a nil data hash keeps the data-slot and the component own data attributes' do
      render_inline(ProbeComponent.new(data: nil)) { 'x' }

      assert_selector "div[data-slot='probe'][data-controller='probe']"
    end

    test 'a nil aria hash keeps the component own aria attributes' do
      render_inline(ProbeComponent.new(aria: nil)) { 'x' }

      assert_selector "div[aria-live='polite']"
    end

    # --- BASE2: string keys normalise, never duplicate, and the caller wins ---

    test 'a string class key is merged like a symbol one' do
      html = render_inline(ProbeComponent.new('class' => 'bg-red-500')) { 'x' }.to_html

      assert_equal 1, html.scan(/\sclass=/).size
      assert_includes probe_classes, 'bg-red-500'
      assert_not_includes probe_classes, 'bg-primary'
    end

    test 'a flat string data-slot key overrides the slot without duplicating it' do
      html = render_inline(ProbeComponent.new('data-slot' => 'custom')) { 'x' }.to_html

      assert_equal 1, html.scan(/\sdata-slot=/).size
      assert_selector "div[data-slot='custom'][data-controller='probe']"
    end

    test 'string keys inside a data hash override the component own keys without duplicating them' do
      html = render_inline(ProbeComponent.new(data: { 'slot' => 'custom', 'controller' => 'other' })) { 'x' }.to_html

      assert_equal 1, html.scan(/\sdata-slot=/).size
      assert_equal 1, html.scan(/\sdata-controller=/).size
      assert_selector "div[data-slot='custom'][data-controller='other']"
    end

    test 'flat data- and aria- keys fold into the component own hashes' do
      html = render_inline(ProbeComponent.new('data-controller' => 'other', 'data-turbo-frame' => 'modal', 'aria-live': 'off')) { 'x' }.to_html

      assert_equal 1, html.scan(/\sdata-controller=/).size
      assert_equal 1, html.scan(/\saria-live=/).size
      assert_selector "div[data-slot='probe'][data-controller='other'][data-turbo-frame='modal'][aria-live='off']"
    end

    test 'dashed and underscored data keys are the same attribute' do
      html = render_inline(ProbeComponent.new(data: { turbo_frame: 'a', 'turbo-frame' => 'b' })) { 'x' }.to_html

      assert_equal 1, html.scan(/\sdata-turbo-frame=/).size
      assert_selector "div[data-turbo-frame='b']"
    end

    # --- BASE4: class: takes Rails' conditional forms ---

    test 'class accepts an array with a conditional hash' do
      render_inline(ProbeComponent.new(class: ['bg-red-500', { 'px-1' => true, 'hidden' => false }])) { 'x' }

      assert_includes probe_classes, 'bg-red-500'
      assert_includes probe_classes, 'px-1'
      assert_not_includes probe_classes, 'hidden'
      assert_not_includes probe_classes, 'px-3'
      assert_no_match(/[{}"=>]/, page.find('[data-slot=probe]')['class'])
    end

    test 'class accepts a conditional hash on its own' do
      render_inline(ProbeComponent.new(class: { 'bg-red-500' => true, 'bg-blue-500' => false })) { 'x' }

      assert_includes probe_classes, 'bg-red-500'
      assert_not_includes probe_classes, 'bg-blue-500'
    end

    test 'class tokens with ampersands are escaped exactly once' do
      html = render_inline(ProbeComponent.new(class: ['[&>svg]:size-5'])) { 'x' }.to_html

      assert_includes probe_classes, '[&>svg]:size-5'
      assert_not_includes html, '&amp;amp;'
    end

    # --- BASE5: unknown variant values fail loudly in development and test ---

    test 'an unknown variant value raises with the axis and the values it accepts' do
      error = assert_raises(Ui::Base::UnknownVariantError) do
        render_inline(ProbeComponent.new(background: :primray)) { 'x' }
      end

      assert_match(/background: :primray/, error.message)
      assert_match(/:primary, :muted/, error.message)
    end

    test 'raises on unknown variant values in the test environment' do
      assert ProbeComponent.raise_on_unknown_variant?
    end

    test 'a string variant value resolves to the declared symbol' do
      render_inline(ProbeComponent.new(background: 'muted', size: 'lg')) { 'x' }

      assert_includes probe_classes, 'bg-muted'
      assert_includes probe_classes, 'h-10'
    end

    test 'a nil variant value falls back to the default' do
      render_inline(ProbeComponent.new(background: nil, size: nil)) { 'x' }

      assert_includes probe_classes, 'bg-primary'
      assert_includes probe_classes, 'h-8'
    end

    test 'a boolean axis accepts true and false' do
      render_inline(ToggleComponent.new(active: true)) { 'x' }
      assert_includes page.find('span')['class'].split, 'font-bold'

      render_inline(ToggleComponent.new(active: false)) { 'x' }
      assert_not_includes page.find('span')['class'].split, 'font-bold'
    end

    test 'outside development and test an unknown variant logs a warning and renders the default' do
      log = StringIO.new
      original_logger = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(log)

      render_inline(LenientProbeComponent.new(background: :primray)) { 'x' }

      assert_includes probe_classes, 'bg-primary'
      assert_match(/background: :primray/, log.string)
    ensure
      Rails.logger = original_logger
    end

    test 'one merger instance is shared by every component' do
      assert_same Ui::Base::MERGER, Ui::ButtonComponent::MERGER
    end

    # --- BASE6: boolean HTML attributes normalise false-ish strings to absent ---

    # `visible: :all` throughout: Capybara treats a rendered `hidden` attribute as
    # an invisible element and would filter it out of an unqualified selector match,
    # which is exactly the attribute this test suite is asserting on.
    Ui::Base::BOOLEAN_ATTRIBUTES.each do |attribute|
      Ui::Base::FALSE_STRINGS.each do |false_string|
        test "#{attribute}: #{false_string.inspect} renders the attribute absent" do
          render_inline(BareComponent.new(attribute => false_string)) { 'x' }

          assert_no_selector "span[#{attribute}]", visible: :all
        end
      end

      test "#{attribute}: true renders the attribute" do
        render_inline(BareComponent.new(attribute => true)) { 'x' }

        assert_selector "span[#{attribute}]", visible: :all
      end

      test "#{attribute}: 'true' renders the attribute" do
        render_inline(BareComponent.new(attribute => 'true')) { 'x' }

        assert_selector "span[#{attribute}]", visible: :all
      end

      test "bare presence of #{attribute} renders the attribute" do
        render_inline(BareComponent.new(attribute => attribute.to_s)) { 'x' }

        assert_selector "span[#{attribute}]", visible: :all
      end

      test "#{attribute}: nil renders the attribute absent" do
        render_inline(BareComponent.new(attribute => nil)) { 'x' }

        assert_no_selector "span[#{attribute}]", visible: :all
      end
    end

    test 'aria-invalid="false" survives verbatim, unaffected by boolean normalisation' do
      render_inline(BareComponent.new(aria: { invalid: 'false' })) { 'x' }

      assert_selector "span[aria-invalid='false']"
    end

    test 'aria-disabled="false" survives verbatim' do
      render_inline(BareComponent.new(aria: { disabled: 'false' })) { 'x' }

      assert_selector "span[aria-disabled='false']"
    end

    test 'aria-expanded="false" survives verbatim' do
      render_inline(BareComponent.new(aria: { expanded: 'false' })) { 'x' }

      assert_selector "span[aria-expanded='false']"
    end

    test 'aria-checked and aria-pressed false strings survive verbatim' do
      render_inline(BareComponent.new(aria: { checked: 'false', pressed: 'false' })) { 'x' }

      assert_selector "span[aria-checked='false'][aria-pressed='false']"
    end

    test 'data attribute string values, including "false", survive verbatim' do
      render_inline(BareComponent.new(data: { enabled: 'false', count: '0', label: '' })) { 'x' }

      assert_selector "span[data-enabled='false'][data-count='0'][data-label='']"
    end
  end
end
