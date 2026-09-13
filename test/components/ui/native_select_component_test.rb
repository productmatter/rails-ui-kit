# frozen_string_literal: true

require 'test_helper'

module Ui
  class NativeSelectComponentTest < ViewComponent::TestCase
    SIZE_MARKERS = {
      default: 'h-9',
      sm: 'h-8'
    }.freeze

    def select_classes
      page.find('[data-slot=native-select]')['class'].split
    end

    def render_with_options
      render_inline(Ui::NativeSelectComponent.new(name: 'role')) do
        '<option value="member">Member</option><option value="admin">Admin</option>'.html_safe
      end
    end

    test 'renders a select element' do
      render_with_options

      assert_selector "select[name='role']"
      assert_selector 'option', count: 2
    end

    test 'stamps data-slot on the select, not the wrapper' do
      render_with_options

      assert_selector "select[data-slot='native-select']"
      assert_no_selector "div[data-slot='native-select']"
    end

    test 'renders shared control classes' do
      render_with_options

      assert_includes select_classes, 'border-input'
      assert_includes select_classes, 'bg-transparent'
      assert_includes select_classes, 'rounded-md'
      assert_includes select_classes, 'appearance-none'
    end

    test 'options and optgroups take popover colours through a descendant selector' do
      render_with_options

      assert_includes select_classes, '[&_option]:bg-popover'
      assert_includes select_classes, '[&_option]:text-popover-foreground'
      assert_includes select_classes, '[&_optgroup]:bg-popover'
      assert_includes select_classes, '[&_optgroup]:text-popover-foreground'
    end

    test 'renders a decorative chevron hidden from assistive tech' do
      render_with_options

      assert_selector "svg[aria-hidden='true']"
    end

    test 'the chevron sits outside the select, in a plain positioning wrapper' do
      render_with_options

      assert_selector "div.relative > select[data-slot='native-select']"
      assert_selector 'div.relative > svg'
    end

    test 'draws its focus indicator as an offset outline from the ring token, not a box-shadow ring' do
      render_with_options

      assert_includes select_classes, 'focus-visible:outline-2'
      assert_includes select_classes, 'focus-visible:outline-offset-2'
      assert_includes select_classes, 'focus-visible:outline-ring'
      assert_empty select_classes.grep(/ring-\[|:ring-ring/)
    end

    test 'carries disabled styling hooks' do
      render_with_options

      assert_includes select_classes, 'disabled:opacity-50'
      assert_includes select_classes, 'disabled:pointer-events-none'
    end

    test 'carries invalid styling hooks driven by aria-invalid' do
      render_with_options

      assert_includes select_classes, 'aria-invalid:border-destructive'
      assert_includes select_classes, 'aria-invalid:focus-visible:outline-destructive'
    end

    test 'reflects disabled on the select element' do
      render_inline(Ui::NativeSelectComponent.new(disabled: true))

      assert_selector 'select[disabled]'
    end

    test 'reflects aria-invalid on the select element' do
      render_inline(Ui::NativeSelectComponent.new(aria: { invalid: true }))

      assert_selector "select[aria-invalid='true']"
    end

    SIZE_MARKERS.each do |size, marker|
      test "renders the #{size} size" do
        render_inline(Ui::NativeSelectComponent.new(size: size))

        assert_includes select_classes, marker
      end
    end

    test 'renders only the requested size classes' do
      render_inline(Ui::NativeSelectComponent.new(size: :sm))

      assert_includes select_classes, 'h-8'
      assert_not_includes select_classes, 'h-9'
    end

    test 'accepts a string size value' do
      render_inline(Ui::NativeSelectComponent.new(size: 'sm'))

      assert_includes select_classes, 'h-8'
    end

    test 'defaults to the default size' do
      render_inline(Ui::NativeSelectComponent.new)

      assert_includes select_classes, 'h-9'
    end

    test 'nil size falls back to the default' do
      render_inline(Ui::NativeSelectComponent.new(size: nil))

      assert_includes select_classes, 'h-9'
    end

    test 'an unknown size raises in development and test' do
      assert_raises(Ui::Base::UnknownVariantError) { render_inline(Ui::NativeSelectComponent.new(size: :xl)) }
    end

    test 'caller class wins over a conflicting default' do
      render_inline(Ui::NativeSelectComponent.new(class: 'bg-red-500'))

      assert_includes select_classes, 'bg-red-500'
      assert_not_includes select_classes, 'bg-transparent'
    end

    test 'forwards arbitrary html attributes to the select element' do
      render_inline(Ui::NativeSelectComponent.new(id: 'role', name: 'role', required: true))

      assert_selector "select#role[name='role'][required]"
    end

    test 'forwards data and aria attributes to the select element' do
      render_inline(Ui::NativeSelectComponent.new(data: { controller: 'field' }, aria: { describedby: 'role-hint' }))

      assert_selector "select[data-slot='native-select'][data-controller='field'][aria-describedby='role-hint']"
    end
  end
end
