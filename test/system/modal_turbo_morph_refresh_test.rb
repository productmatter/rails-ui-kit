# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# The gotcha the guide names, checked in the browser rather than asserted in prose: a Turbo 8
# morphing page refresh rewrites the body, and an open modal only survives it because its
# container is data-turbo-permanent.
class ModalTurboMorphRefreshTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  test 'the demo page really does refresh by morphing' do
    assert_selector 'head meta[name="turbo-refresh-method"][content="morph"]', visible: :all

    count_morphs
    refresh_page
    assert_morphed
  end

  test 'an open modal in a data-turbo-permanent container survives a morphing refresh' do
    open_modal(1)
    mark_dialog
    count_morphs
    count_mounts

    refresh_page
    assert_morphed

    assert_same_dialog
    assert_state '#modal dialog', 'open'
    assert page.evaluate_script("document.querySelector('#modal dialog').matches(':modal')"),
           'the modal survived the morph but left the top layer'
    assert_equal 0, mounts, 'the modal was torn down and re-opened rather than left alone'
    assert scroll_locked?
  end

  test 'without data-turbo-permanent the same refresh morphs the modal away' do
    open_modal(1)
    page.execute_script("document.getElementById('modal').removeAttribute('data-turbo-permanent')")
    count_morphs

    refresh_page
    assert_morphed

    no_modal
    assert_scroll_unlocked
  end

  private

  def count_morphs
    page.execute_script("window.__morphs = 0; document.addEventListener('turbo:morph', () => { window.__morphs++ })")
  end

  def refresh_page
    page.execute_script('Turbo.session.refresh(window.location.href)')
  end

  def assert_morphed
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.02 until page.evaluate_script('window.__morphs').to_i.positive?
    end
  rescue Timeout::Error
    flunk 'the page never refreshed by morphing'
  end
end
