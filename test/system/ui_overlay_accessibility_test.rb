# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

class UiOverlayAccessibilityTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  setup { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test 'the primitives demo page passes an axe audit as rendered' do
    visit primitives_overlay_path

    assert_accessible(within: 'main')
  end

  test 'an open modal passes an axe audit' do
    visit primitives_overlay_path
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'

    assert_accessible(within: 'main')
  end

  test 'a layer open inside a modal passes an axe audit' do
    visit primitives_overlay_path
    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    find('#inner-layer-trigger').click
    assert_state '#inner-layer-content', 'open'

    assert_accessible(within: 'main')
  end

  test 'an open layer and an open hint pass an axe audit' do
    visit primitives_overlay_path
    find('#menu-trigger').click
    assert_state '#menu-content', 'open'
    page.execute_script("document.querySelector('#hint-overlay').setAttribute('data-ui--overlay-open-value', 'true')")
    assert_state '#hint-content', 'open'

    assert_accessible(within: 'main')
  end
end
