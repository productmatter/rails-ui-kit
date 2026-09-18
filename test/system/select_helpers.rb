# frozen_string_literal: true

# Shared probes for the Ui::SelectComponent browser tests. Not a test file and not a second
# harness: ApplicationSystemTestCase stays the base class, and these are the few Select-specific
# reads that would otherwise be copied into every file. `press`, `click_at`, `focused_id`,
# `state_of` and `rect_of` come from ApplicationSystemTestCase's BrowserHelpers.
module SelectHelpers
  TIMEZONES = ['Auckland', 'Berlin', 'Bogotá', 'Cairo', 'Chicago', 'Delhi', 'Dublin', 'Helsinki', 'Lagos', 'Lisbon', 'London', 'Madrid', 'Nairobi', 'New York', 'Oslo', 'Paris', 'São Paulo',
               'Singapore', 'Sydney', 'Tokyo'].freeze

  # A real chord -- Alt held down while the other key is pressed -- which send_keys(:alt, :x)
  # is not: that presses and releases Alt first.
  def press_with(modifier, key)
    page.driver.browser.action.key_down(modifier).send_keys(key).key_up(modifier).perform
  end

  def option_value(id, index)
    find("##{id}-option-#{index}", visible: :all)['data-value']
  end

  # The element that owns the listbox, whichever mode the Select is in: the combobox in
  # select-only mode, the trigger button in search mode. It is ui--overlay's trigger either way,
  # and it is what carries aria-expanded, aria-required and the aria that describes the control.
  def control_selector(id)
    "[data-ui--overlay-target='trigger'][aria-controls='#{id}-listbox']"
  end

  # The element aria-activedescendant lives on: select-only mode's combobox, or search mode's
  # field in the popup. Visual focus is read from here, never from the control.
  def active_selector(id)
    "[data-ui--roving-focus-target='input'][aria-controls='#{id}-listbox']"
  end

  def combobox(id)
    find("##{id}-combobox")
  end

  def control(id)
    find(control_selector(id))
  end

  def active_id(id)
    find(active_selector(id), visible: :all)['aria-activedescendant']
  end

  def focus_combobox(id)
    element = combobox(id)
    page.execute_script('arguments[0].focus()', element)
    assert_equal "#{id}-combobox", focused_id
    element
  end

  # Search mode's trigger, focused the way the browser would leave it: DOM focus is on the trigger
  # whenever the popup is closed.
  def focus_trigger(id)
    element = find("##{id}-trigger")
    page.execute_script('arguments[0].focus()', element)
    assert_equal "#{id}-trigger", focused_id
    element
  end

  def search_value(id)
    page.evaluate_script("document.getElementById('#{id}-search').value")
  end

  def assert_focus_on_trigger(id, message = 'DOM focus is not on the trigger')
    assert_equal "#{id}-trigger", focused_id, message
  end

  def assert_focus_on_search(id, message = 'DOM focus is not in the search field')
    assert_equal "#{id}-search", focused_id, message
  end

  # The value the form would post: the select's, never the label's.
  def select_value(id)
    page.evaluate_script('document.getElementById(arguments[0]).value', id)
  end

  # What the control shows, in either mode: the selected option's label, or the prompt. In
  # select-only mode the control is the combobox, so the two names read the same element.
  def control_label(id)
    control(id).text.strip
  end
  alias combobox_label control_label

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
    assert page.has_css?("#{control_selector(id)}[aria-expanded='#{expected == 'open'}']"),
           "expected #{id} to be #{expected}, but aria-expanded says otherwise"
  end

  # Visual focus: the option aria-activedescendant names, by its index in the listbox. Waits the
  # way any Capybara matcher does, and says what it wanted when it gives up.
  def assert_active(id, index, message = nil)
    selector = "#{active_selector(id)}[aria-activedescendant='#{id}-option-#{index}']"
    assert page.has_css?(selector, visible: :all),
           message || "expected the active option to be #{id}-option-#{index}, got #{active_id(id).inspect}"
  end

  def assert_no_active(id, message = nil)
    assert page.has_no_css?("#{active_selector(id)}[aria-activedescendant]", visible: :all),
           message || "expected no active option, got #{active_id(id).inspect}"
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

  # A rect that is actually laid out. Every geometry assertion goes through this, so a hidden or
  # zero-size element can never make a comparison pass by having nothing to compare.
  def laid_out_rect(selector)
    rect = rect_of(selector)
    assert_operator rect['width'], :>, 0, "#{selector} has no width, so its geometry proves nothing"
    assert_operator rect['height'], :>, 0, "#{selector} has no height, so its geometry proves nothing"
    rect
  end
end
