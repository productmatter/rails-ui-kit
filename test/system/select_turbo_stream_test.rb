# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'select_helpers'

# Options change by re-rendering the component, never by patching options (ui-select § Behavior,
# items 33 to 35). Each of these replaces a Select the way Turbo does and then uses what it left
# behind, because markup that renders is not the same as markup that works.
class SelectTurboStreamTest < ApplicationSystemTestCase
  include SelectHelpers

  ID = 'demo_timezone'

  setup do
    visit select_path
    disable_transitions
  end

  def stream(html)
    page.execute_script('Turbo.renderStreamMessage(arguments[0])', html)
  end

  # The component's own markup for a two-option Select, rendered the way a Turbo Stream would
  # carry it -- straight from the server, not assembled here.
  def replacement(selected: 'oslo')
    page.evaluate_script(<<~JS, selected)
      (() => {
        const source = document.getElementById(arguments[0] === 'oslo' ? '#{ID}-option-14' : '#{ID}-option-19')
        return source.dataset.value
      })()
    JS
  end

  test 'ST1: a Turbo Stream replacing the root leaves a working Select on the new value' do
    root = page.evaluate_script("document.getElementById('#{ID}').closest('[data-slot=select]').outerHTML")
    swapped = root.sub('value="oslo"', 'value="oslo" selected="selected"')
    assert_not_equal root, swapped, 'the replacement markup is identical to what is already there'

    page.execute_script("document.getElementById('#{ID}').closest('[data-slot=select]').id = 'swap-target'")
    stream(%(<turbo-stream action="replace" target="swap-target"><template>#{swapped}</template></turbo-stream>))

    assert_selector "##{ID}-combobox", text: 'Oslo'
    assert_equal 'oslo', select_value(ID)

    focus_combobox(ID)
    press :enter
    assert_popup ID, 'open'
    assert_active ID, 14, 'the replaced Select did not re-derive its active option'
    press :end
    press :enter
    assert_equal 'tokyo', select_value(ID)
  end

  test 'ST2: a frame swap replaces the Select inside it and the new one works' do
    within '#select-round-trip-preview' do
      find('#trip_city-combobox').click
      assert_popup 'trip_city', 'open'
      find('#trip_city-option-1').click
      assert_equal 'berlin', select_value('trip_city')
      find('#select-round-trip-submit').click
      assert_selector '#select-round-trip-result'
    end

    # The frame's contents are a fresh render from the server; the Select in it has to connect
    # from its own markup.
    assert_equal 'berlin', select_value('trip_city')
    focus_combobox('trip_city')
    press :enter
    assert_popup 'trip_city', 'open'
    press :end
    press :enter
    assert_equal 'tokyo', select_value('trip_city')
  end

  test 'ST3: a morphing refresh that changes the selection leaves no stale label' do
    assert_equal 'London', combobox_label(ID)

    morphed = page.evaluate_script(<<~JS, ID)
      (() => {
        const root = document.getElementById(arguments[0]).closest('[data-slot=select]')
        const next = root.cloneNode(true)
        const select = next.querySelector('select')
        select.querySelector('option[value="london"]').removeAttribute('selected')
        select.querySelector('option[value="paris"]').setAttribute('selected', 'selected')
        window.__morphSource = next
        return typeof Turbo.morphElements === 'function'
      })()
    JS
    skip 'this Turbo build does not expose morphElements' unless morphed

    page.execute_script(<<~JS, ID)
      const root = document.getElementById(arguments[0]).closest('[data-slot=select]')
      Turbo.morphElements(root, window.__morphSource)
    JS

    assert_selector "##{ID}-combobox", text: 'Paris'
    assert_equal 'paris', select_value(ID)
    assert_selector "##{ID}-option-15[data-selected='true']", visible: :all
  end

  # ST3's source is a clone of the live, enhanced element, so it never rewrites what enhancement
  # added. A real refresh morphs towards the server's markup, where the combobox is `hidden` and
  # the root has no data-enhanced -- as a 422 on a page that refreshes with morph does. Found by
  # the stress page (docs/specs/ui-stress-page/status.md).
  test "ST5: a morph towards the server's own markup leaves the Select enhanced and working" do
    page.execute_script(<<~JS, ID)
      window.__morphed = false
      fetch(location.href).then((response) => response.text()).then((html) => {
        const server = new DOMParser().parseFromString(html, 'text/html').getElementById(arguments[0]).closest('[data-slot=select]')
        Turbo.morphElements(document.getElementById(arguments[0]).closest('[data-slot=select]'), server)
        window.__morphed = true
      })
    JS
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.02 until page.evaluate_script('window.__morphed') }

    assert_selector "##{ID}-combobox", text: 'London'
    assert_equal 'true', find("##{ID}", visible: :all)['aria-hidden']
    focus_combobox(ID)
    press :enter
    assert_popup ID, 'open'
    press :end
    press :enter
    assert_equal 'tokyo', select_value(ID)
  end

  test 'ST4: a Select removed with its frame leaves no listener or observer behind' do
    page.execute_script(<<~JS)
      window.__probe = { document: 0 }
      const add = document.addEventListener.bind(document)
      const remove = document.removeEventListener.bind(document)
      document.addEventListener = (...args) => { window.__probe.document += 1; return add(...args) }
      document.removeEventListener = (...args) => { window.__probe.document -= 1; return remove(...args) }
    JS

    stream(<<~HTML)
      <turbo-stream action="update" target="select-round-trip"><template>
        <p id="reloaded-frame">The Select that was here has gone.</p>
      </template></turbo-stream>
    HTML
    assert_no_selector '#trip_city-combobox'
    assert_selector '#reloaded-frame'

    # The probe is installed after everything connected, so only the removals it makes are
    # counted: a Select that released nothing on its way out would leave this at zero.
    assert_operator page.evaluate_script('window.__probe.document'), :<, 0,
                    'the Select released no document listener when its frame was replaced'
  end
end
