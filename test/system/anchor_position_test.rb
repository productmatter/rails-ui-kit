# frozen_string_literal: true

require 'application_system_test_case'
require 'primitives_helpers'

class AnchorPositionTest < ApplicationSystemTestCase
  include PrimitivesHelpers

  setup do
    visit primitives_navigation_path
    # Floating UI is fetched from a CDN pin, so the first computation of the page can land well
    # after load. Everything below assumes the page has positioned at least once.
    assert_selector '[data-ui--anchor-target="floating"][data-side]', minimum: 12, wait: 20
  end

  test 'AP1: a block-layout anchor positions against the caller\'s control, not the full-width wrapper' do
    control = find('#anchor-block-control')
    wrapper = find('#anchor-block-wrapper')
    floating = find('#anchor-block-floating')

    assert_selector '#anchor-block-floating[data-side="bottom"][data-align="end"]'

    eventually do
      assert_in_delta rect(control)['right'], rect(floating)['right'], 2
      assert_in_delta rect(control)['bottom'] + 6, rect(floating)['top'], 2
    end

    # The bug this guards: measuring the block wrapper instead, which is hundreds of px wider.
    assert_operator rect(wrapper)['right'] - rect(control)['right'], :>, 100
  end

  test 'AP2: matchWidth sizes the floating element from the control' do
    control = find('#anchor-match-control')
    floating = find('#anchor-match-floating')

    eventually do
      assert_equal offset_width(control), offset_width(floating)
      assert_in_delta rect(control)['left'], rect(floating)['left'], 2
    end
    assert_selector '#anchor-match-floating[data-align="start"]'
  end

  test 'AP3: an anchor in a flex row is positioned beside its control' do
    control = find('#anchor-flex-control')
    floating = find('#anchor-flex-floating')

    assert_selector '#anchor-flex-floating[data-side="right"][data-align="start"]'

    eventually do
      assert_in_delta rect(control)['right'] + 8, rect(floating)['left'], 2
      assert_in_delta rect(control)['top'], rect(floating)['top'], 2
    end
  end

  test 'AP4: every placement, including the -end variants, publishes its resolved side and align' do
    cells = all('#anchor-placements [data-placement-cell]')
    assert_equal 12, cells.size

    cells.each do |cell|
      placement = cell['data-placement-cell']
      side, align = placement.split('-')
      floating = cell.find('[data-ui--anchor-target="floating"]')

      assert_equal side, floating['data-side'], "#{placement} resolved to the wrong side"
      assert_equal align || 'center', floating['data-align'], "#{placement} resolved to the wrong alignment"
    end
  end

  test 'AP5: a -start and a -end placement land on opposite edges of the same anchor' do
    starts = find('#anchor-placements [data-placement-cell="bottom-start"] [data-ui--anchor-target="floating"]')
    ends = find('#anchor-placements [data-placement-cell="bottom-end"] [data-ui--anchor-target="floating"]')
    anchor_start = find('#anchor-placements [data-placement-cell="bottom-start"] [data-ui--anchor-target="anchor"]')
    anchor_end = find('#anchor-placements [data-placement-cell="bottom-end"] [data-ui--anchor-target="anchor"]')

    eventually do
      assert_in_delta rect(anchor_start)['left'], rect(starts)['left'], 2
      assert_in_delta rect(anchor_end)['right'], rect(ends)['right'], 2
    end
  end

  test 'AP6: the side is the side it landed on -- a collision flips it, and data-side follows' do
    scroller = find('#anchor-flip-scroller')
    control = find('#anchor-flip-control')
    floating = find('#anchor-flip-floating')

    # The viewport is a clipping ancestor too: bring the box into view, or nothing about the
    # container's own edges is what decides the side.
    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", scroller)

    # Room below the control inside its scroll container: the requested side survives.
    scroll_to(scroller, 384 - 20)
    assert_selector '#anchor-flip-floating[data-side="bottom"]'
    eventually { assert_in_delta rect(control)['bottom'] + 6, rect(floating)['top'], 2 }

    # Scrolled down until the control is at the bottom edge, the only side that fits is above it.
    scroll_to(scroller, 384 - 160)
    assert_selector '#anchor-flip-floating[data-side="top"]'
    eventually { assert_in_delta rect(control)['top'] - 6, rect(floating)['bottom'], 2 }

    # And back: nothing latches.
    scroll_to(scroller, 384 - 20)
    assert_selector '#anchor-flip-floating[data-side="bottom"]'
  end

  # A fixed floating element does not move with the page, so it only stays on its control if the
  # controller recomputes on scroll. autoUpdate is what does that here.
  test 'AP7: scrolling the page repositions a fixed-strategy floating element' do
    control = find('#anchor-block-control')
    floating = find('#anchor-block-floating')
    anchor = find('#anchor-block [data-controller="ui--anchor"]', visible: :all)

    page.execute_script("arguments[0].setAttribute('data-ui--anchor-strategy-value', 'fixed')", anchor)
    eventually { assert_equal 'fixed', page.evaluate_script('getComputedStyle(arguments[0]).position', floating) }

    page.execute_script('window.scrollBy(0, 300)')

    eventually do
      assert_in_delta rect(control)['right'], rect(floating)['right'], 2
      assert_in_delta rect(control)['bottom'] + 6, rect(floating)['top'], 2
    end
  ensure
    page.execute_script('window.scrollTo(0, 0)')
  end

  test 'AP8: resizing the window repositions' do
    control = find('#anchor-block-control')
    floating = find('#anchor-block-floating')

    page.driver.browser.manage.window.resize_to(900, 900)

    eventually do
      assert_in_delta rect(control)['right'], rect(floating)['right'], 2
      assert_in_delta rect(control)['bottom'] + 6, rect(floating)['top'], 2
    end
  end

  test 'AP9: changing a value repositions at once' do
    floating = find('#anchor-block-floating')
    control = find('#anchor-block-control')
    anchor = find('#anchor-block [data-controller="ui--anchor"]', visible: :all)

    page.execute_script("arguments[0].setAttribute('data-ui--anchor-placement-value', 'top-start')", anchor)

    assert_selector '#anchor-block-floating[data-side="top"][data-align="start"]'
    eventually do
      assert_in_delta rect(control)['left'], rect(floating)['left'], 2
      assert_in_delta rect(control)['top'] - 6, rect(floating)['bottom'], 2
    end
  end

  private

  def scroll_to(element, top)
    page.execute_script('arguments[0].scrollTop = arguments[1]', element, top)
  end
end
