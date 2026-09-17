# frozen_string_literal: true

require 'test_helper'

module Ui
  class ButtonComponentTest < ViewComponent::TestCase
    VARIANT_MARKERS = {
      default: 'bg-primary',
      destructive: 'bg-destructive',
      outline: 'border-input',
      secondary: 'bg-secondary',
      ghost: 'hover:bg-accent',
      link: 'underline-offset-4'
    }.freeze

    SIZE_MARKERS = {
      default: 'h-(--control-height)',
      sm: 'h-(--control-height-sm)',
      lg: 'h-(--control-height-lg)',
      icon: 'size-(--control-height)'
    }.freeze

    def button_classes
      page.find('[data-slot=button]')['class'].split
    end

    test 'renders a button element with a type by default' do
      render_inline(Ui::ButtonComponent.new) { 'Save' }

      assert_selector "button[type='button']", text: 'Save'
    end

    test 'stamps data-slot on the root element' do
      render_inline(Ui::ButtonComponent.new) { 'Save' }

      assert_selector "button[data-slot='button']"
    end

    test 'renders shared base classes on every button' do
      render_inline(Ui::ButtonComponent.new) { 'Save' }

      assert_includes button_classes, 'inline-flex'
      assert_includes button_classes, 'rounded-md'
      assert_includes button_classes, 'text-sm'
    end

    VARIANT_MARKERS.each do |variant, marker|
      test "renders the #{variant} variant" do
        render_inline(Ui::ButtonComponent.new(variant: variant)) { 'Save' }

        assert_includes button_classes, marker
      end
    end

    test 'renders only the requested variant classes' do
      render_inline(Ui::ButtonComponent.new(variant: :secondary)) { 'Save' }

      assert_includes button_classes, 'bg-secondary'
      assert_not_includes button_classes, 'bg-primary'
      assert_not_includes button_classes, 'bg-destructive'
    end

    test 'renders the destructive variant label in destructive-foreground, not primary-foreground' do
      render_inline(Ui::ButtonComponent.new(variant: :destructive)) { 'Delete' }

      assert_includes button_classes, 'text-destructive-foreground'
      assert_not_includes button_classes, 'text-primary-foreground'
    end

    SIZE_MARKERS.each do |size, marker|
      test "renders the #{size} size" do
        render_inline(Ui::ButtonComponent.new(size: size)) { 'Save' }

        assert_includes button_classes, marker
      end
    end

    test 'renders only the requested size classes' do
      render_inline(Ui::ButtonComponent.new(size: :lg)) { 'Save' }

      assert_includes button_classes, 'h-(--control-height-lg)'
      assert_not_includes button_classes, 'h-(--control-height)'
      assert_not_includes button_classes, 'h-(--control-height-sm)'
    end

    test 'accepts string variant and size values' do
      render_inline(Ui::ButtonComponent.new(variant: 'outline', size: 'sm')) { 'Save' }

      assert_includes button_classes, 'border-input'
      assert_includes button_classes, 'h-(--control-height-sm)'
    end

    test 'defaults to the default variant and size' do
      render_inline(Ui::ButtonComponent.new) { 'Save' }

      assert_includes button_classes, 'bg-primary'
      assert_includes button_classes, 'h-(--control-height)'
    end

    test 'renders an anchor when href is given' do
      render_inline(Ui::ButtonComponent.new(href: '/settings')) { 'Settings' }

      assert_selector "a[href='/settings'][data-slot='button']", text: 'Settings'
      assert_no_selector 'button'
    end

    test 'an anchor carries no type attribute' do
      render_inline(Ui::ButtonComponent.new(href: '/settings')) { 'Settings' }

      assert_nil page.find('a')['type']
    end

    test 'an anchor keeps its variant and size classes' do
      render_inline(Ui::ButtonComponent.new(href: '/settings', variant: :outline, size: :lg)) { 'Settings' }

      assert_includes button_classes, 'border-input'
      assert_includes button_classes, 'h-(--control-height-lg)'
    end

    test 'accepts a custom button type' do
      render_inline(Ui::ButtonComponent.new(type: 'submit')) { 'Save' }

      assert_selector "button[type='submit']"
    end

    test 'reflects disabled on the button element' do
      render_inline(Ui::ButtonComponent.new(disabled: true)) { 'Save' }

      assert_selector 'button[disabled]'
    end

    test 'a disabled anchor drops its href and is announced as a disabled link' do
      render_inline(Ui::ButtonComponent.new(href: '/settings', disabled: true)) { 'Settings' }

      assert_selector "a[role='link'][aria-disabled='true']", text: 'Settings'
      assert_nil page.find('a')['href']
      assert_nil page.find('a')['disabled']
    end

    test 'carries disabled styling hooks for both element forms' do
      render_inline(Ui::ButtonComponent.new) { 'Save' }

      assert_includes button_classes, 'disabled:opacity-50'
      assert_includes button_classes, 'aria-disabled:opacity-50'
    end

    # BTN1/BTN4: an outline survives forced-colors mode, where box-shadow rings are dropped.
    test 'draws its focus indicator as an offset outline from the ring token, not a box-shadow ring' do
      render_inline(Ui::ButtonComponent.new) { 'Save' }

      assert_includes button_classes, 'focus-visible:outline-2'
      assert_includes button_classes, 'focus-visible:outline-offset-2'
      assert_includes button_classes, 'focus-visible:outline-ring'
      assert_not_includes button_classes, 'outline-none'
      assert_empty button_classes.grep(/ring-\[|:ring-ring/)
    end

    test 'every variant shares the ring token focus colour' do
      VARIANT_MARKERS.each_key do |variant|
        render_inline(Ui::ButtonComponent.new(variant: variant)) { 'Save' }

        assert_includes button_classes, 'focus-visible:outline-ring', "#{variant} variant"
        assert_empty button_classes.grep(/focus-visible:(ring|outline)-destructive/), "#{variant} variant"
      end
    end

    # BTN3
    test 'the outline variant sets its own text colour' do
      render_inline(Ui::ButtonComponent.new(variant: :outline)) { 'Save' }

      assert_includes button_classes, 'text-foreground'
    end

    # BTN6
    test 'sizes a direct svg child at zero specificity so a sizing class on the svg wins' do
      render_inline(Ui::ButtonComponent.new) { 'Save' }

      assert_includes button_classes, '[:where(&>svg)]:size-4'
      assert_includes button_classes, '[&>svg]:shrink-0'
    end

    test 'icon sizing does not reach nested svgs' do
      render_inline(Ui::ButtonComponent.new) { 'Save' }

      assert_empty button_classes.grep(/\[&_svg[^\]]*\]:(size|h|w)-/)
    end

    # BTN5
    test 'nil variant and size fall back to the defaults' do
      render_inline(Ui::ButtonComponent.new(variant: nil, size: nil)) { 'Save' }

      assert_includes button_classes, 'bg-primary'
      assert_includes button_classes, 'h-(--control-height)'
    end

    test 'an unknown variant raises in development and test' do
      assert_raises(Ui::Base::UnknownVariantError) { render_inline(Ui::ButtonComponent.new(variant: :primary)) { 'Save' } }
      assert_raises(Ui::Base::UnknownVariantError) { render_inline(Ui::ButtonComponent.new(size: :xl)) { 'Save' } }
    end

    # BTN7
    test 'a string disabled key disables a link' do
      render_inline(Ui::ButtonComponent.new(href: '/settings', 'disabled' => true)) { 'Settings' }

      assert_selector "a[role='link'][aria-disabled='true']"
      assert_nil page.find('a')['href']
      assert_nil page.find('a')['disabled']
    end

    test 'a string disabled key disables a button' do
      render_inline(Ui::ButtonComponent.new('disabled' => true)) { 'Save' }

      assert_selector 'button[disabled]'
    end

    [false, 'false', '0', '', nil].each do |value|
      test "disabled: #{value.inspect} leaves a button enabled" do
        render_inline(Ui::ButtonComponent.new(disabled: value)) { 'Save' }

        assert_selector 'button'
        assert_no_selector 'button[disabled]'
      end

      test "disabled: #{value.inspect} leaves a link live" do
        render_inline(Ui::ButtonComponent.new(href: '/settings', disabled: value)) { 'Settings' }

        assert_selector "a[href='/settings']"
        assert_no_selector 'a[aria-disabled]'
      end
    end

    test 'caller class wins over a conflicting variant class' do
      render_inline(Ui::ButtonComponent.new(class: 'bg-red-500')) { 'Save' }

      assert_includes button_classes, 'bg-red-500'
      assert_not_includes button_classes, 'bg-primary'
    end

    test 'caller class wins over a conflicting size class' do
      render_inline(Ui::ButtonComponent.new(size: :lg, class: 'h-20')) { 'Save' }

      assert_includes button_classes, 'h-20'
      assert_not_includes button_classes, 'h-(--control-height-lg)'
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(Ui::ButtonComponent.new(id: 'save', name: 'commit', value: '1')) { 'Save' }

      assert_selector "button#save[name='commit'][value='1']"
    end

    test 'forwards data and aria attributes to the root element' do
      render_inline(Ui::ButtonComponent.new(data: { turbo_confirm: 'Sure?' }, aria: { label: 'Save record' })) { 'Save' }

      assert_selector "button[data-slot='button'][data-turbo-confirm='Sure?'][aria-label='Save record']"
    end

    test 'forwards attributes onto the anchor form too' do
      render_inline(Ui::ButtonComponent.new(href: '/settings', data: { turbo_frame: 'modal' })) { 'Settings' }

      assert_selector "a[data-slot='button'][data-turbo-frame='modal']"
    end

    test 'renders block content as the label' do
      render_inline(Ui::ButtonComponent.new) { '<span>Save</span>'.html_safe }

      assert_selector 'button span', text: 'Save'
    end
  end
end
