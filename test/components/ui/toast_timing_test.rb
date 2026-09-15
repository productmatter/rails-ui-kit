# frozen_string_literal: true

require 'test_helper'
require 'support/lenient_toasts'

module Ui
  # Timing defaults in Ruby (docs/specs/ui-toast, § Behavior, item 10). A default never takes an
  # action away: a toast with one has no countdown unless its payload asks for one.
  class ToastTimingTest < ViewComponent::TestCase
    include LenientToasts

    ACTION = { label: 'Undo', href: '/undo', method: 'patch' }.freeze

    test 'no action: 3000 ms, or 20000 ms for an error, with a countdown bar' do
      render_inline(Ui::ToastComponent.new(type: :info, message: 'Hi'))
      assert_duration 3000
      assert_selector '[data-slot=toast-progress] [data-ui--toast-target=timer]'

      render_inline(Ui::ToastComponent.new(type: :error, message: 'Boom'))
      assert_duration 20_000
    end

    test 'an action and no duration: nothing counts down, and there is no bar' do
      render_inline(Ui::ToastComponent.new(type: :success, title: 'Archived', actions: [ACTION]))

      assert_duration 0
      assert_no_selector '[data-slot=toast-progress]'
    end

    test 'an explicit duration wins with actions, and 0 persists without them' do
      render_inline(Ui::ToastComponent.new(type: :success, title: 'Archived', actions: [ACTION], duration: 8000))
      assert_duration 8000
      assert_selector '[data-slot=toast-progress]'

      render_inline(Ui::ToastComponent.new(type: :info, message: 'Stays', duration: 0))
      assert_duration 0
      assert_no_selector '[data-slot=toast-progress]'
    end

    test 'a duration from flash arrives as a String of digits, and is used' do
      render_inline(Ui::ToastComponent.new(message: { 'description' => 'x', 'duration' => '1500' }))

      assert_duration 1500
    end

    # 0.2.0 wrote timeout: straight into an inline style. Nothing a payload carries is written into
    # a style now, and a value that isn't a whole number never gets that far.
    test 'a duration carrying CSS is loud in test, and outside it the default is used and nothing injected' do
      attack = '1; background-image: url(https://example.com/x)'
      error = assert_raises(Ui::Toast::InvalidPayloadError) { render_inline(Ui::ToastComponent.new(message: 'x', duration: attack)) }
      assert_match(/duration/, error.message)

      leniently do |log|
        render_inline(Ui::ToastComponent.new(type: :info, message: { description: 'x', timeout: attack }))

        assert_duration 3000
        assert_not_includes rendered_content, 'background-image'
        assert_no_selector '[style]'
        assert_match(/duration/, log.string)
      end
    end

    test 'a negative or fractional duration is invalid the same way' do
      [-1, 1.5, '2.5', 'soon'].each do |value|
        assert_raises(Ui::Toast::InvalidPayloadError, value.inspect) do
          render_inline(Ui::ToastComponent.new(message: 'x', duration: value))
        end
      end
    end

    private

    def assert_duration(milliseconds)
      assert_selector "[data-slot=toast][data-ui--toast-duration-value='#{milliseconds}']"
    end
  end
end
