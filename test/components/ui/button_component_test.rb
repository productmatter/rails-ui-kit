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
      default: 'h-9',
      sm: 'h-8',
      lg: 'h-10',
      icon: 'size-9'
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

      assert_includes button_classes, 'h-10'
      assert_not_includes button_classes, 'h-9'
      assert_not_includes button_classes, 'h-8'
    end

    test 'accepts string variant and size values' do
      render_inline(Ui::ButtonComponent.new(variant: 'outline', size: 'sm')) { 'Save' }

      assert_includes button_classes, 'border-input'
      assert_includes button_classes, 'h-8'
    end

    test 'defaults to the default variant and size' do
      render_inline(Ui::ButtonComponent.new) { 'Save' }

      assert_includes button_classes, 'bg-primary'
      assert_includes button_classes, 'h-9'
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
      assert_includes button_classes, 'h-10'
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

    test 'carries a focus-visible ring drawn from the ring token' do
      render_inline(Ui::ButtonComponent.new) { 'Save' }

      assert_includes button_classes, 'focus-visible:ring-ring/50'
      assert_includes button_classes, 'focus-visible:ring-[3px]'
    end

    test 'sizes an unsized inline svg child' do
      render_inline(Ui::ButtonComponent.new) { 'Save' }

      assert_includes button_classes, "[&_svg:not([class*='size-'])]:size-4"
      assert_includes button_classes, '[&_svg]:shrink-0'
    end

    test 'caller class wins over a conflicting variant class' do
      render_inline(Ui::ButtonComponent.new(class: 'bg-red-500')) { 'Save' }

      assert_includes button_classes, 'bg-red-500'
      assert_not_includes button_classes, 'bg-primary'
    end

    test 'caller class wins over a conflicting size class' do
      render_inline(Ui::ButtonComponent.new(size: :lg, class: 'h-20')) { 'Save' }

      assert_includes button_classes, 'h-20'
      assert_not_includes button_classes, 'h-10'
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
