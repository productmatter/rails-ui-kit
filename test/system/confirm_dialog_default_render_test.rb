# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'ui_overlay_helpers'

# What the default Ui::ConfirmDialogComponent renders, pinned (docs/specs/ui-confirm-dialog,
# § Acceptance checks, the first agent-loopable check; § Business rules, rule 6).
#
# Written and green against the unmodified 0.2.0 component before the rework touched it, and kept
# green unedited after. It pins everything except the icon: the icon cell's presence and the
# text column's inline offset are deliberately not asserted, because removing the icon moves
# them. Colour is not pinned either -- it moves to tokens -- except that Confirm stays in the
# destructive hue family. Proved able to fail by planting a changed footer padding.
#
# Every assertion reads the rendered result, never Ruby internals. The panel and body are found
# from the parts the dialog's contract names (the title, the method="dialog" form), not from
# classes, so the rework is free to restructure them.
class ConfirmDialogDefaultRenderTest < ApplicationSystemTestCase
  include UiOverlayHelpers

  # Long enough to wrap at both viewports, so the panel is at its width limit rather than
  # shrink-wrapped to a short sentence.
  LONG_MESSAGE = 'This permanently deletes the project, its files, its history and every comment ' \
                 'anyone has left on it. It cannot be undone.'

  WIDE = { viewport: [1280, 900], panel_width: 512.0, body_padding: [24, 24, 16, 24], footer_padding: [12, 24, 12, 24],
           text_align: 'start' }.freeze
  NARROW = { viewport: [375, 812], panel_width: 343.0, body_padding: [20, 16, 16, 16], footer_padding: [12, 16, 12, 16],
             text_align: 'center' }.freeze

  BUTTON_HEIGHT = 36.0
  BUTTON_GAP = 12.0

  # Padding is [top, right, bottom, left] in px, as CSS shorthand orders it, measured in LTR. Every box
  # is checked as laid out before it is measured: a zero-size box would pin nothing.
  LAYOUT_PROBE = <<~JS
    (() => {
      const dialog = document.getElementById('default-confirm')
      const footer = dialog.querySelector("form[method='dialog']")
      const panel = footer.parentElement
      const title = document.getElementById(dialog.getAttribute('aria-labelledby'))
      const message = document.getElementById(dialog.getAttribute('aria-describedby'))
      const body = Array.from(panel.children).find((child) => child.contains(title))
      const box = (element) => {
        const rect = element.getBoundingClientRect()
        if (rect.width === 0 || rect.height === 0) throw new Error(`${element.outerHTML.slice(0, 80)} is not laid out`)
        const style = getComputedStyle(element)
        const padding = ['Top', 'Right', 'Bottom', 'Left'].map((side) => parseFloat(style[`padding${side}`]))
        return { x: rect.x, y: rect.y, width: rect.width, height: rect.height, right: rect.right, bottom: rect.bottom, padding,
                 contentWidth: rect.width - padding[1] - padding[3], textAlign: style.textAlign,
                 font: [parseFloat(style.fontSize), parseInt(style.fontWeight, 10), parseFloat(style.lineHeight)] }
      }
      return { panel: box(panel), body: box(body), footer: box(footer), title: box(title), message: box(message),
               cancel: box(footer.querySelector("[value='cancel']")), confirm: box(footer.querySelector("[value='confirm']")) }
    })()
  JS

  teardown { page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride') }

  test 'CR1: the default dialog keeps its identity, names, default strings and answer form' do
    open_default_confirm('Delete this item?')

    dialog = find('dialog#default-confirm')
    assert_equal 'alertdialog', dialog['role']
    assert_equal I18n.t('rails_ui_kit.confirm_dialog.title'), find("##{dialog['aria-labelledby']}").text
    assert_equal 'Delete this item?', find("##{dialog['aria-describedby']}").text
    assert_equal I18n.t('rails_ui_kit.confirm_dialog.title'), dialog['data-default-title']
    assert_equal I18n.t('rails_ui_kit.confirm_dialog.message'), dialog['data-default-message']

    assert_selector "dialog#default-confirm form[method='dialog'] button[type='submit'][value='cancel']",
                    text: I18n.t('rails_ui_kit.confirm_dialog.cancel_label')
    assert_selector "dialog#default-confirm form[method='dialog'] button[type='submit'][value='confirm']",
                    text: I18n.t('rails_ui_kit.confirm_dialog.confirm_label')
    assert page.evaluate_script(<<~JS), 'Cancel does not come before Confirm in the DOM'
      (() => {
        const [cancel, confirm] = ['cancel', 'confirm'].map((v) => document.querySelector(`#default-confirm button[value='${v}']`))
        return !!(cancel.compareDocumentPosition(confirm) & Node.DOCUMENT_POSITION_FOLLOWING)
      })()
    JS
    assert_equal 'cancel', page.evaluate_script('document.activeElement.value'), 'Cancel is not focused on open'
  end

  test 'CR2: at 1280px the panel is 512px and centred, with Cancel then Confirm side by side at the end' do
    layout = measure(WIDE)
    assert_common_metrics(layout, WIDE)

    assert_in_delta 640, layout['panel']['x'] + (layout['panel']['width'] / 2), 1, 'the panel is not centred horizontally'
    assert_in_delta 450, layout['panel']['y'] + (layout['panel']['height'] / 2), 1, 'the panel is not centred vertically'

    cancel, confirm, footer = layout.values_at('cancel', 'confirm', 'footer')
    assert_operator cancel['width'], :<, footer['contentWidth'] / 2, 'the buttons are not auto width at sm and up'
    assert_in_delta cancel['right'] + BUTTON_GAP, confirm['x'], 0.5, 'Cancel is not directly before Confirm on screen'
    assert_in_delta cancel['y'], confirm['y'], 0.5, 'Cancel and Confirm are not on one row'
    assert_in_delta footer['right'] - footer['padding'][1], confirm['right'], 0.5, 'the buttons are not end-aligned'
  end

  test 'CR3: at 375px the panel fills the width at the bottom, with full-width Cancel stacked above Confirm' do
    layout = measure(NARROW)
    assert_common_metrics(layout, NARROW)

    assert_in_delta 812 - 16, layout['panel']['bottom'], 1, 'the panel does not sit at the bottom of the viewport'

    cancel, confirm, footer = layout.values_at('cancel', 'confirm', 'footer')
    [cancel, confirm].each do |button|
      assert_in_delta footer['contentWidth'], button['width'], 0.5, 'a button is not full width below sm'
    end
    assert_in_delta cancel['bottom'] + BUTTON_GAP, confirm['y'], 0.5, 'Cancel is not directly above Confirm'
  end

  test 'CR4: Confirm is filled in the destructive hue family, in light and dark mode' do
    open_default_confirm('Delete this item?')
    disable_transitions
    confirm = find("#default-confirm button[value='confirm']")

    { 'light' => false, 'dark' => true }.each do |mode, dark|
      use_dark_mode(dark)
      rgb = color_of(:background, confirm)
      hue, saturation = hue_and_saturation(rgb)
      assert_operator saturation, :>, 0.25, "Confirm's fill is not a saturated colour in #{mode} mode: #{rgb.inspect}"
      assert_operator [hue, 360 - hue].min, :<, 35,
                      "Confirm's fill is #{hue.round}deg, outside the destructive red family, in #{mode} mode: #{rgb.inspect}"
    end
  end

  test 'CR5: Escape closes the dialog and answers false; a click outside the panel does neither' do
    open_default_confirm('Delete this item?')
    page.driver.browser.action.move_to_location(10, 10).click.perform
    sleep 0.3 # a dismissal, if the click caused one, starts in the task after it
    assert_selector 'dialog#default-confirm[open]'
    assert_equal 'pending', page.evaluate_script('window.__answer')

    press :escape
    assert_no_selector 'dialog#default-confirm[open]'
    wait_until("window.__answer !== 'pending'")
    assert_equal false, page.evaluate_script('window.__answer')
  end

  private

  def open_default_confirm(message)
    visit confirm_dialog_path unless page.current_path == confirm_dialog_path
    wait_until("typeof window.defaultConfirmDialog === 'function'")
    page.execute_script(<<~JS, message)
      window.__answer = 'pending'
      window.defaultConfirmDialog(arguments[0]).then((answer) => { window.__answer = answer })
    JS
    assert_selector 'dialog#default-confirm[open]'
    assert_state '#default-confirm', 'open'
  end

  # HSL hue in degrees (red is 0, and wraps) and saturation, from a painted [r, g, b]. The hue
  # family, not one colour: the pinned property is "destructive red", which survives the move
  # from a palette literal to the --destructive token and its different light and dark values.
  def hue_and_saturation(rgb)
    channels = rgb.map { |channel| channel / 255.0 }
    [hue_of(channels), saturation_of(channels)]
  end

  def hue_of(channels)
    red, green, blue = channels
    radians = Math.atan2(Math.sqrt(3) * (green - blue), (2 * red) - green - blue)
    (radians * 180 / Math::PI) % 360
  end

  def saturation_of(channels)
    high, low = channels.minmax.reverse
    high.zero? ? 0.0 : (high - low) / high
  end

  # Waits, as a Capybara assertion does, for a script expression to become true.
  def wait_until(expression)
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.02 until page.evaluate_script(expression) }
  rescue Timeout::Error
    flunk "timed out waiting for #{expression}"
  end

  def measure(size)
    emulate_viewport(*size[:viewport])
    visit confirm_dialog_path
    assert_equal size[:viewport][0], page.evaluate_script('innerWidth'), 'the viewport was not emulated'
    open_default_confirm(LONG_MESSAGE)
    page.evaluate_script(LAYOUT_PROBE)
  end

  def emulate_viewport(width, height)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: width, height: height,
                                                                          deviceScaleFactor: 1, mobile: false)
  end

  def assert_common_metrics(layout, size)
    assert_in_delta size[:panel_width], layout['panel']['width'], 0.5, 'the panel width moved'
    assert_equal size.values_at(:body_padding, :footer_padding), [layout['body']['padding'], layout['footer']['padding']],
                 'the body or footer padding moved'
    %w[cancel confirm].each do |button|
      assert_in_delta BUTTON_HEIGHT, layout[button]['height'], 0.5, "#{button}'s height moved"
    end
    assert_text_metrics(layout, size)
  end

  def assert_text_metrics(layout, size)
    title, message = layout.values_at('title', 'message')
    assert_equal [16, 600, 24], title['font'], "the title's size, weight or line height moved"
    assert_equal [14, 400, 20], message['font'], "the message's size, weight or line height moved"
    assert_equal [size[:text_align]] * 2, [title['textAlign'], message['textAlign']], 'the text alignment moved'
  end
end
