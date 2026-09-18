# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# Input, Textarea and Select's control box are one shape as far as WCAG contrast and focus are
# concerned (docs/specs/ui-presentational-components § Business rules, rule 5): the same checks,
# run against the same token surfaces, for whichever element a person actually types or chooses
# into. Input and Textarea used to be two copies of this file with the component name swapped;
# Select's control box repeated the text-contrast and focus-ring pieces again in
# select_accessibility_test.rb (SA6, SA7). This is the one copy.
class ControlContrastTest < ApplicationSystemTestCase
  include SelectHelpers

  CONTROLS = {
    'Input' => { page: :input, focused: 'focused-input', default: 'default-input', placeholder: 'placeholder-input' },
    'Textarea' => { page: :textarea, focused: 'focused-textarea', default: 'default-textarea', placeholder: 'placeholder-textarea' }
  }.freeze

  CONTROLS.each do |name, spec|
    test "#{name}: the focus indicator survives forced-colors mode" do
      preview = visit_preview(spec)
      assert_focus_outline_in_forced_colors(field(preview, spec[:focused]), name)
    end

    test "#{name}: entered text and placeholder text reach 4.5:1 on every token surface in light and dark mode" do
      preview = visit_preview(spec)
      each_token_surface(preview) do |mode, surface|
        assert_text_contrast(field(preview, spec[:default]), 'entered text', mode, surface)
        assert_text_contrast(field(preview, spec[:placeholder]), 'placeholder text', mode, surface)
      end
    end

    test "#{name}: the focus ring reaches 3:1 against the surface on every token surface in light and dark mode" do
      preview = visit_preview(spec)
      each_token_surface(preview) do |mode, surface|
        assert_focus_ring_contrast(field(preview, spec[:focused]), preview, mode, surface)
      end
    end

    test "#{name}: the control boundary reaches 3:1 against its fill and the surface in light and dark mode" do
      preview = visit_preview(spec)
      each_token_surface(preview) do |mode, surface|
        control = field(preview, spec[:default])
        border = color_of(:border, control)
        { 'fill' => color_of(:background, control), 'surface' => color_of(:background, preview) }.each do |against, color|
          ratio = contrast_ratio(border, color)
          assert_operator ratio, :>=, 3, "boundary is #{ratio.round(2)}:1 against its #{against} on #{surface} in #{mode} mode"
        end
      end
    end

    test "#{name}: the #{spec[:page]} preview passes an accessibility audit in light and dark mode" do
      visit_preview(spec)
      assert_accessible(within: "##{spec[:page]}-preview")

      use_dark_mode(true)
      assert_accessible(within: "##{spec[:page]}-preview")
    end
  end

  # Select's control box is the enhanced combobox, not a find_field target, so it is asserted
  # directly rather than through the CONTROLS table above -- but the same two WCAG checks apply,
  # and used to be duplicated in select_accessibility_test.rb (SA6's control assertion, SA7 whole).
  test "Select's control box: the control text reaches 4.5:1 on every token surface in light and dark mode" do
    visit select_path
    disable_transitions
    preview = find_by_id('select-preview')

    each_token_surface(preview) do |mode, surface|
      assert_text_contrast(find('#demo_timezone-combobox'), "the control's text", mode, surface)
    end
  end

  test "Select's control box: the focus ring reaches 3:1 against every surface" do
    visit select_path
    disable_transitions
    preview = find_by_id('select-preview')

    each_token_surface(preview) do |mode, surface|
      assert_focus_ring_contrast(find('#demo_timezone-combobox'), preview, mode, surface)
    end
  end

  private

  def visit_preview(spec)
    visit send("#{spec[:page]}_path")
    disable_transitions
    find_by_id("#{spec[:page]}-preview")
  end

  def field(preview, id)
    preview.find_field(id: id)
  end

  def assert_text_contrast(element, label, mode, surface)
    ratio = contrast_ratio(color_of(:text, element), color_of(:background, element))
    assert_operator ratio, :>=, 4.5, "#{label} is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
  end

  def assert_focus_ring_contrast(element, preview, mode, surface)
    focus_visibly(element)
    assert_not_equal 'none', outline_of(element)['style'], 'element draws no focus outline'
    ring = color_of(:outline, element)
    ratio = contrast_ratio(ring, color_of(:background, preview))
    assert_operator ratio, :>=, 3, "focus ring is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    return unless fused_focus?(element)

    # The fused line touches the control's own fill as well as the surface, and it is one line
    # only if the border took the focus colour too (ui-presentational-components, rule 3).
    fill = contrast_ratio(ring, color_of(:background, element))
    assert_operator fill, :>=, 3, "fused focus line is #{fill.round(2)}:1 against the control's fill on #{surface} in #{mode} mode"
    assert_equal ring, settled_border(element, ring),
                 "the border did not take the focus colour on #{surface} in #{mode} mode, so the line reads as two"
  end

  # A flush outline is the fused form a bordered control draws; an offset one is the stand-off ring.
  def fused_focus?(element)
    page.evaluate_script('parseFloat(getComputedStyle(arguments[0]).outlineOffset) === 0', element)
  end

  # These controls animate colour, so the border is read until it settles rather than mid-fade.
  def settled_border(element, expected)
    border = color_of(:border, element)
    20.times do
      break if border == expected

      sleep 0.05
      border = color_of(:border, element)
    end
    border
  end
end
