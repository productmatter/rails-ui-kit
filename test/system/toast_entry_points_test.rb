# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'toast_helpers'

# The same payload renders the same markup from every entry point (docs/specs/ui-toast,
# § Behavior, item 7; § Business rules, rule 10): a Ruby render (here, the container rendering a
# flash toast: payload after a redirect), a turbo_stream.ui_toast response, and
# window.triggerToast. Once each toast's enter has settled, their outerHTML is compared with the
# differences that are allowed normalised away: generated ids, whitespace between tags, and the
# countdown bar's inline style, which the controller writes at runtime to all three alike.
class ToastEntryPointsTest < ApplicationSystemTestCase
  include ToastHelpers

  NORMALISE = <<~JS
    ((toast) => toast.outerHTML
      .replace(/ui-toast-[0-9a-f]+/g, 'ui-toast-ID')
      .replace(/\\sstyle="[^"]*"/g, '')
      .replace(/>\\s+</g, '><'))(arguments[0])
  JS

  %w[archived timed].each do |scenario|
    test "TE1: the #{scenario} payload renders identically from Ruby, a Turbo Stream and JavaScript" do
      markups = render_from_every_entry_point(scenario)

      assert_equal markups[:ruby], markups[:turbo_stream], 'a Turbo Stream toast differs from a Ruby-rendered one'
      assert_equal markups[:ruby], markups[:javascript], 'a JavaScript toast differs from a Ruby-rendered one'
    end
  end

  test 'TE2: the comparison can fail -- one extra class planted on the JavaScript template shows up' do
    visit demo_toast_flash_path(scenario: 'archived')
    ruby = normalised(settled_toast)
    remove_toasts

    page.execute_script(<<~JS)
      const template = document.querySelector('template[data-toast-type="success"]')
      template.content.firstElementChild.classList.add('planted')
    JS
    trigger_toast(ToastsController.scenario('archived'))

    assert_not_equal ruby, normalised(settled_toast)
  end

  private

  def render_from_every_entry_point(scenario)
    visit demo_toast_flash_path(scenario: scenario)
    ruby = capture_and_remove

    send_stream(scenario)
    turbo_stream = capture_and_remove

    trigger_toast(ToastsController.scenario(scenario))
    { ruby: ruby, turbo_stream: turbo_stream, javascript: capture_and_remove }
  end

  # The docs page's stream button, pointed at the scenario under test.
  def send_stream(scenario)
    button = find('button#toast-stream-archived')
    page.execute_script("arguments[0].form.action = arguments[0].form.action.replace(/scenario=[a-z]+/, 'scenario=' + arguments[1])",
                        button, scenario)
    button.click
  end

  def capture_and_remove
    markup = normalised(settled_toast)
    remove_toasts
    markup
  end

  def normalised(toast)
    page.evaluate_script(NORMALISE, toast)
  end

  def remove_toasts
    page.execute_script("document.querySelectorAll('#{TOAST}').forEach((toast) => toast.remove())")
    assert_no_selector TOAST
  end
end
