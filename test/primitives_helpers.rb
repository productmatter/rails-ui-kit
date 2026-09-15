# frozen_string_literal: true

# Browser helpers shared by the ui--anchor and ui--roving-focus system tests. Required by those
# test files only, never from test_helper.rb -- it must not pull Capybara into the unit lane.
# `press` and `focused?` come from ApplicationSystemTestCase's BrowserHelpers.
module PrimitivesHelpers
  def tab_to(element, limit: 80)
    limit.times do
      break if focused?(element)

      press :tab
    end
    element
  end

  def rect(element)
    page.evaluate_script('arguments[0].getBoundingClientRect().toJSON()', element)
  end

  def offset_width(element)
    page.evaluate_script('arguments[0].offsetWidth', element)
  end

  # Positioning is asynchronous and lands a frame or two after the scroll, resize or DOM change
  # that caused it, so geometry assertions retry the way Capybara's own matchers do.
  def eventually(timeout: 3)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    begin
      yield
    rescue Minitest::Assertion
      raise if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
      retry
    end
  end

  # The items of a roving group that are in the tab sequence. Exactly one, always.
  def tabbable_items(scope)
    within(scope) { all('[data-ui--roving-focus-target="item"][tabindex="0"]', visible: :all) }
  end

  def assert_single_tab_stop(scope, expected_id = nil)
    items = tabbable_items(scope)
    assert_equal 1, items.size, "expected exactly one tabbable item in #{scope}, found #{items.map { |i| i[:id] }.inspect}"
    assert_equal expected_id, items.first[:id] if expected_id
  end

  def assert_focused_item(text)
    assert_selector '[data-ui--roving-focus-target="item"]:focus', text: text, exact_text: true
  end
end
