# frozen_string_literal: true

require 'application_system_test_case'

# ui--turbo-disable-with replaces a submitting button's content with its disable text. That
# text is chrome: it comes from a translation or from the call site, so it can legitimately
# contain a quote, an ampersand or an angle bracket, and it must reach the DOM as characters
# rather than as markup (ui-localization § Behavior, item 11).
class TurboDisableWithTest < ApplicationSystemTestCase
  # Quote: breaks out of aria-label="…" in an interpolated template. Angle brackets: open an
  # element. Ampersand: the entity round-trip. One string covers all three.
  HOSTILE = 'He said "no" & <script>window.__pwned = true</script><b>bold</b>'

  # The demo endpoint sleeps 1.5s, and the disabled state only exists while the submission is in
  # flight, so every assertion below runs inside that window.
  %w[spinner pulse text].each do |style|
    test "TDW1 the #{style} style renders hostile disable text as characters, not markup" do
      visit turbo_disable_with_path
      button = find("button[data-turbo-disable-style='#{style}']")
      page.execute_script('arguments[0].dataset.turboDisableWith = arguments[1]', button, HOSTILE)

      button.click

      assert_selector "button[data-turbo-disable-style='#{style}'][aria-busy='true']"
      disabled = find("button[data-turbo-disable-style='#{style}']")
      assert_equal HOSTILE, disabled.text(:all).strip
      assert_no_selector "button[data-turbo-disable-style='#{style}'] script", visible: :all
      assert_no_selector "button[data-turbo-disable-style='#{style}'] b", visible: :all
      assert_nil page.evaluate_script('window.__pwned ?? null')

      named = page.evaluate_script(<<~JS, style)
        (() => {
          const button = document.querySelector(`button[data-turbo-disable-style='${arguments[0]}']`)
          const labelled = button.querySelector('[role="status"]') || button
          return labelled.getAttribute('aria-label')
        })()
      JS
      assert_equal HOSTILE, named
    end
  end

  test 'TDW2 the announcement carries the text as characters too' do
    visit turbo_disable_with_path
    button = find("button[data-turbo-disable-style='spinner']")
    page.execute_script('arguments[0].dataset.turboDisableWith = arguments[1]', button, HOSTILE)

    button.click

    # The controller writes the announcement 100ms after clearing the region, so this has to
    # wait for it: a bare read races that timeout and loses it every time under SLOW=1.
    assert_selector '#rails-ui-kit-announcer', text: HOSTILE, exact_text: true, visible: :all
    assert_no_selector '#rails-ui-kit-announcer script', visible: :all
  end

  # Turbo disables the submitter while the request runs, and Chrome moves focus off a disabled
  # element to <body>; focus goes back to the button once the submission ends (ui-stress-page,
  # open-questions.md, "Where does focus belong after a Turbo form submission?").
  test 'TDW3 the button that had focus when its form was submitted has it back when the submission ends' do
    button = start_submission('text')

    wait_for_script('document.activeElement === document.body', 'focus never left the disabled button')
    wait_for_script('window.__submitEnds === 1', 'the submission never ended')
    assert page.evaluate_script('document.activeElement === arguments[0]', button), 'focus was not put back on the button'
  end

  test 'TDW4 focus taken by something else while the submission runs stays where it was taken' do
    button = start_submission('text')
    page.execute_script(<<~JS)
      const other = document.createElement('button')
      other.id = 'tdw4-elsewhere'
      other.textContent = 'Elsewhere'
      document.querySelector('main').prepend(other)
      other.focus()
    JS

    wait_for_script('window.__submitEnds === 1', 'the submission never ended')
    assert_equal 'tdw4-elsewhere', page.evaluate_script('document.activeElement.id')
    assert_not page.evaluate_script('document.activeElement === arguments[0]', button)
  end

  private

  def start_submission(style)
    visit turbo_disable_with_path
    page.execute_script("window.__submitEnds = 0; document.addEventListener('turbo:submit-end', () => window.__submitEnds++)")
    button = find("button[data-turbo-disable-style='#{style}']")
    button.click
    assert_selector "button[data-turbo-disable-style='#{style}'][aria-busy='true']"
    button
  end

  def wait_for_script(expression, message)
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.02 until page.evaluate_script(expression) }
  rescue Timeout::Error
    flunk message
  end
end
