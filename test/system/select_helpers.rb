# frozen_string_literal: true

# Shared probes for the Ui::SelectComponent browser tests. Not a test file and not a second
# harness: ApplicationSystemTestCase stays the base class, and these are the few Select-specific
# reads that would otherwise be copied into every file.
module SelectHelpers
  TIMEZONES = ['Auckland', 'Berlin', 'Bogotá', 'Cairo', 'Chicago', 'Delhi', 'Dublin', 'Helsinki', 'Lagos', 'Lisbon', 'London', 'Madrid', 'Nairobi', 'New York', 'Oslo', 'Paris', 'São Paulo',
               'Singapore', 'Sydney', 'Tokyo'].freeze

  # Sends keys to whatever currently has focus, the way a keyboard does -- unlike Capybara's
  # element.send_keys, which focuses the element it is called on first.
  def press(*keys)
    page.driver.browser.action.send_keys(*keys).perform
  end

  # A real chord -- Alt held down while the other key is pressed -- which send_keys(:alt, :x)
  # is not: that presses and releases Alt first.
  def press_with(modifier, key)
    page.driver.browser.action.key_down(modifier).send_keys(key).key_up(modifier).perform
  end

  # A real pointer press at a point on the page, which is the only way to press something the
  # page has told the pointer to ignore.
  def click_at(point_x, point_y)
    page.driver.browser.action.move_to_location(point_x.to_i, point_y.to_i).click.perform
  end

  def option_value(id, index)
    find("##{id}-option-#{index}", visible: :all)['data-value']
  end

  def combobox(id)
    find("##{id}-combobox")
  end

  def focus_combobox(id)
    element = combobox(id)
    page.execute_script('arguments[0].focus()', element)
    assert_equal "#{id}-combobox", focused_id
    element
  end

  def focused_id
    page.evaluate_script('document.activeElement && document.activeElement.id')
  end

  # The value the form would post: the select's, never the label's.
  def select_value(id)
    page.evaluate_script('document.getElementById(arguments[0]).value', id)
  end

  def combobox_label(id)
    combobox(id).text.strip
  end

  def state_of(selector)
    page.evaluate_script('document.querySelector(arguments[0]).dataset.state', selector)
  end

  # Waits, the way any Capybara assertion waits, for the popup to reach `expected` with its
  # transitions finished: data-state="open" is set as the entry transition starts.
  def assert_popup(id, expected)
    settled = <<~JS
      (() => {
        const element = document.getElementById(arguments[0])
        const running = element.getAnimations().some((animation) => !['finished', 'idle'].includes(animation.playState))
        return element.dataset.state === arguments[1] && !running
      })()
    JS
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.02 until page.evaluate_script(settled, "#{id}-popup", expected)
    end
    assert page.has_css?("##{id}-combobox[aria-expanded='#{expected == 'open'}']"),
           "expected #{id} to be #{expected}, but aria-expanded says otherwise"
  end

  # Visual focus: the option aria-activedescendant names, by its index in the listbox. Waits the
  # way any Capybara matcher does, and says what it wanted when it gives up.
  def assert_active(id, index, message = nil)
    selector = "##{id}-combobox[aria-activedescendant='#{id}-option-#{index}']"
    assert page.has_css?(selector), message || "expected the active option to be #{id}-option-#{index}, " \
                                               "got #{combobox(id)['aria-activedescendant'].inspect}"
  end

  def assert_no_active(id)
    assert_no_selector "##{id}-combobox[aria-activedescendant]"
  end

  def assert_focus_on_combobox(id, message = 'DOM focus left the combobox')
    assert_equal "#{id}-combobox", focused_id, message
  end

  # input and change, recorded from the select itself -- the only place they may come from. One
  # recorder per page, however often this is called, so a repeated call can't double-count.
  def record_events(id)
    page.execute_script(<<~JS, id)
      window.__selectEvents = []
      window.__selectRecordId = arguments[0]
      if (!window.__selectRecorder) {
        window.__selectRecorder = (event) => {
          if (event.target.id !== window.__selectRecordId) return
          window.__selectEvents.push(`${event.type}:${event.target.value}:${event.bubbles}`)
        }
        for (const type of ['input', 'change']) document.addEventListener(type, window.__selectRecorder, true)
      }
    JS
  end

  def recorded_events
    page.evaluate_script('window.__selectEvents')
  end

  def rect_of(selector)
    page.evaluate_script('document.querySelector(arguments[0]).getBoundingClientRect().toJSON()', selector)
  end

  # A rect that is actually laid out. Every geometry assertion goes through this, so a hidden or
  # zero-size element can never make a comparison pass by having nothing to compare.
  def laid_out_rect(selector)
    rect = rect_of(selector)
    assert_operator rect['width'], :>, 0, "#{selector} has no width, so its geometry proves nothing"
    assert_operator rect['height'], :>, 0, "#{selector} has no height, so its geometry proves nothing"
    rect
  end
end
