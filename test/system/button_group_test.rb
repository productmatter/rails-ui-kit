# frozen_string_literal: true

require 'application_system_test_case'

class ButtonGroupTest < ApplicationSystemTestCase
  setup do
    visit button_group_path
    disable_transitions
  end

  test 'the focus indicator survives forced-colors mode on a button inside the group' do
    assert_focus_outline_in_forced_colors(preview.find("[data-slot=button][aria-label='Align left']"), 'Align left button')
  end

  test 'adjoining buttons overlap by a hairline instead of doubling their shared border' do
    align_group = preview.find("[data-slot=button-group][aria-label='Text alignment']")
    buttons = align_group.all('[data-slot=button]')

    first_rect = rect(buttons[0])
    second_rect = rect(buttons[1])

    assert_operator second_rect['left'], :<=, first_rect['right'], 'the second button leaves a visible gap instead of overlapping the border'
  end

  test 'only the first and last buttons round their outer corners' do
    align_group = preview.find("[data-slot=button-group][aria-label='Text alignment']")
    buttons = align_group.all('[data-slot=button]')

    radii = buttons.map { |button| page.evaluate_script('getComputedStyle(arguments[0]).borderTopLeftRadius', button) }
    assert_not_equal '0px', radii.first, 'the first button has square corners'
    assert_equal '0px', page.evaluate_script('getComputedStyle(arguments[0]).borderTopLeftRadius', buttons[1]), 'a middle button is not squared'
  end

  test 'a vertical group stretches its buttons to a common width' do
    vertical_group = preview.find("[data-slot=button-group][aria-label='Edit actions']")
    widths = vertical_group.all('[data-slot=button]').map { |button| rect(button)['width'] }

    assert widths.uniq.size == 1, "expected every button to share the group's width, got #{widths}"
  end

  test 'the pagination-style group renders its text chip under button-group-text' do
    pagination_group = preview.find("[data-slot=button-group][aria-label='Pagination']")
    assert_equal 'of 10', pagination_group.find('[data-slot=button-group-text]').text
  end

  test 'the button_group preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#button_group-preview')

    use_dark_mode(true)
    assert_accessible(within: '#button_group-preview')
  end

  private

  def preview
    find_by_id('button_group-preview')
  end

  def rect(element)
    page.evaluate_script(<<~JS, element)
      (() => { const r = arguments[0].getBoundingClientRect(); return { top: r.top, right: r.right, bottom: r.bottom, left: r.left, width: r.width, height: r.height } })()
    JS
  end
end
