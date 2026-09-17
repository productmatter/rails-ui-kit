# frozen_string_literal: true

require 'test_helper'
require 'support/lenient_toasts'

module Ui
  # Every payload rule in docs/specs/ui-toast § Behavior, item 15: it raises in development and
  # test, naming the key and the fix, and outside them it logs and renders by the safe rule.
  class ToastValidationTest < ViewComponent::TestCase
    include LenientToasts

    # [what breaks the rule, the payload, what the message names, what renders safely]
    RULES = {
      'an unknown key' => [{ description: 'x', colour: 'red' }, /colour/, -> { assert_selector '[data-slot=toast-description]', text: 'x' }],
      'a blank action label' => [{ description: 'x', actions: [{ label: ' ' }] }, /label/, -> { assert_no_selector '[data-slot=toast-actions]' }],
      'an unknown action variant' => [{ description: 'x', actions: [{ label: 'Go', variant: 'loud' }] }, /variant/,
                                      -> { assert_no_selector '[data-slot=toast-actions]' }],
      'an unknown action method' => [{ description: 'x', actions: [{ label: 'Go', href: '/g', method: 'trace' }] }, /method/,
                                     -> { assert_no_selector '[data-slot=toast-actions]' }],
      'a method without an href' => [{ description: 'x', actions: [{ label: 'Go', method: 'patch' }] }, /without an href/,
                                     -> { assert_no_selector '[data-slot=toast-actions]' }],
      'dismiss: false without an href' => [{ description: 'x', actions: [{ label: 'Go', dismiss: false }] }, /dismiss: false/,
                                           -> { assert_no_selector '[data-slot=toast-actions]' }],
      'an icon other than false' => [{ description: 'x', icon: '<svg onload=alert(1)>' }, /icon/,
                                     -> { assert_selector '[data-slot=toast-icon] svg path' }],
      'a non-String title' => [{ title: { html: '<b>' }, description: 'x' }, /title/, -> { assert_no_selector '[data-slot=toast-title]' }],
      'a negative duration' => [{ description: 'x', duration: -5 }, /duration/,
                                -> { assert_selector "[data-ui--toast-duration-value='3000']" }]
    }.freeze

    RULES.each do |name, (payload, names, safely)|
      test "#{name} raises in test, and outside it logs and renders safely" do
        error = assert_raises(Ui::Toast::InvalidPayloadError) { render_inline(Ui::ToastComponent.new(message: payload)) }
        assert_match names, error.message

        leniently do |log|
          render_inline(Ui::ToastComponent.new(message: payload))
          instance_exec(&safely)
          assert_match names, log.string
        end
      end
    end

    test "0.2.0's body: and timeout: name their replacements, and outside test are honoured" do
      error = assert_raises(Ui::Toast::InvalidPayloadError) { render_inline(Ui::ToastComponent.new(message: { title: 'x', body: 'y' })) }
      assert_match(/body: is now description:/, error.message)
      error = assert_raises(Ui::Toast::InvalidPayloadError) { render_inline(Ui::ToastComponent.new(message: { title: 'x', timeout: 10 })) }
      assert_match(/timeout: is now duration:/, error.message)

      leniently do
        render_inline(Ui::ToastComponent.new(message: { title: 'Oops', body: 'Try again.', timeout: 1500 }))

        assert_selector '[data-slot=toast-description]', text: 'Try again.'
        assert_selector "[data-ui--toast-duration-value='1500']"
      end
    end

    test 'an icon slot together with icon: false raises, and outside test the slot renders' do
      assert_raises(Ui::Toast::InvalidPayloadError) { render_with_both_icons }

      leniently do |log|
        render_with_both_icons
        assert_selector '[data-slot=toast-icon] svg#mine'
        assert_match(/icon slot and icon: false/, log.string)
      end
    end

    # One behaviour for a closed-set keyword across the kit: loud in development and test, the
    # default and a log line outside them.
    test 'an unknown type raises UnknownVariantError in test, and outside it logs and renders info' do
      error = assert_raises(Ui::Base::UnknownVariantError) { render_inline(Ui::ToastComponent.new(type: :weird, message: 'x')) }
      assert_match(/type: :weird/, error.message)

      leniently do |log|
        render_inline(Ui::ToastComponent.new(type: 'weird', message: 'x'))
        assert_selector "[data-ui--toast-type-value='info']"
        assert_match(/weird/, log.string)
      end
    end

    test 'a Symbol message that is not an I18n key is loud' do
      assert_raises(Ui::Toast::InvalidPayloadError) { render_inline(Ui::ToastComponent.new(message: :'toast_test.no_such_key')) }
    end

    private

    def render_with_both_icons
      render_inline(Ui::ToastComponent.new(message: 'x', icon: false)) do |toast|
        toast.with_icon { '<svg id="mine"></svg>'.html_safe }
      end
    end
  end
end
