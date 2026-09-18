# frozen_string_literal: true

require 'application_system_test_case'

# Form controls carry an explicit fill in both modes, so a control reads as a control on any
# surface instead of inheriting whatever it sits on (decided 2026-09-14, Jonathan Simmons;
# ui-presentational-components § Business rules, rule 6(a)). Inside a muted card a transparent
# control read as a sunken grey panel. Measured on the Field page's mixed row, which holds
# Input, both Select modes and Textarea side by side.
class ControlFillTest < ApplicationSystemTestCase
  # The painted colour and alpha of an element's own background-color alone, on a transparent
  # canvas: alpha 0 means the control has no fill of its own and shows its surface through.
  OWN_FILL = <<~JS
    ((element) => {
      const canvas = document.createElement('canvas')
      canvas.width = canvas.height = 1
      const context = canvas.getContext('2d', { willReadFrequently: true })
      context.fillStyle = getComputedStyle(element).backgroundColor
      context.fillRect(0, 0, 1, 1)
      return Array.from(context.getImageData(0, 0, 1, 1).data)
    })(arguments[0])
  JS

  setup do
    visit field_path
    disable_transitions
  end

  test 'CF1 in light mode every control is filled with --background, whatever surface it sits on' do
    use_dark_mode(false)
    each_surface do |surface|
      expected = color_of(:background, background_probe)

      controls.each do |name, control|
        assert_equal expected, color_of(:background, control),
                     "#{name} shows its #{surface} surface through instead of the --background fill"
      end
    end
  end

  test 'CF2 in dark mode every control has a fill of its own, not the surface behind it' do
    use_dark_mode(true)

    controls.each do |name, control|
      alpha = page.evaluate_script(OWN_FILL, control).last
      assert_operator alpha, :>, 0, "#{name} has no fill of its own in dark mode"
    end
  end

  test 'CF3 an enhanced Select paints its fill on the combobox, the element a user actually sees' do
    %w[light dark].each do |mode|
      use_dark_mode(mode == 'dark')
      combobox = find('#sizes-default-select-combobox')
      native = find('#sizes-default-select', visible: :all)

      assert_equal '0', native.native.css_value('opacity'), 'the native select should be laid over at opacity 0'
      assert_equal color_of(:background, find('#sizes-default-input')), color_of(:background, combobox),
                   "the enhanced Select's box doesn't match Input's fill in #{mode} mode"
    end
  end

  test 'CF4 the open list is opaque in both modes' do
    %w[light dark].each do |mode|
      use_dark_mode(mode == 'dark')
      find('#sizes-default-select-combobox').click
      popup = find('#sizes-default-select-popup')

      assert_equal 255, page.evaluate_script(OWN_FILL, popup).last, "the Select popup is see-through in #{mode} mode"
      find('#sizes-default-select-combobox').send_keys(:escape)
      assert_no_selector '#sizes-default-select-popup:popover-open'
    end
  end

  private

  def controls
    {
      'Input' => find('#sizes-default-input'),
      'Textarea' => find('#sizes-default-textarea'),
      'select-only Select' => find('#sizes-default-select-combobox'),
      'search Select' => find('#sizes-default-search-trigger')
    }
  end

  def preview
    find_by_id('control-sizes-preview')
  end

  # A painted --background, composited from <html> down, to compare fills against.
  def background_probe
    @background_probe ||= begin
      page.execute_script(<<~JS)
        const probe = document.createElement('div')
        probe.id = 'background-probe'
        probe.style.cssText = 'position:absolute;width:1px;height:1px;background:var(--background)'
        document.body.appendChild(probe)
      JS
      find_by_id('background-probe', visible: :all)
    end
  end

  def each_surface
    TOKEN_SURFACES.each do |surface|
      page.execute_script("arguments[0].style.backgroundColor = 'var(#{surface})'", preview)
      yield surface
    end
  end
end
