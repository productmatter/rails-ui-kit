# frozen_string_literal: true

require 'application_system_test_case'

# Select's result count, in languages whose plural rules are not English's
# (ui-localization § Behavior, items 6–9). The Internationalization page's plural demo narrows
# to exactly 1, 2, 3, 11 or 100 options, one per category worth exercising, and the count is
# announced in the field's status region — the thing a screen reader actually reads.
class LocalizationPluralTest < ApplicationSystemTestCase
  ID = 'plural_demo'

  # Arabic uses all six CLDR categories, which is why it is the fixture. Its count renders in
  # Latin digits: current CLDR gives "ar" the latn numbering system by default (measured in
  # Chrome 152, 2026-09-14), and a host that wants Arabic-Indic asks for it by tag —
  # I18n.locale = :"ar-u-nu-arab" — which reaches Intl through the same data attribute.
  ARABIC = {
    'zzzz' => 'لا نتائج',        # zero
    'q1-' => 'نتيجة واحدة',      # one
    'q2-' => 'نتيجتان',          # two
    'q3-' => '3 نتائج',          # few
    'q11-' => '11 نتيجة',        # many
    'q100-' => '100 من النتائج'  # other
  }.freeze

  # Search mode opens onto the field in its popup, so the query is typed there
  # (ui-select § Behavior, item 17).
  def filter(query, locale: nil)
    visit locale ? i18n_path(locale: locale) : i18n_path
    page.execute_script("document.getElementById('#{ID}-trigger').scrollIntoView({ block: 'center' })")
    find("##{ID}-trigger").click
    find("##{ID}-search").send_keys(query)
  end

  ARABIC.each do |query, expected|
    test "LP1 Arabic picks the category CLDR chooses for #{query}" do
      filter(query, locale: :ar)

      assert_selector "##{ID}-status", text: expected, exact_text: true, visible: :all
    end
  end

  test 'LP2 French puts 0 in the one category, where English does not' do
    filter('zzzz', locale: :fr)

    assert_selector "##{ID}-status", text: '0 résultat', exact_text: true, visible: :all
  end

  test 'LP3 English is unchanged: one for 1, other for 0 and for many' do
    filter('q1-')
    assert_selector "##{ID}-status", text: '1 result', exact_text: true, visible: :all

    filter('zzzz')
    assert_selector "##{ID}-status", text: '0 results', exact_text: true, visible: :all

    filter('q11-')
    assert_selector "##{ID}-status", text: '11 results', exact_text: true, visible: :all
  end

  test 'LP4 the locale rendered into the markup is what picks the rules, not <html lang>' do
    visit i18n_path(locale: :ar)
    root = find("##{ID}-trigger").find(:xpath, "ancestor::*[@data-slot='select']")

    assert_equal 'ar', root['data-ui--select-locale-value']
    assert_includes root['data-ui--select-results-value'], 'نتيجتان'
  end

  test 'LP5 a locale with no plural map of its own still announces, through the fallback' do
    filter('q3-', locale: :fr)

    assert_selector "##{ID}-status", text: '3 résultats', exact_text: true, visible: :all
  end
end
