# frozen_string_literal: true

require 'application_system_test_case'

class TurboConfirmTest < ApplicationSystemTestCase
  test "TC1: a link's custom turbo-confirm title doesn't carry over to the next confirm" do
    visit turbo_confirm_path

    click_link 'Publish post'
    assert_selector 'dialog[open]'
    assert_equal 'Publish post?', find('[data-ui--dialog-title]').text
    find("button[value='cancel']").click
    assert_no_selector 'dialog[open]'

    click_link 'Delete item'
    assert_selector 'dialog[open]'
    assert_equal 'Confirmation required', find('[data-ui--dialog-title]').text
    find("button[value='cancel']").click
  end
end
