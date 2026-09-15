# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'confirm_dialog_helpers'

# The confirm variant, the labels and the title reach the shared dialog identically from a Ruby
# render, window.defaultConfirmDialog and a Turbo data attribute (docs/specs/ui-confirm-dialog,
# § Behavior, items 2 to 6).
#
# "The primary variant's exact classes" is checked against what Ui::ButtonComponent rendered into
# the dialog's own template for that variant, never against a class list written here: the point
# is that JavaScript swaps server-rendered markup in rather than composing classes.
class ConfirmDialogVariantTest < ApplicationSystemTestCase
  include ConfirmDialogHelpers

  test 'CV1: a dialog rendered with confirm_variant: :default shows a primary confirm' do
    visit confirm_dialog_path
    open_custom_confirm('#archive-confirm')

    assert_equal 'default', confirm_button['data-ui--dialog-confirm-variant']
    assert_equal variant_classes('archive-confirm', 'default'), classes_of(confirm_button)
    assert_equal 'Archive', confirm_button.text.strip
    cancel_confirm
  end

  test 'CV2: defaultConfirmDialog carries the variant, the labels and the title, and resets after' do
    visit confirm_dialog_path
    open_default_confirm(title: 'Publish this post?', message: 'Readers will see it immediately.',
                         confirm_label: 'Publish', cancel_label: 'Not yet', confirm_variant: 'default')

    assert_equal 'Publish this post?', find('#default-confirm [data-ui--dialog-title]').text
    assert_equal 'Readers will see it immediately.', find('#default-confirm [data-ui--dialog-message]').text
    assert_equal 'Publish', confirm_button.text.strip
    assert_equal 'Not yet', cancel_button.text.strip
    assert_equal variant_classes('default-confirm', 'default'), classes_of(confirm_button)
    cancel_confirm

    open_default_confirm('Delete this item?')
    assert_destructive_default
    cancel_confirm
  end

  test 'CV3: a Turbo confirmation carries them from a link, a submit button and a form' do
    visit turbo_confirm_path

    click_link 'Publish post'
    assert_confirm_open
    assert_equal 'Publish this post?', find('#default-confirm [data-ui--dialog-title]').text
    assert_equal 'Publish', confirm_button.text.strip
    assert_equal variant_classes('default-confirm', 'default'), classes_of(confirm_button)
    cancel_confirm

    find('#archive-submit').click
    assert_confirm_open
    assert_equal 'Archive this project?', find('#default-confirm [data-ui--dialog-title]').text
    assert_equal 'Archive', confirm_button.text.strip
    assert_equal 'Keep it', cancel_button.text.strip, 'the cancel label on the form was not read'
    assert_equal variant_classes('default-confirm', 'secondary'), classes_of(confirm_button)
    cancel_confirm

    # The same attribute on the form rather than the submitter: the lookup order is submitter,
    # then form, then the link Turbo built the form from.
    move_variant_to_form
    find('#archive-submit').click
    assert_confirm_open
    assert_equal variant_classes('default-confirm', 'ghost'), classes_of(confirm_button)
    cancel_confirm
  end

  private

  def move_variant_to_form
    page.execute_script(<<~JS)
      const submitter = document.getElementById('archive-submit')
      submitter.removeAttribute('data-turbo-confirm-confirm-variant')
      submitter.form.setAttribute('data-turbo-confirm-confirm-variant', 'ghost')
    JS
  end
end
