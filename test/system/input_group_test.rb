# frozen_string_literal: true

require 'application_system_test_case'

class InputGroupTest < ApplicationSystemTestCase
  setup do
    visit input_group_path
    disable_transitions
  end

  # The hard part: focus moves into the control, the group draws the indicator,
  # and the control draws none of its own.
  test 'the group draws the focus indicator when its control is focused, not the control itself' do
    each_token_surface(preview) do |mode, surface|
      input = field('focused-input')
      group = group_for(input)

      focus_visibly(input)

      input_outline = outline_of(input)
      assert(input_outline['style'] == 'none' || input_outline['width'].to_f.zero?,
             "the control draws its own outline (#{input_outline}) on #{surface} in #{mode} mode")

      group_outline = outline_of(group)
      assert_not_equal 'none', group_outline['style'], "the group draws no focus outline on #{surface} in #{mode} mode"
      assert_operator group_outline['width'].to_f, :>=, 2, "the group's focus outline is too thin on #{surface} in #{mode} mode"

      ratio = contrast_ratio(color_of(:outline, group), color_of(:background, preview))
      assert_operator ratio, :>=, 3, "the group's focus outline is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test "the focus indicator survives forced-colors mode on a grouped control's own Button addon" do
    assert_focus_outline_in_forced_colors(preview.find('[data-slot=input-group-addon] [data-slot=button]', text: 'Send'), 'Send button')
  end

  test 'entered text reaches 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      input = field('focused-input')
      ratio = contrast_ratio(color_of(:text, input), color_of(:background, input))
      assert_operator ratio, :>=, 4.5, "entered text is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'the group boundary reaches 3:1 against its fill and the surface in light and dark mode, including when invalid' do
    each_token_surface(preview) do |mode, surface|
      %w[focused-input invalid-input].each do |id|
        group = group_for(field(id))
        border = color_of(:border, group)
        { 'fill' => color_of(:background, group), 'surface' => color_of(:background, preview) }.each do |against, color|
          ratio = contrast_ratio(border, color)
          assert_operator ratio, :>=, 3, "#{id} group boundary is #{ratio.round(2)}:1 against its #{against} on #{surface} in #{mode} mode"
        end
      end
    end
  end

  test 'an invalid control is reflected on the group, not just the (suppressed) control border' do
    group = group_for(field('invalid-input'))
    assert_includes group['class'].split, 'has-[[data-slot=input][aria-invalid=true]]:border-destructive'
  end

  test 'a block-end addon stacks the group into a column' do
    textarea = preview.find_field(id: 'message-textarea')
    group = group_for(textarea)

    textarea_rect = rect(textarea)
    addon_rect = rect(group.find('[data-slot=input-group-addon]'))

    assert_operator addon_rect['top'], :>=, textarea_rect['bottom'] - 0.5, 'the block-end addon does not sit below the textarea'
  end

  test 'the input_group preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#input_group-preview')

    use_dark_mode(true)
    assert_accessible(within: '#input_group-preview')
  end

  private

  def preview
    find_by_id('input_group-preview')
  end

  def field(id)
    preview.find_field(id: id)
  end

  def group_for(control)
    control.find(:xpath, 'ancestor::div[@data-slot="input-group"]')
  end

  def rect(element)
    page.evaluate_script(<<~JS, element)
      (() => { const r = arguments[0].getBoundingClientRect(); return { top: r.top, bottom: r.bottom } })()
    JS
  end
end
