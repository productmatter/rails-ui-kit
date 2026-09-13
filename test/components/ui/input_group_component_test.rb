# frozen_string_literal: true

require 'test_helper'

module Ui
  class InputGroupComponentTest < ViewComponent::TestCase
    ALIGN_MARKERS = {
      'inline-start': 'order-first',
      'inline-end': 'order-last',
      'block-start': 'basis-full',
      'block-end': 'basis-full'
    }.freeze

    def group_classes
      page.find('[data-slot=input-group]')['class'].split
    end

    def addon_classes
      page.find('[data-slot=input-group-addon]')['class'].split
    end

    def render_with_input
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::InputGroupComponent.new do |group| %>
            <% group.with_addon(align: "inline-start", aria: { hidden: true }) { "$" } %>
            <%= render Ui::InputComponent.new(name: "amount", placeholder: "0.00") %>
          <% end %>
        ERB
      end
    end

    test 'renders the root with the input-group data-slot' do
      render_with_input

      assert_selector "div[data-slot='input-group']"
    end

    test 'renders the control as plain content next to its addon' do
      render_with_input

      assert_selector "[data-slot='input-group'] > [data-slot='input-group-addon']", text: '$'
      assert_selector "[data-slot='input-group'] > [data-slot='input']"
    end

    test 'a group with no addons renders the control alone' do
      render_in_view_context do
        render(inline: '<%= render(Ui::InputGroupComponent.new) { render(Ui::InputComponent.new(name: "q")) } %>')
      end

      assert_selector "[data-slot='input-group'] > [data-slot='input']"
      assert_no_selector "[data-slot='input-group-addon']"
    end

    test 'renders every addon in call order under its own data-slot' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::InputGroupComponent.new do |group| %>
            <% group.with_addon(align: "inline-start") { "search" } %>
            <%= render Ui::InputComponent.new(name: "q") %>
            <% group.with_addon(align: "inline-end") { "clear" } %>
          <% end %>
        ERB
      end

      addons = page.all('[data-slot=input-group-addon]').map(&:text)
      assert_equal %w[search clear], addons
    end

    ALIGN_MARKERS.each do |align, marker|
      test "the #{align} addon carries its positioning classes" do
        render_inline(Ui::InputGroupComponent.new) { |group| group.with_addon(align: align) { 'x' } }

        assert_includes addon_classes, marker
      end
    end

    test 'stamps a data-align attribute the group reads to switch layout' do
      render_inline(Ui::InputGroupComponent.new) { |group| group.with_addon(align: 'block-start') { 'x' } }

      assert_selector "[data-slot='input-group-addon'][data-align='block-start']"
    end

    test 'defaults an addon to inline-start' do
      render_inline(Ui::InputGroupComponent.new) { |group| group.with_addon { 'x' } }

      assert_selector "[data-slot='input-group-addon'][data-align='inline-start']"
    end

    test 'an unknown addon align raises in development and test' do
      assert_raises(Ui::Base::UnknownVariantError) do
        render_inline(Ui::InputGroupComponent.new) { |group| group.with_addon(align: :diagonal) { 'x' } }
      end
    end

    test 'the group switches to a column layout when it holds a block addon' do
      render_with_input

      assert_includes group_classes, 'has-[[data-align=block-start]]:flex-col'
      assert_includes group_classes, 'has-[[data-align=block-end]]:flex-col'
    end

    test 'the group draws the focus indicator, not the control' do
      render_with_input

      assert_includes group_classes, 'has-[[data-slot=input]:focus-visible]:outline-2'
      assert_includes group_classes, 'has-[[data-slot=input]:focus-visible]:outline-offset-2'
      assert_includes group_classes, 'has-[[data-slot=input]:focus-visible]:outline-ring'
      assert_includes group_classes, '[&_[data-slot=input]]:focus-visible:outline-0'
      assert_empty group_classes.grep(/ring-\[|:ring-ring/)
    end

    test 'suppresses the control boundary and fill so only the group draws them' do
      render_with_input

      assert_includes group_classes, '[&_[data-slot=input]]:border-transparent'
      assert_includes group_classes, '[&_[data-slot=input]]:bg-transparent'
      assert_includes group_classes, '[&_[data-slot=input]]:shadow-none'
    end

    test 'the group reflects an invalid control on its own boundary and ring' do
      render_with_input

      assert_includes group_classes, 'has-[[data-slot=input][aria-invalid=true]]:border-destructive'
      assert_includes group_classes, 'has-[[data-slot=input][aria-invalid=true]:focus-visible]:outline-destructive'
    end

    test 'renders shared control classes on the group itself' do
      render_with_input

      assert_includes group_classes, 'border-input'
      assert_includes group_classes, 'bg-transparent'
      assert_includes group_classes, 'rounded-md'
    end

    test 'caller class wins over a conflicting default' do
      render_inline(Ui::InputGroupComponent.new(class: 'rounded-none')) { |group| group.with_addon { 'x' } }

      assert_includes group_classes, 'rounded-none'
      assert_not_includes group_classes, 'rounded-md'
    end

    test 'caller class on an addon wins over a conflicting default' do
      render_inline(Ui::InputGroupComponent.new) { |group| group.with_addon(align: 'inline-end', class: 'order-first') { 'x' } }

      assert_includes addon_classes, 'order-first'
      assert_not_includes addon_classes, 'order-last'
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(Ui::InputGroupComponent.new(id: 'amount-group')) { |group| group.with_addon { '$' } }

      assert_selector "div#amount-group[data-slot='input-group']"
    end

    test 'forwards data and aria attributes to the root element' do
      render_inline(Ui::InputGroupComponent.new(data: { testid: 'amount' })) { |group| group.with_addon { '$' } }

      assert_selector "[data-slot='input-group'][data-testid='amount']"
    end

    test 'forwards html attributes to an addon' do
      render_inline(Ui::InputGroupComponent.new) { |group| group.with_addon(id: 'currency', aria: { hidden: true }) { '$' } }

      assert_selector "div#currency[data-slot='input-group-addon'][aria-hidden='true']"
    end

    test 'nested parts compose from an erb template' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::InputGroupComponent.new(id: "erb-group") do |group| %>
            <% group.with_addon(align: "inline-start") { "$" } %>
            <%= render Ui::InputComponent.new(name: "amount") %>
            <% group.with_addon(align: "inline-end") { "USD" } %>
          <% end %>
        ERB
      end

      assert_selector "#erb-group > [data-slot='input-group-addon']", count: 2
      assert_selector "#erb-group > [data-slot='input']"
      assert_equal 1, page.all("#erb-group > [data-slot='input']").size
    end
  end
end
