# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

class UiScrollLockTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  setup { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test 'the demo page has a space-taking scrollbar, or none of this proves anything' do
    visit primitives_overlay_path

    assert_operator scrollbar_width, :>, 0
  end

  test 'a second lock-requesting overlay opening and closing leaves the page locked while the first is open' do
    visit primitives_overlay_path
    assert_not scroll_locked?

    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    assert scroll_locked?

    find('#nested-modal-trigger').click
    assert_state '#nested-modal-content', 'open'
    assert scroll_locked?

    find('#nested-modal-close').click
    assert_state '#nested-modal-content', 'closed'
    assert scroll_locked?, 'the second overlay closing unlocked the page underneath the first'

    find('#modal-close').click
    assert_state '#modal-content', 'closed'
    assert_not scroll_locked?
    assert_equal '', body_style('overflow')
    assert_equal '', body_style('position')
  end

  test 'the page cannot be scrolled while locked, and the exact scroll position comes back' do
    visit primitives_overlay_path
    page.execute_script('window.scrollTo(0, 480)')
    assert_equal 480, scroll_position.last

    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    page.execute_script('window.scrollTo(0, 900)')
    assert_equal 0, scroll_position.last, 'the page scrolled behind the modal'

    find('#modal-close').click
    assert_state '#modal-content', 'closed'
    assert_equal 480, scroll_position.last
  end

  test 'locking and unlocking shift nothing horizontally' do
    visit primitives_overlay_path
    before = rect_of('#fade-panel')

    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    locked = rect_of('#fade-panel')
    assert_in_delta before['left'], locked['left'], 0.5, 'the page shifted sideways when the scrollbar went'
    assert_in_delta before['right'], locked['right'], 0.5

    find('#modal-close').click
    assert_state '#modal-content', 'closed'
    after = rect_of('#fade-panel')
    assert_in_delta before['left'], after['left'], 0.5
    assert_in_delta before['right'], after['right'], 0.5
  end

  test 'the gutter is reserved by CSS while locked, and given back afterwards' do
    visit primitives_overlay_path
    assert_equal '', page.evaluate_script('document.documentElement.style.scrollbarGutter')

    find('#modal-trigger').click
    assert_state '#modal-content', 'open'
    assert_equal 'stable', page.evaluate_script('document.documentElement.style.scrollbarGutter')
    assert_equal '', body_style('paddingRight'), 'measured padding was applied where CSS would do'

    find('#modal-close').click
    assert_state '#modal-content', 'closed'
    assert_equal '', page.evaluate_script('document.documentElement.style.scrollbarGutter')
  end

  test 'an overlay that does not ask for the lock does not take it' do
    visit primitives_overlay_path
    find('#menu-trigger').click
    assert_state '#menu-content', 'open'

    assert_not scroll_locked?
  end

  private

  def scrollbar_width
    page.evaluate_script('window.innerWidth - document.documentElement.clientWidth')
  end
end
