# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'toast_helpers'

# A toast belongs to the moment it was sent. A page restored from Turbo's cache shows none, whether
# the toast came from JavaScript or from a flash (docs/specs/ui-toast, § Acceptance checks).
class ToastTurboCacheTest < ApplicationSystemTestCase
  include ToastHelpers

  test 'TT1: a toast visible when the page was left is not there when it is restored from the cache' do
    visit toast_path
    trigger_toast(ToastsController.scenario('archived'))
    settled_toast

    leave_and_come_back
  end

  test 'TT2: the same for a flash toast rendered by the server' do
    visit demo_toast_flash_path(notice: 'Post was successfully created.')
    assert_selector TOAST, text: 'Post was successfully created.'

    leave_and_come_back
  end

  private

  # The marker is written only in this browser, so finding it after Back proves the page came from
  # Turbo's snapshot -- where a toast would survive -- and not from a fresh fetch, where it never could.
  def leave_and_come_back
    page.execute_script("document.querySelector('main').insertAdjacentHTML('afterbegin', '<p id=\"cache-marker\"></p>')")
    click_on 'Installation'
    assert_selector 'h1', text: 'Installation'
    page.go_back

    assert_selector 'h1', text: 'Toast'
    assert_selector '#cache-marker', visible: :all
    assert_no_selector TOAST, visible: :all
    assert page.evaluate_script("document.getElementById('ui-toasts').hidden"), 'the empty stack is still a landmark'
  end
end
