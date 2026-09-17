# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'toast_helpers'

# Invalid input through window.triggerToast (docs/specs/ui-toast, § Behavior, item 15): strict, the
# call throws before anything renders; not strict, it warns and renders by the safe rule. The
# strict flag is rendered from Ruby, so "not strict" is emulated by writing that attribute.
class ToastValidationSystemTest < ApplicationSystemTestCase
  include ToastHelpers

  # [the payload, what the message names, what renders safely when not strict]
  RULES = {
    'an unknown key' => [{ description: 'Unknown key', colour: 'red' }, /colour/, ->(toast) { assert toast.has_selector?('[data-slot=toast-description]') }],
    'a blank label' => [{ description: 'Blank label', actions: [{ label: '' }] }, /label/, ->(toast) { assert toast.has_no_selector?('[data-slot=toast-actions]') }],
    'an unknown variant' => [{ description: 'Bad variant', actions: [{ label: 'Go', variant: 'loud' }] }, /variant/, ->(toast) { assert toast.has_no_selector?('[data-slot=toast-actions]') }],
    'an unknown method' => [{ description: 'Bad method', actions: [{ label: 'Go', href: '/g', method: 'trace' }] }, /method/,
                            ->(toast) { assert toast.has_no_selector?('[data-slot=toast-actions]') }],
    'dismiss: false without an href' => [{ description: 'No href', actions: [{ label: 'Go', dismiss: false }] }, /dismiss/, ->(toast) { assert toast.has_no_selector?('[data-slot=toast-actions]') }],
    'a method without an href' => [{ description: 'Method only', actions: [{ label: 'Go', method: 'patch' }] }, /without an href/,
                                   ->(toast) { assert toast.has_no_selector?('[data-slot=toast-actions]') }],
    'a class on a JavaScript action' => [{ description: 'Has class', actions: [{ label: 'Go', class: 'h-12' }] }, /class/, ->(toast) { assert toast.has_no_selector?('[data-slot=toast-actions]') }],
    'a non-integer duration' => [{ description: 'Bad duration', duration: '1; background-image:url(x)' }, /duration/,
                                 ->(toast) { assert_equal '3000', toast['data-ui--toast-duration-value'] }],
    'a negative duration' => [{ description: 'Negative', duration: -1 }, /duration/, ->(toast) { assert_equal '3000', toast['data-ui--toast-duration-value'] }],
    'an icon other than false' => [{ description: 'Bad icon', icon: '<svg onload=alert(1)>' }, /icon/, ->(toast) { assert toast.has_selector?('[data-slot=toast-icon] path', visible: :all) }],
    'an unknown type' => [{ type: 'weird', description: 'Weird type' }, /type/, ->(toast) { assert_equal 'info', toast['data-ui--toast-type-value'] }],
    "0.2.0's body" => [{ title: 'Old', body: 'Renamed body' }, /body is now description/, ->(toast) { assert toast.has_selector?('[data-slot=toast-description]', text: 'Renamed body') }],
    "0.2.0's timeout" => [{ description: 'Old timeout', timeout: 1500 }, /timeout is now duration/, ->(toast) { assert_equal '1500', toast['data-ui--toast-duration-value'] }]
  }.freeze

  test 'TV1: strict, every rule throws before anything renders, naming what to fix' do
    visit toast_path
    wait_for_toast_api

    RULES.each do |name, (payload, names, _)|
      thrown = page.evaluate_script(<<~JS, deep_stringify(payload))
        (() => { try { window.triggerToast(arguments[0]); return null } catch (error) { return String(error) } })()
      JS
      assert_match names, thrown.to_s, "#{name} did not throw"
    end
    assert_no_selector TOAST
  end

  test 'TV2: not strict, every rule warns and renders by the safe rule' do
    visit toast_path
    wait_for_toast_api
    page.execute_script("document.querySelector('[data-controller~=\"ui--toast-container\"]').setAttribute('data-ui--toast-container-strict-value', 'false')")
    install_console_warning_capture

    RULES.each do |name, (payload, names, safely)|
      trigger_toast(payload)
      toast = settled_toast
      instance_exec(toast, &safely)
      assert_match names, console_warnings.last.to_s, "#{name} did not warn"
    end
    assert_no_selector "#{TOAST} svg[onload]", visible: :all
  end
end
