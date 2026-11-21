# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'modal_turbo_helpers'

# Ui::ModalContentComponent in a real browser (docs/specs/ui-modal-content): the layout contract
# it promises in a full-height pane, and the model it exists for -- later responses replace the
# content's frame and never re-mount the modal.
class ModalContentTest < ApplicationSystemTestCase
  include ModalTurboHelpers

  ACTIVITY = 'turbo-frame#project_activity_modal'

  # The activity modal is position: :right, an h-dvh dialog that scrolls itself. Transitions are
  # off so the slide-in is not what gets measured.
  def open_side_panel
    disable_transitions
    open_activity_modal(1)
  end

  # The dialog's padding box (inside its border) beside the content's three parts, as laid out now.
  PANEL_METRICS = <<~JS
    ((selector) => {
      const dialog = document.querySelector(selector)
      const box = (part) => dialog.querySelector(part).getBoundingClientRect().toJSON()
      const style = getComputedStyle(dialog)
      const rect = dialog.getBoundingClientRect()
      return {
        top: rect.top,
        bottom: rect.bottom,
        viewport: innerHeight,
        inner_top: rect.top + parseFloat(style.borderTopWidth),
        inner_bottom: rect.bottom - parseFloat(style.borderBottomWidth),
        client_height: dialog.clientHeight,
        scroll_height: dialog.scrollHeight,
        content: box('[data-slot=modal-content]'),
        header: box('[data-slot=modal-content-header]'),
        footer: box('[data-slot=modal-content-footer]')
      }
    })(arguments[0])
  JS

  def panel_metrics(dialog = "#{ACTIVITY} dialog")
    page.evaluate_script(PANEL_METRICS, dialog)
  end

  def scroll_to_end(dialog = "#{ACTIVITY} dialog")
    page.execute_script('const d = document.querySelector(arguments[0]); d.scrollTop = d.scrollHeight', dialog)
  end

  # A modal in the given position whose content is far taller than any viewport.
  LONG_MODAL = <<~ERB
    <%= render Ui::ModalComponent.new(position: position, aria: { labelledby: "position_probe_title" }) do %>
      <%= render Ui::ModalContentComponent.new(id: "position_probe", title: "Position probe") do |modal| %>
        <% 150.times do |line| %><p class="text-sm">Line <%= line %></p><% end %>
        <% modal.with_footer do %><button type="button">Done</button><% end %>
      <% end %>
    <% end %>
  ERB

  def open_long_modal(position)
    html = ApplicationController.render(inline: LONG_MODAL, locals: { position: position })
    stream(%(<turbo-stream action="update" target="modal"><template>#{html}</template></turbo-stream>))
    assert_modal_open(content_frame: 'position_probe')
  end

  def assert_parts_in_view(metrics, position, moment)
    assert_in_delta metrics['inner_top'], metrics['header']['top'], 1, "#{position}: the header is not at the top #{moment}"
    assert_in_delta metrics['inner_bottom'], metrics['footer']['bottom'], 1, "#{position}: the footer is not at the bottom #{moment}"
  end

  test 'in a full-height pane, short content still fills it and the footer sits on its bottom edge' do
    open_side_panel
    metrics = panel_metrics

    assert_equal metrics['client_height'], metrics['scroll_height'], 'the demo content should be short enough not to scroll'
    assert_in_delta metrics['client_height'], metrics['content']['height'], 1, 'the content root does not fill the pane'
    assert_in_delta metrics['inner_top'], metrics['header']['top'], 1, 'the header is not at the top of the pane'
    assert_in_delta metrics['inner_bottom'], metrics['footer']['bottom'], 1,
                    'the footer floats instead of sitting on the bottom of the pane'
  end

  # Every position caps its height inside the viewport and scrolls itself, so long content never
  # pushes the header and its close button, or the footer and its actions, out of reach.
  test 'in every position, long content scrolls inside the dialog with the header and footer in view' do
    disable_transitions

    Ui::ModalComponent::POSITIONS.each do |position|
      open_long_modal(position)
      metrics = panel_metrics('#modal dialog')

      assert_operator metrics['top'], :>=, 0, "#{position}: the dialog starts above the viewport"
      assert_operator metrics['bottom'], :<=, metrics['viewport'], "#{position}: the dialog runs past the viewport"
      assert_operator metrics['scroll_height'], :>, metrics['client_height'], "#{position}: the dialog grew instead of scrolling"
      assert_parts_in_view(metrics, position, 'before scrolling')

      scroll_to_end('#modal dialog')
      assert_parts_in_view(panel_metrics('#modal dialog'), position, 'after scrolling')

      stream('<turbo-stream action="ui_close_modal" target="modal"><template></template></turbo-stream>')
      no_modal
    end
  end

  test 'a 422 replaces the content frame, keeping the same dialog element and the same frame id' do
    open_modal(1, trigger: 'edit')
    mark_dialog('before-422')
    record_response_statuses

    fill_in 'Name', with: 'Q3 campaign'
    within('#modal') { click_on 'Save' }

    assert_selector '#modal turbo-frame#project_modal_content', text: 'is already taken'
    assert_equal [422], response_statuses
    assert_same_dialog('before-422')
    assert_equal ['project_modal_content'],
                 page.evaluate_script("[...document.querySelectorAll('#modal [data-slot=modal-content]')].map((e) => e.id)")
    # The re-rendered content is the same component: one form, still tracking changes, and the
    # heading the dialog is named by.
    assert_selector '#modal turbo-frame#project_modal_content > form[data-controller~="ui--form-change"]', count: 1
    assert_named 'Edit project'
  end

  # The guide's next step and one-time result: a stream that replaces the content frame with the
  # same component, same id, swaps what the modal shows and leaves the modal alone.
  test 'a stream that replaces the content frame shows the next step in the same, still-named dialog' do
    open_modal(1)
    mark_dialog('step-1')
    count_mounts
    next_step = ApplicationController.render(
      Ui::ModalContentComponent.new(id: 'project_modal_content', title: 'Step 2 of 2').with_content('Review and confirm'),
      layout: false
    )

    stream(%(<turbo-stream action="replace" target="project_modal_content"><template>#{next_step}</template></turbo-stream>))

    assert_selector '#modal turbo-frame#project_modal_content', text: 'Review and confirm'
    assert_same_dialog('step-1')
    assert_equal 0, mounts, 'replacing the content re-mounted the modal'
    assert_named 'Step 2 of 2'
    assert_state '#modal dialog', 'open'
  end

  test "the header's close button closes the modal with no request and returns focus to the trigger" do
    open_modal(1)
    count_requests
    record_dialog_states

    within('#modal [data-slot=modal-content-header]') do
      find("button[aria-label='#{I18n.t('rails_ui_kit.modal.close_label')}']").click
    end

    no_modal
    assert_equal 0, requests
    assert_includes dialog_states, 'closing'
    assert_scroll_unlocked
    assert_equal 'open_project_1', focused_id
  end

  test 'header, body and footer pass an axe audit in a side panel' do
    open_side_panel

    assert_accessible(within: ACTIVITY)
  end
end
