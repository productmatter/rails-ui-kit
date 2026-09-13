# frozen_string_literal: true

require 'test_helper'

module Ui
  class BadgeComponentTest < ViewComponent::TestCase
    VARIANT_MARKERS = {
      default: 'bg-primary',
      secondary: 'bg-secondary',
      destructive: 'bg-destructive',
      outline: 'border-input'
    }.freeze

    def badge_classes
      page.find('[data-slot=badge]')['class'].split
    end

    test 'renders a span element by default' do
      render_inline(Ui::BadgeComponent.new) { 'New' }

      assert_selector 'span', text: 'New'
      assert_no_selector 'a'
    end

    test 'stamps data-slot on the root element' do
      render_inline(Ui::BadgeComponent.new) { 'New' }

      assert_selector "span[data-slot='badge']"
    end

    test 'renders shared base classes on every badge' do
      render_inline(Ui::BadgeComponent.new) { 'New' }

      assert_includes badge_classes, 'inline-flex'
      assert_includes badge_classes, 'rounded-md'
      assert_includes badge_classes, 'text-xs'
    end

    VARIANT_MARKERS.each do |variant, marker|
      test "renders the #{variant} variant" do
        render_inline(Ui::BadgeComponent.new(variant: variant)) { 'New' }

        assert_includes badge_classes, marker
      end
    end

    test 'renders only the requested variant classes' do
      render_inline(Ui::BadgeComponent.new(variant: :secondary)) { 'New' }

      assert_includes badge_classes, 'bg-secondary'
      assert_not_includes badge_classes, 'bg-primary'
      assert_not_includes badge_classes, 'bg-destructive'
    end

    test 'renders the destructive variant label in destructive-foreground, not primary-foreground' do
      render_inline(Ui::BadgeComponent.new(variant: :destructive)) { 'Failed' }

      assert_includes badge_classes, 'text-destructive-foreground'
      assert_not_includes badge_classes, 'text-primary-foreground'
    end

    test 'accepts a string variant value' do
      render_inline(Ui::BadgeComponent.new(variant: 'outline')) { 'New' }

      assert_includes badge_classes, 'border-input'
    end

    test 'defaults to the default variant' do
      render_inline(Ui::BadgeComponent.new) { 'New' }

      assert_includes badge_classes, 'bg-primary'
    end

    test 'nil variant falls back to the default' do
      render_inline(Ui::BadgeComponent.new(variant: nil)) { 'New' }

      assert_includes badge_classes, 'bg-primary'
    end

    test 'an unknown variant raises in development and test' do
      assert_raises(Ui::Base::UnknownVariantError) { render_inline(Ui::BadgeComponent.new(variant: :primary)) { 'New' } }
    end

    test 'renders an anchor when href is given' do
      render_inline(Ui::BadgeComponent.new(href: '/releases/1')) { 'v1.0' }

      assert_selector "a[href='/releases/1'][data-slot='badge']", text: 'v1.0'
      assert_no_selector 'span'
    end

    test 'an anchor keeps its variant classes' do
      render_inline(Ui::BadgeComponent.new(href: '/releases/1', variant: :outline)) { 'v1.0' }

      assert_includes badge_classes, 'border-input'
    end

    test 'draws its focus indicator as an offset outline from the ring token, not a box-shadow ring' do
      render_inline(Ui::BadgeComponent.new(href: '/releases/1')) { 'v1.0' }

      assert_includes badge_classes, 'focus-visible:outline-2'
      assert_includes badge_classes, 'focus-visible:outline-offset-2'
      assert_includes badge_classes, 'focus-visible:outline-ring'
      assert_empty badge_classes.grep(/ring-\[|:ring-ring/)
    end

    test 'caller class wins over a conflicting variant class' do
      render_inline(Ui::BadgeComponent.new(class: 'bg-red-500')) { 'New' }

      assert_includes badge_classes, 'bg-red-500'
      assert_not_includes badge_classes, 'bg-primary'
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(Ui::BadgeComponent.new(id: 'status', title: 'Status')) { 'New' }

      assert_selector "span#status[title='Status']"
    end

    test 'forwards data and aria attributes to the root element' do
      render_inline(Ui::BadgeComponent.new(data: { testid: 'plan-badge' }, aria: { label: 'Plan: Pro' })) { 'Pro' }

      assert_selector "span[data-slot='badge'][data-testid='plan-badge'][aria-label='Plan: Pro']"
    end

    test 'renders block content as the label' do
      render_inline(Ui::BadgeComponent.new) { '<span class="dot"></span>Live'.html_safe }

      assert_selector 'span[data-slot=badge] span.dot'
      assert_text 'Live'
    end
  end
end
