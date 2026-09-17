# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'toast_helpers'

# Tokens and theming, measured (docs/specs/ui-toast, § Acceptance checks): every type's glyph and
# countdown bar reach 3:1 on the toast's own surface in both modes, and a toast with actions passes
# an axe audit in both modes.
class ToastAccessibilityTest < ApplicationSystemTestCase
  include ToastHelpers

  GRAPHIC_MINIMUM = 3.0

  test 'TA1: a toast with actions, and one of each type, pass axe in light and dark' do
    visit toast_path
    fire_every_toast
    disable_transitions

    [false, true].each do |dark|
      use_dark_mode(dark)
      assert_accessible(within: '#ui-toasts')
    end
  end

  test "TA2: each type's glyph and bar reach 3:1 against the toast surface in both modes" do
    visit toast_path
    fire_every_toast
    disable_transitions

    { 'light' => false, 'dark' => true }.each do |mode, dark|
      use_dark_mode(dark)
      Ui::ToastComponent::TYPES.each do |type|
        toast = find("#{TOAST}[data-ui--toast-type-value='#{type}']", match: :first)
        surface = color_of(:background, toast)
        glyph = color_of(:text, toast.find('[data-slot=toast-icon]'))
        bar = color_of(:background, toast.find('[data-ui--toast-target=timer]', visible: :all))

        assert_operator contrast_ratio(glyph, surface), :>=, GRAPHIC_MINIMUM, "the #{type} glyph in #{mode} mode"
        assert_operator contrast_ratio(bar, surface), :>=, GRAPHIC_MINIMUM, "the #{type} bar in #{mode} mode"
      end
    end
  end

  private

  # Persisting toasts, so none leaves mid-audit: each type with a countdown of a minute, and the
  # archived payload with its actions.
  def fire_every_toast
    wait_for_toast_api
    Ui::ToastComponent::TYPES.each do |type|
      trigger_toast(type: type, title: type.to_s.capitalize, description: "A #{type} toast.", duration: 60_000)
    end
    trigger_toast(ToastsController.scenario('archived'))
    settled_toast
  end
end
