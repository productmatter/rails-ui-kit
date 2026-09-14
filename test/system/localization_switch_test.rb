# frozen_string_literal: true

require 'application_system_test_case'

# Every chrome surface, in a second language, in a real browser: the strings a component
# renders on the server and the strings its Stimulus controller writes at runtime
# (ui-localization § Acceptance checks). The docs app takes ?locale=, and the fr fixture in
# test/fixtures/locales is on the load path for this process.
class LocalizationSwitchTest < ApplicationSystemTestCase
  FRENCH = { locale: :fr }.freeze

  test 'LS1 the document reports the locale it rendered in' do
    visit toast_path(**FRENCH)

    assert_equal 'fr', page.find('html')[:lang]
  end

  # The container's per-type <template>s are server-rendered markup, inert in the document, so
  # they are read from the page's HTML rather than queried as elements.
  test 'LS2 the toast templates the server rendered name their close button in French' do
    visit toast_path(**FRENCH)

    assert_includes page.html, 'aria-label="Fermer la notification"'
    assert_not_includes page.html, 'aria-label="Close notification"'
  end

  test 'LS3 a toast JavaScript creates takes its default title and close name from the container' do
    visit toast_path(**FRENCH)
    page.execute_script('window.triggerToast("info")')

    toast = find("[data-ui--toast-target='title']", text: 'Avis')
    assert toast
    assert_selector "[data-controller='ui--toast'] button[aria-label='Fermer la notification']"
  end

  test 'LS4 the default confirm dialog opens in French, title and buttons' do
    visit confirm_dialog_path(**FRENCH)
    page.execute_script('window.defaultConfirmDialog()')

    assert_selector '[data-ui--dialog-title]', text: 'Confirmation requise'
    assert_selector 'button[value=confirm]', text: 'Confirmer'
    assert_selector 'button[value=cancel]', text: 'Annuler'
  end

  test 'LS5 Select says "no results" and counts results in French' do
    visit select_path(**FRENCH)

    page.execute_script("document.getElementById('demo_city-combobox').focus()")
    find('#demo_city-combobox').send_keys('zzzzz')
    assert_selector '[data-ui--select-target="empty"]', text: 'Aucun résultat'
    # French puts 0 in the `one` category, so the singular form is the right one here.
    assert_selector '#demo_city-status', text: '0 résultat', exact_text: true, visible: :all

    assert_selector "button[aria-label='Afficher les options']", visible: :all
  end

  test 'LS6 the same page in English is English' do
    visit toast_path

    assert_equal 'en', page.find('html')[:lang]
    assert_includes page.html, 'aria-label="Close notification"'
  end
end
