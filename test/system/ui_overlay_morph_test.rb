# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

# A Turbo morph sets every attribute to the server's markup. ui--overlay writes attributes into
# the markup it was given -- popover on its content, aria-expanded and aria-controls on its
# trigger -- and a morph towards the server's own markup must not take them away. Found by the
# stress page, where a 422 on a page that refreshes with morph left every layer unopenable
# (docs/specs/ui-stress-page/status.md).
class UiOverlayMorphTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  test "a closed layer morphed towards the server's markup keeps what ui--overlay gave it, and still opens" do
    capture_console
    visit primitives_overlay_path
    assert_equal 'auto', find('#menu-content', visible: :all)['popover']
    record_arrival

    morph_towards_server('#menu-content')

    assert_equal 'auto', find('#menu-content', visible: :all)['popover']
    assert_equal 'false', find('#menu-trigger')['aria-expanded']
    assert_equal 'menu-content', find('#menu-trigger')['aria-controls']

    find('#menu-trigger').click
    assert_state '#menu-content', 'open'
    assert_equal 'true', find('#menu-trigger')['aria-expanded']
    press :escape
    assert_state '#menu-content', 'closed'

    # ui-presence-and-overlay-stack § Behavior, item 12: Escape returns focus to the trigger.
    assert_kit_invariants(focus: '#menu-trigger')
  end

  private

  # The overlay root around `selector`, morphed towards the same root in a fresh server render of
  # this page. Waits on the morph having run, not on a duration.
  def morph_towards_server(selector)
    page.execute_script(<<~JS, selector)
      window.__morphed = false
      const root = document.querySelector(arguments[0]).closest('[data-controller~="ui--overlay"]')
      fetch(location.href).then((response) => response.text()).then((html) => {
        const server = new DOMParser().parseFromString(html, 'text/html').querySelector(arguments[0])
        Turbo.morphElements(root, server.closest('[data-controller~="ui--overlay"]'))
        window.__morphed = true
      })
    JS
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.02 until page.evaluate_script('window.__morphed') }
  end
end
