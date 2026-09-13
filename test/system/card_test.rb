# frozen_string_literal: true

require 'application_system_test_case'

class CardTest < ApplicationSystemTestCase
  LONG_EMAIL = 'accounts-payable.department.notifications@really-long-company-domain.example.com'

  setup do
    visit card_path
    disable_transitions
  end

  # CARD1
  test 'a long unbroken title never pushes the action outside a narrow card' do
    card = preview_card('With a header action')
    page.execute_script(<<~JS, card, LONG_EMAIL)
      arguments[0].style.width = '280px'
      arguments[0].querySelector('[data-slot=card-title]').textContent = arguments[1]
    JS

    card_rect = rect(card)
    action_rect = rect(card.find('[data-slot=card-action] [data-slot=button]'))
    title_rect = rect(card.find('[data-slot=card-title]'))

    assert_operator action_rect['right'], :<=, card_rect['right'], 'the action spills out of the card'
    assert_operator title_rect['right'], :<=, action_rect['left'], 'the title runs under the action'
    assert_operator title_rect['width'], :>, 0
  end

  test 'a long unbroken title wraps inside a card with no action' do
    card = preview_card('Plain')
    page.execute_script(<<~JS, card, LONG_EMAIL)
      arguments[0].style.width = '240px'
      arguments[0].querySelector('[data-slot=card-title]').textContent = arguments[1]
    JS

    assert_operator rect(card.find('[data-slot=card-title]'))['right'], :<=, rect(card)['right']
  end

  # CARD3
  test 'a title-only header is exactly as tall as its title' do
    card = preview_card('Plain')
    page.execute_script("arguments[0].querySelector('[data-slot=card-description]').remove()", card)

    assert_in_delta rect(card.find('[data-slot=card-title]'))['height'], rect(card.find('[data-slot=card-header]'))['height'], 0.5
  end

  # CARD4
  test 'an action-only header is tall enough to contain its action' do
    card = preview_card('With a header action')
    page.execute_script(<<~JS, card)
      arguments[0].querySelectorAll('[data-slot=card-title], [data-slot=card-description]').forEach((node) => node.remove())
    JS

    header_rect = rect(card.find('[data-slot=card-header]'))
    button_rect = rect(card.find('[data-slot=card-action] [data-slot=button]'))

    assert_operator button_rect['height'], :>, 0
    assert_operator button_rect['top'], :>=, header_rect['top'] - 0.5
    assert_operator button_rect['bottom'], :<=, header_rect['bottom'] + 0.5
  end

  test 'the card previews pass an accessibility audit in light and dark mode' do
    assert_accessible(within: '#card-preview')

    use_dark_mode(true)
    assert_accessible(within: '#card-preview')
  end

  private

  def preview_card(heading)
    find_by_id('card-preview').find('h2', exact_text: heading).find(:xpath, 'following-sibling::div[1]').find('[data-slot=card]')
  end

  def rect(element)
    page.evaluate_script(<<~JS, element)
      (() => { const r = arguments[0].getBoundingClientRect(); return { top: r.top, right: r.right, bottom: r.bottom, left: r.left, width: r.width, height: r.height } })()
    JS
  end
end
