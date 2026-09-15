# frozen_string_literal: true

require 'application_system_test_case'
require 'primitives_helpers'

class AnchorArrowTest < ApplicationSystemTestCase
  include PrimitivesHelpers

  setup do
    visit primitives_navigation_path
    assert_selector '[data-ui--anchor-target="floating"][data-side]', minimum: 12, wait: 20
    # The viewport is a clipping ancestor: an anchor below the fold has no room on any side and
    # flip picks for itself, so bring this one into view before asking for a placement.
    page.execute_script("document.querySelector('#anchor-arrow').scrollIntoView({ block: 'center' })")
  end

  test 'AR1: the arrow points at the control and is inset on the side opposite the resolved one' do
    control = find('#anchor-arrow-control')
    floating = find('#anchor-arrow-floating')
    arrow = find('#anchor-arrow-arrow')

    assert_selector '#anchor-arrow-floating[data-side="top"]'

    eventually do
      # Floating above the control, arrow centred on it and hanging half its own width below the
      # floating element's bottom edge -- the static-side inset.
      assert_in_delta rect(control)['left'] + (rect(control)['width'] / 2),
                      rect(arrow)['left'] + (rect(arrow)['width'] / 2), 2
      assert_in_delta rect(floating)['bottom'], rect(arrow)['top'] + (rect(arrow)['height'] / 2), 2
    end

    assert_equal '-4px', style_of(arrow, 'bottom')
    assert_equal 'auto', style_of(arrow, 'top')
  end

  test 'AR2: the arrow follows the resolved side when the placement flips to the other side' do
    arrow = find('#anchor-arrow-arrow')
    anchor = find('#anchor-arrow [data-controller="ui--anchor"]', visible: :all)

    page.execute_script("arguments[0].setAttribute('data-ui--anchor-placement-value', 'bottom')", anchor)
    assert_selector '#anchor-arrow-floating[data-side="bottom"]'

    eventually do
      assert_equal '-4px', style_of(arrow, 'top')
      assert_equal 'auto', style_of(arrow, 'bottom')
    end
  end

  test 'AR3: an anchor with no arrow target positions normally and raises nothing' do
    # Every other anchored element on the page has no arrow target. If the missing middleware data
    # threw, none of them would have been positioned, and repositioning one would not work either.
    assert_selector '#anchor-block-floating[data-side="bottom"]'
    assert_no_selector '#anchor-block [data-ui--anchor-target="arrow"]', visible: :all

    anchor = find('#anchor-block [data-controller="ui--anchor"]', visible: :all)
    page.execute_script("arguments[0].setAttribute('data-ui--anchor-placement-value', 'right')", anchor)

    assert_selector '#anchor-block-floating[data-side="right"]'
  end

  test 'AR4: an arrow added or removed after connect is picked up' do
    arrow = find('#anchor-arrow-arrow')
    page.execute_script('arguments[0].remove()', arrow)
    assert_no_selector '#anchor-arrow-arrow'

    # Still positioned, with no arrow middleware registered.
    anchor = find('#anchor-arrow [data-controller="ui--anchor"]', visible: :all)
    page.execute_script("arguments[0].setAttribute('data-ui--anchor-placement-value', 'bottom')", anchor)
    assert_selector '#anchor-arrow-floating[data-side="bottom"]'

    # And an arrow that arrives later is positioned without anything else changing.
    page.execute_script(<<~JS)
      const arrow = document.createElement('div')
      arrow.id = 'anchor-arrow-arrow'
      arrow.className = 'absolute h-2 w-2 rotate-45 bg-neutral-900'
      arrow.setAttribute('data-ui--anchor-target', 'arrow')
      document.querySelector('#anchor-arrow-floating').appendChild(arrow)
    JS

    control = find('#anchor-arrow-control')
    eventually do
      added = find('#anchor-arrow-arrow')
      assert_equal '-4px', style_of(added, 'top')
      assert_in_delta rect(control)['left'] + (rect(control)['width'] / 2),
                      rect(added)['left'] + (rect(added)['width'] / 2), 2
    end
  end

  private

  def style_of(element, property)
    page.evaluate_script("arguments[0].style.getPropertyValue(arguments[1]) || 'auto'", element, property)
  end
end
