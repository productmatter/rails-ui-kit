# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'support/lenient_toasts'

module Ui
  # The URL rule in Ruby (docs/specs/ui-toast, § Behavior, item 9), run against the vectors
  # test/system/toast_href_test.rb runs through window.triggerToast, so both languages decide alike.
  class ToastHrefTest < ViewComponent::TestCase
    include LenientToasts

    VECTORS = JSON.parse(File.read(File.expand_path('../../fixtures/toast_href_vectors.json', __dir__))).freeze

    test 'every shared vector is accepted or rejected as listed' do
      VECTORS.each do |vector|
        assert_equal vector['allowed'], Ui::Toast::Href.allowed?(vector['href']),
                     "#{vector['href'].inspect} should be #{vector['allowed'] ? 'allowed' : 'rejected'}: #{vector['why']}"
      end
    end

    test 'a rejected href raises in test, naming the href' do
      VECTORS.reject { |vector| vector['allowed'] }.each do |vector|
        error = assert_raises(Ui::Toast::InvalidPayloadError, vector['why']) do
          render_inline(Ui::ToastComponent.new(title: 'x', actions: [{ label: 'Open', href: vector['href'] }]))
        end
        assert_match(/not a relative or http\(s\) URL/, error.message)
      end
    end

    test 'outside development and test a rejected href drops that action, logs, and keeps the rest' do
      leniently do |log|
        render_inline(Ui::ToastComponent.new(title: 'x', actions: [{ label: 'Evil', href: 'JaVaScRiPt:alert(1)' },
                                                                   { label: 'Fine', href: '/fine' }]))

        assert_no_selector '[data-slot=toast-actions] a', text: 'Evil'
        assert_selector "[data-slot=toast-actions] a[href='/fine']", text: 'Fine'
        assert_not_includes rendered_content.downcase, 'javascript:'
        assert_match(/Evil/, log.string)
      end
    end
  end
end
