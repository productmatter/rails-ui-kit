# frozen_string_literal: true

require 'application_system_test_case'
require 'json'
require_relative 'toast_helpers'

# The URL rule through window.triggerToast, against the same vectors test/components/ui/toast_href_test.rb
# runs in Ruby (docs/specs/ui-toast, § Behavior, item 9). Strict, a rejected href throws before
# anything renders; not strict, the toast renders without that action and warns. No javascript:
# URL ever reaches the DOM either way.
class ToastHrefSystemTest < ApplicationSystemTestCase
  include ToastHelpers

  VECTORS = JSON.parse(File.read(File.expand_path('../fixtures/toast_href_vectors.json', __dir__))).freeze

  test 'TH1: every shared vector is accepted or rejected by the browser as it is by Ruby' do
    visit toast_path
    wait_for_toast_api

    VECTORS.each do |vector|
      outcome = page.evaluate_script(<<~JS, vector['href'])
        (() => {
          try {
            window.triggerToast({ title: 'Vector', actions: [{ label: 'Open', href: arguments[0] }] })
            return 'rendered'
          } catch (error) {
            return 'thrown'
          }
        })()
      JS
      assert_equal vector['allowed'] ? 'rendered' : 'thrown', outcome, "#{vector['href'].inspect}: #{vector['why']}"
      assert_equal Ui::Toast::Href.allowed?(vector['href']), vector['allowed'], 'Ruby and the vector list disagree'
    end

    assert_no_javascript_urls
  end

  test 'TH2: strict, a rejected href renders nothing; not strict, the toast renders without that action and warns' do
    visit toast_path
    wait_for_toast_api
    before = all(TOAST).size

    thrown = page.evaluate_script(<<~JS)
      (() => { try { window.triggerToast({ title: 'Strict', actions: [{ label: 'Evil', href: 'java\\tscript:alert(1)' }] }) } catch (e) { return String(e) } })()
    JS
    assert_match(/not a relative or http\(s\) URL/, thrown)
    assert_equal before, all(TOAST).size, 'a strict rejection still rendered a toast'

    relax_strictness
    install_console_warning_capture
    trigger_toast(title: 'Lenient', actions: [{ label: 'Evil', href: ' JaVaScRiPt:alert(1)' }, { label: 'Fine', href: '/fine' }])

    toast = find(TOAST, text: 'Lenient')
    assert toast.has_no_selector?('[data-slot=toast-actions] a', text: 'Evil')
    assert toast.has_selector?("[data-slot=toast-actions] a[href='/fine']", text: 'Fine')
    assert_match(/Evil/, console_warnings.join("\n"))
    assert_no_javascript_urls
  end

  private

  def relax_strictness
    page.execute_script("document.querySelector('[data-controller~=\"ui--toast-container\"]').setAttribute('data-ui--toast-container-strict-value', 'false')")
  end

  def assert_no_javascript_urls
    urls = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('#ui-toasts [href], #ui-toasts [action]'))
        .map((element) => element.getAttribute('href') || element.getAttribute('action'))
    JS
    assert_empty(urls.select { |url| url.to_s.gsub(/[\x00-\x20]/, '').downcase.start_with?('javascript:') })
  end
end
