# frozen_string_literal: true

require 'application_system_test_case'

# The docs site's own frame (layouts/docs.html.erb): sidebar, nav, version badge,
# body. Every other docs system test scopes assert_accessible to `main` because the
# chrome around it used to fail on contrast -- this is the test that couldn't run
# before the chrome was moved onto tokens.
class DocsChromeTest < ApplicationSystemTestCase
  test 'the index page has no accessibility violations, chrome included, in light and dark mode' do
    visit root_path
    disable_transitions
    assert_accessible

    use_dark_mode(true)
    assert_accessible
  end

  test 'a component page has no accessibility violations, chrome included, in light and dark mode' do
    visit button_path
    disable_transitions
    assert_accessible

    use_dark_mode(true)
    assert_accessible
  end

  test 'a utility page has no accessibility violations, chrome included, in light and dark mode' do
    visit dark_mode_path
    disable_transitions
    assert_accessible

    use_dark_mode(true)
    assert_accessible
  end

  test 'the sidebar section heading reaches 4.5:1 in light and dark mode' do
    visit root_path
    disable_transitions

    [false, true].each do |dark|
      use_dark_mode(dark)
      heading = first('aside nav p')
      ratio = contrast_ratio(color_of(:text, heading), color_of(:background, heading))
      assert_operator ratio, :>=, 4.5, "sidebar heading is #{ratio.round(2)}:1 in #{dark ? 'dark' : 'light'} mode"
    end
  end

  test 'the active nav item reaches 4.5:1 in light and dark mode' do
    visit root_path
    disable_transitions

    [false, true].each do |dark|
      use_dark_mode(dark)
      active = find('aside nav a.font-medium')
      ratio = contrast_ratio(color_of(:text, active), color_of(:background, active))
      assert_operator ratio, :>=, 4.5, "active nav item is #{ratio.round(2)}:1 in #{dark ? 'dark' : 'light'} mode"
    end
  end

  test 'an inactive nav item reaches 4.5:1 in light and dark mode' do
    visit root_path
    disable_transitions

    [false, true].each do |dark|
      use_dark_mode(dark)
      inactive = first('aside nav a:not(.font-medium)')
      ratio = contrast_ratio(color_of(:text, inactive), color_of(:background, inactive))
      assert_operator ratio, :>=, 4.5, "inactive nav item is #{ratio.round(2)}:1 in #{dark ? 'dark' : 'light'} mode"
    end
  end

  test 'the version badge reaches 4.5:1 in light and dark mode' do
    visit root_path
    disable_transitions

    [false, true].each do |dark|
      use_dark_mode(dark)
      badge = find('aside span', text: '0.1.0')
      ratio = contrast_ratio(color_of(:text, badge), color_of(:background, badge))
      assert_operator ratio, :>=, 4.5, "version badge is #{ratio.round(2)}:1 in #{dark ? 'dark' : 'light'} mode"
    end
  end

  test 'the body text reaches 4.5:1 against the page background in light and dark mode' do
    visit root_path
    disable_transitions

    [false, true].each do |dark|
      use_dark_mode(dark)
      body = find('body')
      ratio = contrast_ratio(color_of(:text, body), color_of(:background, body))
      assert_operator ratio, :>=, 4.5, "body text is #{ratio.round(2)}:1 in #{dark ? 'dark' : 'light'} mode"
    end
  end
end
