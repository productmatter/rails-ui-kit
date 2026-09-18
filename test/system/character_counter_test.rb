# frozen_string_literal: true

require 'application_system_test_case'

# The counter agrees with the server, never validates, and rides Field's existing swap
# (ui-character-counter § Business rules, rules 1-3; § Acceptance checks).
class CharacterCounterTest < ApplicationSystemTestCase
  setup do
    visit character_counter_path
    disable_transitions
  end

  def textarea
    find('#demo_bio')
  end

  def count_span
    find('#demo_bio-description [data-ui--character-count-target="count"]', visible: :all)
  end

  def status_region
    find('#demo_bio-status', visible: :all)
  end

  # ax_node (Chrome's accessibility tree for one element) comes from ApplicationSystemTestCase's
  # BrowserHelpers.
  def ax(selector, key)
    ax_node(selector)&.dig(key, 'value')
  end

  test 'CC1: typing updates the visible count' do
    assert_equal '0 / 60', count_span.text
    textarea.send_keys('hello')
    assert_equal '5 / 60', count_span.text
  end

  test 'CC2: a paste past the limit turns the count destructive with data-over, and the control stays valid' do
    textarea.send_keys('x' * 65)

    span = count_span
    assert_equal '65 / 60', span.text
    assert_equal 'true', span['data-over']
    assert_nil textarea['aria-invalid']
    assert_no_selector '#demo_bio[aria-invalid]'
  end

  test 'CC3: the status region announces once at each threshold and nothing between' do
    assert_equal '', status_region.text(:all)

    # Ten percent of 60, rounded down, is 6: 54 characters leaves exactly 6 remaining -- the low
    # band, crossed for the first time.
    textarea.send_keys('x' * 54)
    assert_selector '#demo_bio-status', text: 'remaining', visible: :all

    # One more character stays inside the low band: no further announcement.
    low_message = status_region.text(:all)
    textarea.send_keys('y')
    assert_equal low_message, status_region.text(:all)

    # Ten more characters (65 total) cross over the limit.
    textarea.send_keys('z' * 10)
    assert_selector '#demo_bio-status', text: 'over the limit', visible: :all

    # Still over after one deletion: no further announcement.
    over_message = status_region.text(:all)
    textarea.send_keys(:backspace)
    assert_equal over_message, status_region.text(:all)

    # Fourteen more deletions (from 64 to 50) cross back under the limit, comfortably out of the
    # low band too -- the third and last moment.
    14.times { textarea.send_keys(:backspace) }
    assert_selector '#demo_bio-status', text: 'remaining', visible: :all
    assert_not_includes status_region.text(:all), 'over the limit'
  end

  test 'CC4: a form reset recounts' do
    field = find('#character-counter-swap-demo textarea')
    count = find('#character-counter-swap-demo [data-ui--character-count-target="count"]')
    field.send_keys('hello')
    assert_equal '5 / 40', count.text

    page.execute_script("document.getElementById('character-counter-swap-demo').reset()")
    assert_equal '0 / 40', count.text
  end

  test 'CC5: the computed accessible description carries the help text before the count' do
    described = ax('#demo_bio', 'description').to_s
    assert_operator described.index('sentences'), :<, described.index('60'),
                    "expected the help text before the count in #{described.inspect}"
  end

  test 'the accessibility preview passes an audit valid, invalid and over the limit, in light and dark mode' do
    find('#character-counter-swap-submit').click
    assert_selector '[data-slot=field-error]'

    %w[light dark].each do |mode|
      use_dark_mode(mode == 'dark')
      assert_accessible(within: '#character-counter-preview')
      assert_accessible(within: '#character-counter-over-preview')
      assert_accessible(within: '#character-counter-form-preview')
    end
  end

  test 'an invalid field hides the line, and a valid one brings it back with the current count' do
    find('#character-counter-swap-demo textarea').set('')
    find('#character-counter-swap-submit').click

    assert_selector '[data-slot=field-error]', text: 'blank'
    assert_no_selector "#character-counter-swap-demo [data-slot='field-description']:not([hidden])", visible: :all

    find('#character-counter-swap-demo textarea').set('back to valid')
    find('#character-counter-swap-submit').click

    assert_selector '#character-counter-swap-result'
    assert_selector "#character-counter-swap-demo [data-slot='field-description']:not([hidden]) " \
                    "[data-ui--character-count-target='count']", text: '13 / 40'
  end

  # A value with line breaks agrees with what the server receives (§ Behavior, item 7): the
  # browser submits CRLF for every LF the textarea's own value carries, and that is what
  # `validates length:` -- and the counter -- both count.
  test 'the docs demo agrees with the server when line breaks are posted' do
    field = find('#character-counter-swap-demo textarea')
    field.set('')
    field.send_keys('line one', :enter, 'line two')

    shown = find('#character-counter-swap-demo [data-ui--character-count-target="count"]').text.split(' / ').first.to_i

    find('#character-counter-swap-submit').click
    assert_selector '#character-counter-swap-result'

    received = find('#character-counter-received-length').text.to_i
    assert_equal shown, received
  end
end

# With JavaScript off, the count is exactly what the server rendered, and simply does not
# update -- the strongest possible form of "JavaScript never ran" (ui-character-counter
# § Behavior, item 8, mirroring ui-select's own no-JavaScript check).
class CharacterCounterNoJavascriptTest < ApplicationSystemTestCase
  driven_by :rack_test

  setup { visit character_counter_path }

  test 'the line shows the server-rendered count with no controller to update it' do
    assert_selector '#demo_bio-description', text: '0 / 60'
    assert_selector "#character-counter-swap-demo [data-ui--character-count-target='count']", text: '0 / 40', visible: :all
  end
end
