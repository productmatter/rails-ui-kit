# frozen_string_literal: true

require 'test_helper'

module Ui
  class AlertComponentTest < ViewComponent::TestCase
    PART_SLOTS = %w[alert-icon alert-title alert-description].freeze

    VARIANT_MARKERS = {
      default: 'border-input',
      destructive: 'border-destructive'
    }.freeze

    def classes_for(slot)
      page.find("[data-slot='#{slot}']")['class'].split
    end

    def render_full_alert(**options)
      render_inline(Ui::AlertComponent.new(**options)) do |alert|
        alert.with_icon { '<svg viewBox="0 0 24 24"><path d="M12 2v10"/></svg>'.html_safe }
        alert.with_title { 'Update available' }
        alert.with_description { 'Restart the app to install it.' }
      end
    end

    test 'renders the root with the alert data-slot and token classes' do
      render_inline(Ui::AlertComponent.new) { |alert| alert.with_title { 'Heads up' } }

      assert_selector "div[data-slot='alert']"
      assert_includes classes_for('alert'), 'bg-card'
      assert_includes classes_for('alert'), 'text-card-foreground'
      assert_includes classes_for('alert'), 'border-input'
      assert_includes classes_for('alert'), 'rounded-lg'
    end

    test 'renders every part with its data-slot' do
      render_full_alert

      PART_SLOTS.each { |slot| assert_selector "[data-slot='alert'] [data-slot='#{slot}']", count: 1 }
    end

    test 'renders parts in the fixed order regardless of call order' do
      render_inline(Ui::AlertComponent.new) do |alert|
        alert.with_description { 'Restart the app to install it.' }
        alert.with_title { 'Update available' }
        alert.with_icon { '<svg viewBox="0 0 24 24"></svg>'.html_safe }
      end

      order = page.all("[data-slot='alert'] > [data-slot]").map { |node| node['data-slot'] }
      assert_equal %w[alert-icon alert-title alert-description], order
    end

    VARIANT_MARKERS.each do |variant, marker|
      test "renders the #{variant} variant" do
        render_inline(Ui::AlertComponent.new(variant: variant)) { |alert| alert.with_title { 'Heads up' } }

        assert_includes classes_for('alert'), marker
      end
    end

    test 'renders only the requested variant classes' do
      render_inline(Ui::AlertComponent.new(variant: :destructive)) { |alert| alert.with_title { 'Heads up' } }

      assert_includes classes_for('alert'), 'text-destructive'
      assert_not_includes classes_for('alert'), 'border-input'
    end

    test 'an unknown variant raises in development and test' do
      assert_raises(Ui::Base::UnknownVariantError) do
        render_inline(Ui::AlertComponent.new(variant: :warning)) { |alert| alert.with_title { 'Heads up' } }
      end
    end

    test 'opens a second grid column only when an icon is present' do
      render_inline(Ui::AlertComponent.new) { |alert| alert.with_title { 'No icon here' } }

      assert_includes classes_for('alert'), 'grid-cols-[0_1fr]'
      assert_not_includes classes_for('alert'), 'grid-cols-[1rem_1fr]'
    end

    test 'an icon opens the grid column' do
      render_full_alert

      assert_includes classes_for('alert'), 'grid-cols-[1rem_1fr]'
    end

    test 'omitted parts render no element' do
      render_inline(Ui::AlertComponent.new) { |alert| alert.with_title { 'Just a title' } }

      assert_selector "[data-slot='alert-title']", text: 'Just a title'
      assert_no_selector "[data-slot='alert-icon']"
      assert_no_selector "[data-slot='alert-description']"
    end

    test 'the icon is hidden from assistive tech by default' do
      render_full_alert

      assert_selector "[data-slot='alert-icon'][aria-hidden='true']"
    end

    test 'a caller can mark its icon as carrying meaning' do
      render_inline(Ui::AlertComponent.new) do |alert|
        alert.with_icon(aria: { hidden: false, label: 'Error' }) { '<svg viewBox="0 0 24 24"></svg>'.html_safe }
        alert.with_title { 'Failed' }
      end

      assert_selector "[data-slot='alert-icon'][aria-hidden='false'][aria-label='Error']"
    end

    test 'carries no role by default, so it is not announced as a live region' do
      render_full_alert

      assert_nil page.find('[data-slot=alert]')['role']
    end

    test 'a caller can inject a live-region role through forwarded attributes' do
      render_inline(Ui::AlertComponent.new(role: 'alert')) { |alert| alert.with_title { 'Saved' } }

      assert_selector "[data-slot='alert'][role='alert']"
    end

    test 'caller class on the root wins over a conflicting default' do
      render_inline(Ui::AlertComponent.new(class: 'rounded-none')) { |alert| alert.with_title { 'Heads up' } }

      assert_includes classes_for('alert'), 'rounded-none'
      assert_not_includes classes_for('alert'), 'rounded-lg'
    end

    test 'caller class on a part wins over a conflicting default' do
      render_inline(Ui::AlertComponent.new) { |alert| alert.with_title(class: 'line-clamp-none') { 'Heads up' } }

      assert_includes classes_for('alert-title'), 'line-clamp-none'
      assert_not_includes classes_for('alert-title'), 'line-clamp-1'
    end

    test 'forwards html attributes to the root element' do
      render_inline(Ui::AlertComponent.new(id: 'update-alert', data: { testid: 'alert' })) { |alert| alert.with_title { 'Heads up' } }

      assert_selector "div#update-alert[data-slot='alert'][data-testid='alert']"
    end

    test 'forwards html attributes to a part' do
      render_inline(Ui::AlertComponent.new) do |alert|
        alert.with_title(id: 'alert-heading') { 'Heads up' }
        alert.with_description(data: { testid: 'desc' }) { 'Details' }
      end

      assert_selector "div#alert-heading[data-slot='alert-title']"
      assert_selector "div[data-slot='alert-description'][data-testid='desc']"
    end

    test 'nested parts compose from an erb template' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::AlertComponent.new(id: "erb-alert", variant: :destructive) do |alert| %>
            <% alert.with_icon do %>
              <svg viewBox="0 0 24 24"><path d="M12 2v10"/></svg>
            <% end %>
            <% alert.with_title { "Payment failed" } %>
            <% alert.with_description do %>
              <p>Update your card to keep your subscription active.</p>
            <% end %>
          <% end %>
        ERB
      end

      assert_selector "#erb-alert > [data-slot='alert-icon']"
      assert_selector "#erb-alert > [data-slot='alert-title']", text: 'Payment failed'
      assert_selector "#erb-alert > [data-slot='alert-description'] p", text: 'Update your card to keep your subscription active.'
      assert_equal 1, page.all("[data-slot='alert-title']").size
    end
  end
end
