# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'confirm_dialog_helpers'

class TurboConfirmTest < ApplicationSystemTestCase
  include ConfirmDialogHelpers

  test "TC1: a link's custom turbo-confirm title doesn't carry over to the next confirm" do
    visit turbo_confirm_path

    click_link 'Publish post'
    assert_selector 'dialog[open]'
    assert_equal 'Publish this post?', find('[data-ui--dialog-title]').text
    find("button[value='cancel']").click
    assert_no_selector 'dialog[open]'

    click_link 'Delete item'
    assert_selector 'dialog[open]'
    assert_equal 'Confirmation required', find('[data-ui--dialog-title]').text
    find("button[value='cancel']").click
  end

  # The same leak TC1 guards for the title, for every other part a confirmation can set: a
  # data-turbo-confirm that names no variant gets the dialog's rendered default, destructive,
  # even straight after one that asked for the primary button (ui-confirm-dialog rule 3 and 4).
  test 'TC2: a Turbo confirmation with no variant is destructive, after one that set default' do
    visit turbo_confirm_path

    click_link 'Publish post'
    assert_confirm_open
    assert_equal variant_classes('default-confirm', 'default'), classes_of(confirm_button)
    cancel_confirm

    click_link 'Delete item'
    assert_confirm_open
    assert_destructive_default
    cancel_confirm
  end

  test 'TC3: every part resets from defaultConfirmDialog too' do
    visit turbo_confirm_path
    open_default_confirm(title: 'Publish this post?', confirm_label: 'Publish', cancel_label: 'Not yet',
                         confirm_variant: 'secondary', message: 'Readers will see it immediately.')
    assert_equal 'secondary', confirm_button['data-ui--dialog-confirm-variant']
    cancel_confirm

    open_default_confirm('Delete this item?')
    assert_destructive_default
    assert_equal I18n.t('rails_ui_kit.confirm_dialog.title'), find('#default-confirm [data-ui--dialog-title]').text
    cancel_confirm
  end
end
