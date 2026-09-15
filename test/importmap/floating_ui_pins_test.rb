# frozen_string_literal: true

require 'test_helper'

# The engine ships config/importmap.rb and invites host apps to override any pin in it. Floating
# UI reaches importmap consumers as one pin, and it is vendored rather than fetched from a CDN:
# jsDelivr's +esm build for @floating-ui/dom looked like one CDN dependency but wasn't -- its own
# module graph re-imported @floating-ui/core and @floating-ui/utils from jsDelivr by URL, so
# jsDelivr being unreachable took Turbo, Stimulus and every anchored component down with it, not
# just positioning. vendor/floating-ui.dom.js bundles all three into one file with no remaining
# imports. These tests hold that in place.
class FloatingUiPinsTest < ActiveSupport::TestCase
  IMPORTMAP = File.expand_path('../../config/importmap.rb', __dir__)
  VENDOR_DIR = File.expand_path('../../app/javascript/rails_ui_kit/vendor', __dir__)
  VENDORED_FILE = File.join(VENDOR_DIR, 'floating-ui.dom.js')
  VENDORED_LICENSE = File.join(VENDOR_DIR, 'floating-ui.LICENSE')

  def pins
    @pins ||= File.read(IMPORTMAP).scan(/^\s*pin\s+'([^']+)',\s*to:\s*'([^']+)'/).to_h
  end

  def floating_ui_pins
    pins.select { |name, _| name.start_with?('@floating-ui/') }
  end

  test 'Floating UI is pinned exactly once' do
    assert_equal ['@floating-ui/dom'], floating_ui_pins.keys,
                 'Floating UI must reach importmap consumers as a single pin whose version set moves as a unit'
  end

  test 'the single pin points at the vendored bundle' do
    assert_equal 'rails_ui_kit/vendor/floating-ui.dom.js', floating_ui_pins.fetch('@floating-ui/dom')
  end

  test 'no pin in config/importmap.rb resolves to a remote URL' do
    pins.each_value do |target|
      refute_match %r{\Ahttps?://}, target, "#{target} is a remote URL, not a local pin"
    end
  end

  test 'the vendored bundle is self-contained: no import statement, no jsDelivr reference' do
    body = File.read(VENDORED_FILE)

    refute_match(/\bimport\b/, body, 'the vendored file still imports something -- it is not self-contained')
    refute_match(/cdn\.jsdelivr\.net/, body, 'the vendored file still names jsDelivr')
  end

  test 'the LICENSE sits beside the vendored file' do
    assert File.exist?(VENDORED_LICENSE), "#{VENDORED_LICENSE} is missing"
  end
end
