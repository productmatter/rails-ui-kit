# frozen_string_literal: true

require 'test_helper'

module Ui
  # The size scale Button, Input, Select and Textarea share (docs/specs/ui-control-sizing). Each
  # component's own test covers its markup; this holds what they have in common: the same token
  # at the same step, a caller's height winning over it, and an unknown step failing loudly. What
  # those classes measure in a browser is test/system/control_sizing_test.rb.
  class ControlSizeTest < ViewComponent::TestCase
    STATES = [%w[Draft draft], %w[Published published]].freeze

    HEIGHTS = {
      xs: 'h-(--control-height-xs)',
      sm: 'h-(--control-height-sm)',
      default: 'h-(--control-height)',
      lg: 'h-(--control-height-lg)',
      xl: 'h-(--control-height-xl)',
      '2xl': 'h-(--control-height-2xl)'
    }.freeze

    TEXTAREA_MINIMUMS = {
      xs: 'min-h-[calc(var(--control-height-xs)+var(--spacing)*7)]',
      sm: 'min-h-[calc(var(--control-height-sm)+var(--spacing)*7)]',
      default: 'min-h-[calc(var(--control-height)+var(--spacing)*7)]',
      lg: 'min-h-[calc(var(--control-height-lg)+var(--spacing)*7)]',
      xl: 'min-h-[calc(var(--control-height-xl)+var(--spacing)*7)]',
      '2xl': 'min-h-[calc(var(--control-height-2xl)+var(--spacing)*7)]'
    }.freeze

    FIXED_HEIGHT_CONTROLS = %i[button input select].freeze

    # The rest of § Behavior's table, as classes: a step is a height, an inline padding, a text
    # size and a radius, and every control takes the same ones. What they measure in a browser is
    # test/system/control_sizing_test.rb; this is the step-by-step contract the two share.
    TYPE_CLASSES = {
      xs: %w[text-xs rounded-sm],
      sm: %w[text-sm rounded-sm],
      default: %w[text-sm rounded-md],
      lg: %w[text-sm rounded-md],
      xl: %w[text-sm rounded-md],
      '2xl': %w[text-base rounded-md]
    }.freeze

    PADDING = { xs: 'px-2', sm: 'px-2', default: 'px-2.5', lg: 'px-3', xl: 'px-3.5', '2xl': 'px-3.5' }.freeze

    # Select's box splits the step's padding, because its end side also clears the chevron.
    SELECT_PADDING = {
      xs: %w[ps-2 pe-7],
      sm: %w[ps-2 pe-7],
      default: %w[ps-2.5 pe-7.5],
      lg: %w[ps-3 pe-8],
      xl: %w[ps-3.5 pe-8.5],
      '2xl': %w[ps-3.5 pe-8.5]
    }.freeze

    def render_control(control, **options)
      case control
      when :button then render_inline(Ui::ButtonComponent.new(**options)) { 'Save' }
      when :input then render_inline(Ui::InputComponent.new(**options))
      when :textarea then render_inline(Ui::TextareaComponent.new(**options))
      when :select then render_inline(Ui::SelectComponent.new(name: 'post[state]', options: STATES, **options))
      end
    end

    def classes_of(selector)
      page.find(selector, visible: :all)['class'].split
    end

    def control_selector(control)
      { button: '[data-slot=button]', input: 'input', textarea: 'textarea', select: 'select' }.fetch(control)
    end

    # One control's step, as classes: the padding it was given, plus the step's text size and
    # radius and no other step's.
    def assert_step_classes(control, classes, step, *padding)
      padding.each { |utility| assert_includes classes, utility, "#{control} at #{step}" }

      TYPE_CLASSES.fetch(step).each { |utility| assert_includes classes, utility, "#{control} at #{step}" }
      (TYPE_CLASSES.values.flatten.uniq - TYPE_CLASSES.fetch(step)).each do |other|
        assert_not_includes classes, other, "#{control} at #{step}"
      end
    end

    HEIGHTS.each do |step, height|
      FIXED_HEIGHT_CONTROLS.each do |control|
        test "#{control} at size: :#{step} reads that step's token and no other" do
          render_control(control, size: step)

          classes = classes_of(control_selector(control))
          assert_includes classes, height
          (HEIGHTS.values - [height]).each { |other| assert_not_includes classes, other }
        end
      end

      test "textarea at size: :#{step} takes its minimum from that step's token" do
        render_control(:textarea, size: step)

        classes = classes_of('textarea')
        assert_includes classes, TEXTAREA_MINIMUMS[step]
        (TEXTAREA_MINIMUMS.values - [TEXTAREA_MINIMUMS[step]]).each { |other| assert_not_includes classes, other }
      end

      # The select and the control are one box in two renderings, in either mode. The popup's
      # search row is not a control, so the step never reaches it (ui-control-sizing § Behavior).
      test "select at size: :#{step} puts the step on the control in both modes, and not on the search row" do
        render_control(:select, size: step)
        assert_includes classes_of('#post_state-combobox'), height

        render_control(:select, size: step, search: true)
        assert_includes classes_of('#post_state-trigger'), height
        (HEIGHTS.values - [height]).each { |other| assert_not_includes classes_of('#post_state-trigger'), other }
        assert_not_includes classes_of('#post_state-search'), height
      end

      test "every control at size: :#{step} takes that step's padding, text size and radius" do
        %i[button input textarea].each do |control|
          render_control(control, size: step)
          assert_step_classes(control, classes_of(control_selector(control)), step, PADDING[step])
        end

        render_control(:select, size: step)
        %w[select #post_state-combobox].each do |selector|
          assert_step_classes('select', classes_of(selector), step, *SELECT_PADDING[step])
        end
      end
    end

    # `2xl` is the one step whose name can't be written as a bare symbol, so a call site reaches
    # for the string form more often than at the other five. Both resolve to the same step.
    test 'a step named as a string renders the same box as the symbol' do
      FIXED_HEIGHT_CONTROLS.each do |control|
        render_control(control, size: '2xl')
        assert_includes classes_of(control_selector(control)), HEIGHTS[:'2xl'], "#{control} missed the 2xl step"
      end

      render_control(:textarea, size: '2xl')
      assert_includes classes_of('textarea'), TEXTAREA_MINIMUMS[:'2xl']
    end

    test 'every control without size: renders the default step' do
      FIXED_HEIGHT_CONTROLS.each do |control|
        render_control(control)
        assert_includes classes_of(control_selector(control)), HEIGHTS[:default], "#{control} missed the default step"
      end

      render_control(:textarea)
      assert_includes classes_of('textarea'), TEXTAREA_MINIMUMS[:default]
    end

    # `size` is also an HTML attribute on <input> and <select>. The kit's keyword must be consumed,
    # never forwarded, or `size: :sm` renders size="sm" and sizes nothing.
    test 'size: is consumed as the scale, never forwarded as an HTML attribute' do
      %i[input textarea select].each do |control|
        render_control(control, size: :sm)
        assert_nil page.find(control_selector(control), visible: :all)['size'], "#{control} forwarded size="
      end
    end

    test "a caller's height class is the only height the control renders, at every step" do
      HEIGHTS.each_key do |step|
        FIXED_HEIGHT_CONTROLS.each do |control|
          render_control(control, size: step, class: 'h-12')
          assert_equal ['h-12'], classes_of(control_selector(control)).grep(/\Ah-/), "#{control} at #{step}"
        end
      end

      render_control(:button, size: :icon, class: 'size-12')
      assert_equal ['size-12'], classes_of('[data-slot=button]').grep(/\Asize-/)
    end

    # Textarea's own two new steps are gated to another worker; kept as its own test per step,
    # rather than folded into the check above, so xs and xl failing there doesn't hide a
    # regression on sm, default or lg (ui-control-sizing status.md, § In progress).
    HEIGHTS.each_key do |step|
      test "a caller's height class is the only height the textarea renders, at size: :#{step}" do
        render_control(:textarea, size: step, class: 'min-h-24')
        assert_equal ['min-h-24'], classes_of('textarea').grep(/\Amin-h-/), "textarea at #{step}"
      end
    end

    test 'an unknown size raises in development and test, on every control' do
      %i[button input textarea select].each do |control|
        assert_raises(Ui::Base::UnknownVariantError, "#{control} accepted size: :xxl") { render_control(control, size: :xxl) }
      end
    end

    test "Button's icon size is Button's alone" do
      %i[input textarea select].each do |control|
        assert_raises(Ui::Base::UnknownVariantError, "#{control} accepted size: :icon") do
          render_control(control, size: :icon)
        end
      end
    end
  end
end
