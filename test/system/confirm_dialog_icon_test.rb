# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'confirm_dialog_helpers'

# The icon UPGRADING.md restores, measured (docs/specs/ui-confirm-dialog, § Acceptance checks).
# The component renders no glyph; the cell it renders around a caller's one keeps the size and the
# placement 0.2.0's had, so a host that pastes the snippet gets the dialog it used to have.
#
# The reference geometry was measured against the 0.2.0 component before it was changed:
# a 40px cell at the panel's inline-start with its top on the title's, 16px from the text column,
# and a centred 48px cell 12px above the title below `sm`.
class ConfirmDialogIconTest < ApplicationSystemTestCase
  include ConfirmDialogHelpers

  # Read in one call, and every box proved laid out before it is measured.
  ICON_PROBE = <<~JS
    (() => {
      const dialog = document.getElementById('icon-confirm')
      const icon = dialog.querySelector('[data-slot=confirm-dialog-icon]')
      const title = dialog.querySelector('[data-ui--dialog-title]')
      const body = dialog.querySelector("form[method='dialog']").parentElement.firstElementChild
      const box = (element) => {
        const rect = element.getBoundingClientRect()
        if (rect.width === 0 || rect.height === 0) throw new Error('a reference box is not laid out')
        return { x: rect.x, y: rect.y, width: rect.width, height: rect.height, right: rect.right,
                 bottom: rect.bottom, paddingLeft: parseFloat(getComputedStyle(element).paddingLeft) }
      }
      return { icon: box(icon), title: box(title), body: box(body) }
    })()
  JS

  teardown { page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride') }

  test 'CI1: at sm and up the icon cell is 40px at the inline-start, aligned with the title' do
    boxes = icon_boxes(1280, 900)

    assert_equal [40, 40], boxes['icon'].values_at('width', 'height'), 'the icon cell is not 40px from sm up'
    assert_in_delta boxes['icon']['y'], boxes['title']['y'], 0.5, "the icon's top is not on the title's"
    assert_in_delta 16, boxes['title']['x'] - boxes['icon']['right'], 0.5, 'the gap to the text column moved'
    assert_in_delta boxes['body']['x'] + boxes['body']['paddingLeft'], boxes['icon']['x'], 0.5,
                    'the icon does not start at the panel padding'
  end

  test 'CI2: below sm the icon cell is a centred 48px above the title' do
    boxes = icon_boxes(375, 812)

    assert_equal [48, 48], boxes['icon'].values_at('width', 'height'), 'the icon cell is not 48px below sm'
    assert_in_delta 12, boxes['title']['y'] - boxes['icon']['bottom'], 0.5, 'the gap above the title moved'
    assert_in_delta boxes['body']['x'] + (boxes['body']['width'] / 2), boxes['icon']['x'] + 24, 0.5,
                    'the icon is not centred'
  end

  test 'CI3: the icon is decoration: aria-hidden, and the words carry the meaning' do
    visit confirm_dialog_path
    open_custom_confirm('#icon-confirm')

    cell = find('#icon-confirm [data-slot=confirm-dialog-icon]', visible: :all)
    assert_equal 'true', cell['aria-hidden']
    assert_selector '#icon-confirm [data-ui--dialog-title]', text: 'Delete this project?'
    assert_equal 'Delete project', confirm_button.text.strip
    assert_accessible(within: '#icon-confirm')
    cancel_confirm
  end

  private

  def icon_boxes(width, height)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: width, height: height,
                                                                          deviceScaleFactor: 1, mobile: false)
    visit confirm_dialog_path
    open_custom_confirm('#icon-confirm')

    page.evaluate_script(ICON_PROBE)
  end
end
