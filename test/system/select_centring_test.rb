# frozen_string_literal: true

require 'application_system_test_case'

# A native <select> ignores `flex items-center`, so its text sits wherever its vertical padding
# leaves it. The kit set none, and a host stylesheet that pads every select -- @tailwindcss/forms
# gives each one 8px top and bottom -- pushed the text down inside the fixed step height until it
# clipped at the smaller steps. The box now states `py-0` itself. The Select page's centring
# preview loads that same padding into the base layer, so these read the control as a host
# running the plugin would render it.
class SelectCentringTest < ApplicationSystemTestCase
  PREVIEW = '#select-centring-preview'

  setup { visit select_path }

  # Every probe reads the control's own computed box: its padding, its height, its line height.
  def boxes(tag)
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('#{PREVIEW} #{tag}')).map((element) => {
        const style = getComputedStyle(element)
        return { top: parseFloat(style.paddingTop), bottom: parseFloat(style.paddingBottom),
                 height: element.getBoundingClientRect().height, line: parseFloat(style.lineHeight),
                 border: parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth) }
      })
    JS
  end

  test "SC1: the preview's host rule is live, so the checks below are measuring something" do
    padding = page.evaluate_script(<<~JS)
      (() => {
        const bare = document.createElement('select')
        document.querySelector('#{PREVIEW}').append(bare)
        const value = parseFloat(getComputedStyle(bare).paddingTop)
        bare.remove()
        return value
      })()
    JS

    assert_equal 8.0, padding, 'a bare select in the preview should take the host padding'
  end

  test 'SC2: a native select has no vertical padding at any size, whatever the host pads' do
    selects = boxes('select')
    assert_equal 6, selects.size

    selects.each_with_index do |box, index|
      assert_equal 0.0, box['top'], "select #{index}: padding-top"
      assert_equal 0.0, box['bottom'], "select #{index}: padding-bottom"
      assert_operator box['line'], :<=, box['height'] - box['border'],
                      "select #{index}: its line box must fit inside the control"
    end
  end

  test 'SC3: an Input has no vertical padding at any size either' do
    inputs = boxes('input')
    assert_equal 6, inputs.size

    inputs.each_with_index do |box, index|
      assert_equal 0.0, box['top'], "input #{index}: padding-top"
      assert_equal 0.0, box['bottom'], "input #{index}: padding-bottom"
    end
  end
end
