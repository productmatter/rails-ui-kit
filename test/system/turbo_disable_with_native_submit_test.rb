# frozen_string_literal: true

require 'application_system_test_case'

# ui--turbo-disable-with on a form Turbo doesn't drive (`data-turbo="false"`), where the browser
# submits it: it builds the form data set after the `submit` event, and leaves out every disabled
# control, so a button disabled inside that event never sends its own name and value. And on
# any form, the button's own content comes back as the nodes it had, not a re-parse of them.
class TurboDisableWithNativeSubmitTest < ApplicationSystemTestCase
  NATIVE_FORM = <<~JS
    const form = document.createElement('form')
    form.id = 'native-form'
    form.method = 'get'
    form.action = window.location.pathname
    form.dataset.turbo = 'false'
    const field = document.createElement('input')
    field.name = 'note'
    field.value = 'kept'
    const button = document.createElement('button')
    button.id = 'native-submit'
    button.name = 'decision'
    button.value = 'approve'
    button.dataset.turboDisableWith = 'Approving...'
    button.textContent = 'Approve'
    form.append(field, button)
    document.querySelector('h1').after(form)
  JS

  def add_native_form
    page.execute_script(NATIVE_FORM)
    assert_selector '#native-submit', text: 'Approve'
  end

  test 'TDW3 the clicked button name and value reach the server from a data-turbo="false" form' do
    visit turbo_disable_with_path
    add_native_form

    find('#native-submit').click

    assert_no_selector '#native-form'
    query = Rack::Utils.parse_query(URI.parse(current_url).query)
    assert_equal({ 'note' => 'kept', 'decision' => 'approve' }, query)
  end

  test 'TDW4 a submission another listener cancels leaves the button as it was' do
    visit turbo_disable_with_path
    add_native_form
    # Registered after the controller's own document listener, so it runs after it.
    page.execute_script(<<~JS)
      document.addEventListener('submit', (event) => {
        if (event.target.id === 'native-form') event.preventDefault()
      })
    JS

    find('#native-submit').click

    state = page.evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      setTimeout(() => {
        const button = document.getElementById('native-submit')
        done([button.disabled, button.textContent, button.getAttribute('aria-busy')])
      }, 100)
    JS
    assert_equal [false, 'Approve', nil], state
  end

  test 'TDW5 Back to a page the browser kept in its back/forward cache shows the button restored' do
    visit turbo_disable_with_path
    add_native_form
    find('#native-submit').click
    assert_no_selector '#native-form'

    page.go_back

    # The injected form only exists on a page restored from the cache, never on a fresh load.
    assert_selector '#native-form'
    assert_selector '#native-submit:not([disabled]):not([aria-busy])', text: 'Approve', exact_text: true
  end

  test 'TDW6 the button gets its own child nodes back, not a re-parse of them' do
    visit turbo_disable_with_path
    button = find("button[data-turbo-disable-style='spinner']")
    page.execute_script(<<~JS, button)
      const icon = document.createElement('span')
      icon.textContent = 'Spinner style'
      arguments[0].replaceChildren(icon)
      window.__icon = icon
    JS

    button.click
    assert_selector "button[data-turbo-disable-style='spinner'][aria-busy='true'] svg"
    assert_selector "button[data-turbo-disable-style='spinner']:not([aria-busy])", text: 'Spinner style'

    assert page.evaluate_script('document.querySelector("button[data-turbo-disable-style=spinner]").firstChild === window.__icon')
  end

  test 'TDW7 a page enforcing Trusted Types still gets the spinner and the restore' do
    visit turbo_disable_with_path
    page.execute_script(<<~JS)
      window.__violations = []
      document.addEventListener('securitypolicyviolation', (event) => window.__violations.push(event.sample))
      const policy = document.createElement('meta')
      policy.httpEquiv = 'Content-Security-Policy'
      policy.content = "require-trusted-types-for 'script'"
      document.head.append(policy)
    JS
    button = find("button[data-turbo-disable-style='spinner']")
    page.execute_script(<<~JS, button)
      window.__icon = document.createElement('span')
      window.__icon.textContent = 'Spinner style'
      arguments[0].replaceChildren(window.__icon)
    JS

    button.click
    assert_selector "button[data-turbo-disable-style='spinner'][aria-busy='true'] svg circle"
    assert_selector "button[data-turbo-disable-style='spinner']:not([aria-busy])", text: 'Spinner style'

    assert_empty page.evaluate_script('window.__violations')
  end
end
