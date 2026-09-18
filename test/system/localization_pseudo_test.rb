# frozen_string_literal: true

require 'application_system_test_case'

# The pseudo-locale pass (ui-localization § Acceptance checks). Two failures at once: a chrome
# string that renders in plain English never went through I18n, and a box that clips or shoves
# its neighbours at +40% will do the same in German.
class LocalizationPseudoTest < ApplicationSystemTestCase
  PSEUDO = { locale: PseudoLocale::LOCALE }.freeze
  MARK = PseudoLocale::OPEN

  def pseudo(key)
    I18n.t("rails_ui_kit.#{key}", locale: PseudoLocale::LOCALE)
  end

  test 'LP1 a toast, server-rendered and JavaScript-created, is pseudo-translated throughout' do
    visit toast_path(**PSEUDO)

    assert_includes page.html, %(aria-label="#{pseudo('toast.close_label')}")
    assert_not_includes page.html, 'aria-label="Close notification"'

    page.execute_script('window.triggerToast("info")')
    assert_selector "[data-ui--toast-target='title']", text: pseudo('toast.default_title')
    assert_selector "[data-controller='ui--toast'] button[aria-label='#{pseudo('toast.close_label')}']"
  end

  test 'LP2 the confirm dialog is pseudo-translated, title, message and both buttons' do
    visit confirm_dialog_path(**PSEUDO)
    page.execute_script('window.defaultConfirmDialog()')

    assert_selector '[data-ui--dialog-title]', text: pseudo('confirm_dialog.title')
    assert_selector '[data-ui--dialog-message]', text: pseudo('confirm_dialog.message')
    assert_selector 'button[value=confirm]', text: pseudo('confirm_dialog.confirm_label')
    assert_selector 'button[value=cancel]', text: pseudo('confirm_dialog.cancel_label')
  end

  test 'LP3 Select is pseudo-translated, including the count it announces' do
    visit i18n_path(**PSEUDO)
    find('#plural_demo-trigger').click
    assert_selector "#plural_demo-search[placeholder='#{pseudo('select.search_placeholder')}']"
    find('#plural_demo-search').send_keys('q3-')

    assert_selector '#plural_demo-status', text: MARK, visible: :all
    assert_selector '#plural_demo-status', text: '3', visible: :all
  end

  test 'LP4 no chrome surface on a component page is left in plain English' do
    visit select_path(**PSEUDO)

    english = I18n.t('rails_ui_kit.select', locale: :en).values.grep(String)
    english.each do |string|
      %w[aria-label placeholder].each do |attribute|
        assert_not_includes page.html, %(#{attribute}="#{string}"),
                            "#{string.inspect} rendered in English under the pseudo-locale, so it is hardcoded"
      end
    end
  end

  # Expansion. The pseudo-locale lengthens chrome; the docs page's own expansion preview supplies
  # the long *content* — which is the host's, and the case the guarantees are written for.

  test 'LP5 controls hold their token height when the words get longer' do
    visit i18n_path(**PSEUDO)
    expected = page.evaluate_script(
      "getComputedStyle(document.documentElement).getPropertyValue('--control-height').trim()"
    )

    heights = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('#expansion-preview select, #expansion-preview button'))
           .filter((element) => !element.closest('[role="tooltip"], [popover]'))
           .map((element) => Math.round(element.getBoundingClientRect().height))
    JS

    expected_px = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('#expansion-preview select')).height)")
    assert_operator expected_px, :>, 0
    assert_equal [expected_px.round], heights.uniq, "expected every control to stay at #{expected}"
  end

  test 'LP6 the open list wraps a long option instead of hiding it' do
    visit i18n_path(**PSEUDO)
    find('#expansion_demo-combobox').click

    option = find('#expansion_demo-listbox [role=option]', text: 'Zahlungsbedingungen')
    measured = page.evaluate_script(<<~JS, option)
      (() => {
        const span = arguments[0].querySelector('span')
        const row = arguments[0].getBoundingClientRect()
        return { overflow: span.scrollWidth - span.clientWidth, height: row.height }
      })()
    JS

    assert_operator measured['overflow'], :<=, 1, 'the option is clipped, so its text cannot be read at all'
    assert_operator measured['height'], :>, 32, 'a wrapped option should be taller than one row'
  end

  test 'LP7 a long tooltip wraps within its maximum width and stays on screen' do
    visit i18n_path(**PSEUDO)
    find('button', text: 'Hover for a long tooltip').hover

    box = page.evaluate_script(<<~JS)
      (() => {
        const tip = document.querySelector('[data-ui--tooltip-target="content"]')
        const rect = tip.getBoundingClientRect()
        return { width: rect.width, height: rect.height, right: rect.right, left: rect.left }
      })()
    JS

    assert_operator box['width'], :<=, 320
    assert_operator box['height'], :>, 20, 'a tooltip this long has to wrap onto more than one line'
    assert_operator box['left'], :>=, 0
    assert_operator box['right'], :<=, page.evaluate_script('window.innerWidth')
  end
end
