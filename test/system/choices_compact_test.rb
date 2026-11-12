# frozen_string_literal: true

require 'application_system_test_case'

# Choices' compact appearances in the browser, on the Choices page's segmented and chips demos.
# The input is visually hidden and the label is the control, so what these prove is that nothing
# the platform gave list and card was lost: focus lands on a real input and draws on the label,
# arrows move a radio group, Space toggles a checkbox, the size scale lines up with Button, and
# both modes pass axe.
class ChoicesCompactTest < ApplicationSystemTestCase
  setup do
    visit choices_path
    disable_transitions
  end

  def checked_value(name)
    page.evaluate_script("document.querySelector('input[name=\"#{name}\"]:checked')?.value")
  end

  def label_of(input_id)
    "label:has(> ##{input_id})"
  end

  def outline_width(selector)
    page.evaluate_script('parseFloat(getComputedStyle(document.querySelector(arguments[0])).outlineWidth)', selector)
  end

  test 'CC1 segmented: Tab enters at the checked segment and the arrows move and choose' do
    page.execute_script("document.getElementById('view_zoom_fit').focus()")
    assert_equal 'view_zoom_fit', focused_id

    press(:arrow_right)
    assert_equal 'view_zoom_150', focused_id
    assert_equal '150', checked_value('view[zoom]')

    press(:arrow_right)
    press(:arrow_right)
    assert_equal 'fit', checked_value('view[zoom]'), 'the arrows wrap, as a radio group does'
  end

  test 'CC2 segmented: the keyboard-focused segment draws the focus ring on its label' do
    page.execute_script("document.getElementById('view_zoom_fit').focus()")
    press(:arrow_right)

    assert_equal 2.0, outline_width(label_of('view_zoom_150'))
  end

  test 'CC3 segmented: a click on a segment chooses it' do
    find(label_of('view_zoom_200')).click

    assert_equal '200', checked_value('view[zoom]')
  end

  test 'CC4 segmented: the track is one control height at every step, the same as Button beside it' do
    %w[xs sm default lg xl 2xl].each do |step|
      track = page.evaluate_script(
        "document.querySelector('[name=\"view[zoom_size_#{step}]\"]').closest('fieldset').getBoundingClientRect().height"
      )
      button = page.evaluate_script(
        "document.querySelector('[name=\"view[zoom_size_#{step}]\"]').closest('fieldset').nextElementSibling.getBoundingClientRect().height"
      )
      assert_in_delta button, track, 0.01, "segmented at #{step}"
    end
  end

  test 'CC5 chips: a radio chip group moves with the arrows' do
    page.execute_script("document.getElementById('filter_state_salt').focus()")
    press(:arrow_right)

    assert_equal 'accepted', checked_value('filter[state]')
  end

  test 'CC6 chips: Space toggles a checkbox chip, and a locked chip stays locked' do
    page.execute_script("document.getElementById('filter_states_salt').focus()")
    press(:space)
    assert page.evaluate_script("document.getElementById('filter_states_salt').checked")

    press(:space)
    refute page.evaluate_script("document.getElementById('filter_states_salt').checked")

    find(label_of('filter_states_not_filled')).click
    refute page.evaluate_script("document.getElementById('filter_states_not_filled').checked")
  end

  test "CC7 chips: a chip's accessible name is its text and its count" do
    name = page.evaluate_script(<<~JS)
      (() => {
        const input = document.getElementById('filter_state_unmapped')
        return input.getAttribute('aria-labelledby').split(' ')
          .map((id) => document.getElementById(id).textContent.trim()).join(' ')
      })()
    JS

    assert_equal 'Unmapped 250', name
  end

  test 'CC8 the checked chip and segment change their boundary, not only their colour' do
    chip = page.evaluate_script(
      'getComputedStyle(document.querySelector(arguments[0])).boxShadow', label_of('filter_state_salt')
    )
    unchecked_chip = page.evaluate_script(
      'getComputedStyle(document.querySelector(arguments[0])).boxShadow', label_of('filter_state_unmapped')
    )
    refute_equal unchecked_chip, chip, 'a checked chip draws its inset line'

    outline = ->(selector) { page.evaluate_script('getComputedStyle(document.querySelector(arguments[0])).outlineStyle', selector) }
    assert_equal 'solid', outline.call(label_of('view_zoom_fit')), 'a checked segment draws its outline'
    assert_equal 1.0, outline_width(label_of('view_zoom_fit'))
    assert_equal 'none', outline.call(label_of('view_zoom_150'))
  end

  test 'CC9 both previews pass axe, in light and dark' do
    [false, true].each do |dark|
      use_dark_mode(dark)
      assert_accessible within: '#choices-segmented-preview'
      assert_accessible within: '#choices-chips-preview'
    end
    use_dark_mode(false)
  end
end
