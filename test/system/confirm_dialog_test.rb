# frozen_string_literal: true

require 'application_system_test_case'

class ConfirmDialogTest < ApplicationSystemTestCase
  test 'CD2: navigating away and back leaves the dialog closed, and a fresh confirm still works' do
    visit confirm_dialog_path
    click_on 'Delete item'
    assert_selector 'dialog[open]#default-confirm'

    # The open dialog's native backdrop blocks every click, including a sidebar link, so
    # trigger the Turbo visit directly -- this is exactly the path a real navigation takes.
    page.execute_script('Turbo.visit(arguments[0])', installation_path)
    assert_selector 'h1', text: 'Installation'
    page.go_back
    assert_selector 'h1', text: 'Confirm Dialog'
    assert_no_selector 'dialog[open]'

    page.execute_script(<<~JS)
      window.__cdResult = null
      window.defaultConfirmDialog("Delete this item?").then(function(v) { window.__cdResult = v })
    JS
    assert_selector 'dialog[open]#default-confirm'
    assert page.evaluate_script("document.getElementById('default-confirm').matches(':modal')")

    find("button[value='cancel']").click
    assert_no_selector 'dialog[open]'
    assert_equal false, wait_for_js_result('window.__cdResult')
  end

  test 'CD3: opening a confirm focuses Cancel, and Enter resolves false instead of confirming' do
    visit confirm_dialog_path
    page.execute_script(<<~JS)
      window.__cdResult = null
      window.defaultConfirmDialog("Delete this item?").then(function(v) { window.__cdResult = v })
    JS
    assert_selector 'dialog[open]'
    assert_equal 'cancel', page.evaluate_script('document.activeElement.value')

    find("button[value='cancel']").send_keys(:enter)
    assert_no_selector 'dialog[open]'
    assert_equal false, wait_for_js_result('window.__cdResult')
  end

  test 'CD4: tab order and on-screen order both put Cancel before Confirm' do
    visit confirm_dialog_path
    click_on 'Delete item'
    assert_selector 'dialog[open]'

    cancel_x = page.evaluate_script("document.querySelector(\"button[value='cancel']\").getBoundingClientRect().x")
    confirm_x = page.evaluate_script("document.querySelector(\"button[value='confirm']\").getBoundingClientRect().x")
    assert cancel_x < confirm_x, "expected Cancel (#{cancel_x}) to sit left of Confirm (#{confirm_x})"

    assert_equal 'cancel', page.evaluate_script('document.activeElement.value')
    find("button[value='cancel']").send_keys(:tab)
    assert_equal 'confirm', page.evaluate_script('document.activeElement.value')

    find("button[value='confirm']").click # close it, avoid leaking an open native dialog into the next test
  end

  test 'CD5: the dialog is an alertdialog described by its message text' do
    visit confirm_dialog_path
    click_on 'Publish'
    dialog = find('dialog[open]')
    assert_equal 'alertdialog', dialog['role']

    described_by = dialog['aria-describedby']
    assert_equal 'This will make the post visible to all users.', find("##{described_by}").text

    find("button[value='cancel']").click
  end

  test 'CD6: Cancel shows a 2px focus outline when reached by keyboard' do
    visit confirm_dialog_path
    click_on 'Delete item'
    assert_selector 'dialog[open]'

    find("button[value='cancel']").send_keys(:tab)
    assert_equal 'confirm', page.evaluate_script('document.activeElement.value')

    find("button[value='confirm']").send_keys(%i[shift tab])
    assert_equal 'cancel', page.evaluate_script('document.activeElement.value')

    outline_width = page.evaluate_script('getComputedStyle(document.activeElement).outlineWidth')
    assert_equal '2px', outline_width

    find("button[value='cancel']").click
  end

  test 'CD1: no inline event-handler attributes, and both buttons resolve through a method=dialog form' do
    visit confirm_dialog_path
    page.execute_script(<<~JS)
      window.__cdResult = null
      window.defaultConfirmDialog("Delete this item?").then(function(v) { window.__cdResult = v })
    JS
    assert_selector 'dialog[open]'

    html = page.evaluate_script("document.getElementById('default-confirm').outerHTML")
    refute_match(/\son\w+\s*=/i, html)
    assert_selector "dialog form[method='dialog'] button[type='submit'][value='cancel']"
    assert_selector "dialog form[method='dialog'] button[type='submit'][value='confirm']"

    find("button[value='confirm']").click
    assert_no_selector 'dialog[open]'
    assert_equal true, wait_for_js_result('window.__cdResult')
  end

  test "CD7: a close event still queued from a cancelled confirm doesn't settle the next confirm's promise" do
    visit confirm_dialog_path
    page.execute_script(<<~JS)
      window.__cdFirst = null
      window.__cdSecond = null
      window.defaultConfirmDialog("First?").then(function(v) { window.__cdFirst = v })
    JS
    assert_selector 'dialog[open]', text: 'First?'

    # Cancel and reopen in one task, so the first cycle's native "close" event, which the
    # browser queues as a separate task, is guaranteed to arrive while the second is open.
    page.execute_script(<<~JS)
      document.querySelector("#default-confirm button[value='cancel']").click()
      window.defaultConfirmDialog("Second?").then(function(v) { window.__cdSecond = v })
    JS
    assert_equal false, wait_for_js_result('window.__cdFirst')
    assert_selector 'dialog[open]', text: 'Second?'
    assert_nil page.evaluate_script('window.__cdSecond')

    find("button[value='confirm']").click
    assert_no_selector 'dialog[open]'
    assert_equal true, wait_for_js_result('window.__cdSecond')
  end

  test 'Escape, and navigating away while a confirm is open, each resolve the pending promise false' do
    visit confirm_dialog_path
    open_confirm = <<~JS
      window.__cdResult = null
      window.defaultConfirmDialog("Delete this item?").then(function(v) { window.__cdResult = v })
    JS

    page.execute_script(open_confirm)
    assert_selector 'dialog[open]'
    find("button[value='cancel']").send_keys(:escape)
    assert_no_selector 'dialog[open]'
    assert_equal false, wait_for_js_result('window.__cdResult')

    page.execute_script(open_confirm)
    assert_selector 'dialog[open]'
    page.execute_script('Turbo.visit(arguments[0])', installation_path)
    assert_selector 'h1', text: 'Installation'
    assert_equal false, wait_for_js_result('window.__cdResult')
  end

  private

  # A dialog's native "close" event lands on a browser task queue rather than
  # inside the click that triggered it, so the promise it settles can still be
  # pending for a tick after Capybara's click returns. Poll instead of asserting once.
  def wait_for_js_result(expression, timeout: Capybara.default_max_wait_time)
    deadline = Time.now + timeout
    loop do
      value = page.evaluate_script(expression)
      return value unless value.nil?
      raise "timed out waiting for #{expression} to settle" if Time.now > deadline

      sleep 0.05
    end
  end
end
