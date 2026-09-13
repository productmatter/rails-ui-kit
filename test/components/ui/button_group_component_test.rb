# frozen_string_literal: true

require 'test_helper'

module Ui
  class ButtonGroupComponentTest < ViewComponent::TestCase
    def group_classes
      page.find('[data-slot=button-group]')['class'].split
    end

    def render_full_group
      render_inline(Ui::ButtonGroupComponent.new) do |group|
        group.with_item_button { 'Bold' }
        group.with_item_separator(orientation: :vertical)
        group.with_item_button { 'Italic' }
        group.with_item_text { 'px' }
      end
    end

    test 'renders a div with role=group' do
      render_full_group

      assert_selector "div[data-slot='button-group'][role='group']"
    end

    test 'stamps data-slot on the root element' do
      render_full_group

      assert_selector "[data-slot='button-group']"
    end

    test 'renders each child with its data-slot in call order' do
      render_full_group

      slots = page.all('[data-slot=button-group] > [data-slot]').map { |node| node['data-slot'] }
      assert_equal %w[button separator button button-group-text], slots
    end

    test 'children stay in call order whatever order the caller sets them in' do
      render_inline(Ui::ButtonGroupComponent.new) do |group|
        group.with_item_text { 'px' }
        group.with_item_button { 'Bold' }
      end

      slots = page.all('[data-slot=button-group] > [data-slot]').map { |node| node['data-slot'] }
      assert_equal %w[button-group-text button], slots
    end

    test 'a button child renders the real Ui::ButtonComponent, not a copy' do
      render_full_group

      assert_selector "[data-slot='button-group'] > button[data-slot='button']", text: 'Bold'
    end

    test 'a separator child renders the real Ui::SeparatorComponent' do
      render_full_group

      assert_selector "[data-slot='button-group'] > [data-slot='separator'][role='none']"
    end

    test 'a text child renders under the button-group-text data-slot' do
      render_full_group

      assert_selector "[data-slot='button-group'] > [data-slot='button-group-text']", text: 'px'
    end

    test 'defaults to horizontal orientation' do
      render_full_group

      assert_includes group_classes, 'flex-row'
    end

    test 'renders vertical orientation classes' do
      render_inline(Ui::ButtonGroupComponent.new(orientation: :vertical)) { |group| group.with_item_button { 'Bold' } }

      assert_includes group_classes, 'flex-col'
      assert_not_includes group_classes, 'flex-row'
    end

    test 'accepts a string orientation value' do
      render_inline(Ui::ButtonGroupComponent.new(orientation: 'vertical')) { |group| group.with_item_button { 'Bold' } }

      assert_includes group_classes, 'flex-col'
    end

    test 'nil orientation falls back to the default' do
      render_inline(Ui::ButtonGroupComponent.new(orientation: nil)) { |group| group.with_item_button { 'Bold' } }

      assert_includes group_classes, 'flex-row'
    end

    test 'an unknown orientation raises in development and test' do
      assert_raises(Ui::Base::UnknownVariantError) do
        render_inline(Ui::ButtonGroupComponent.new(orientation: :diagonal)) { |group| group.with_item_button { 'Bold' } }
      end
    end

    test 'rounds only the first and last button, squaring everything between' do
      render_full_group

      assert_includes group_classes, '[&>[data-slot^=button]:first-child]:rounded-l-md'
      assert_includes group_classes, '[&>[data-slot^=button]:last-child]:rounded-r-md'
      assert_includes group_classes, '[&>[data-slot^=button]]:rounded-none'
    end

    test 'lifts a focused button above its neighbours so its outline is not clipped' do
      render_full_group

      assert_includes group_classes, '[&>[data-slot^=button]]:focus-visible:relative'
      assert_includes group_classes, '[&>[data-slot^=button]]:focus-visible:z-10'
    end

    test 'caller class wins over a conflicting default' do
      render_inline(Ui::ButtonGroupComponent.new(class: 'w-full')) { |group| group.with_item_button { 'Bold' } }

      assert_includes group_classes, 'w-full'
      assert_not_includes group_classes, 'w-fit'
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(Ui::ButtonGroupComponent.new(id: 'text-align')) { |group| group.with_item_button { 'Bold' } }

      assert_selector "div#text-align[data-slot='button-group']"
    end

    test 'forwards data and aria attributes to the root element, including a group name' do
      render_inline(Ui::ButtonGroupComponent.new(aria: { label: 'Text alignment' }, data: { testid: 'align' })) do |group|
        group.with_item_button { 'Bold' }
      end

      assert_selector "[data-slot='button-group'][aria-label='Text alignment'][data-testid='align']"
    end

    test 'nested children compose from an erb template' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::ButtonGroupComponent.new(id: "erb-group") do |group| %>
            <% group.with_item_button(variant: :outline) { "Bold" } %>
            <% group.with_item_separator(orientation: :vertical) %>
            <% group.with_item_button(variant: :outline) { "Italic" } %>
          <% end %>
        ERB
      end

      assert_selector "#erb-group > [data-slot='button'] + [data-slot='separator'] + [data-slot='button']"
      assert_equal 2, page.all("#erb-group > [data-slot='button']").size
    end
  end
end
