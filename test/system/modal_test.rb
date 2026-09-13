# frozen_string_literal: true

require 'application_system_test_case'

class ModalTest < ApplicationSystemTestCase
  test 'M1: closing a modal rendered into a plain div removes it, leaving no backdrop to block clicks' do
    visit modal_path
    find('#stream-modal-trigger').click
    assert_selector 'dialog[open]'

    find("[data-action='click->ui--modal#close']", text: 'Close').click
    assert_no_selector "[data-controller~='ui--modal']"

    # A real click on a page link navigates -- nothing left behind intercepts it.
    click_on 'Turbo Confirm'
    assert_selector 'h1', text: 'Turbo Confirm'
  end

  test 'M6: closing a modal inside a turbo-frame with a sibling only removes the modal, not the sibling' do
    visit modal_path
    find('#frame-modal-trigger').click
    frame = find('turbo-frame#frame-modal', visible: :all)
    assert_selector 'turbo-frame#frame-modal dialog[open]'

    page.execute_script(<<~JS)
      var frame = document.querySelector('turbo-frame#frame-modal')
      var sibling = document.createElement('div')
      sibling.id = 'frame-modal-sibling'
      sibling.textContent = 'sibling content'
      frame.appendChild(sibling)
    JS

    within frame do
      find("[data-action='click->ui--modal#close']", text: 'Close').click
    end

    assert_no_selector "[data-controller~='ui--modal']"
    assert_selector '#frame-modal-sibling', visible: :all
  end

  test "M2: a Turbo Stream that empties the modal's container unlocks the body and restores focus" do
    visit modal_path
    find('#stream-modal-trigger').click
    assert_selector 'dialog[open]'
    assert_equal 'hidden', page.evaluate_script('document.body.style.overflow')

    page.execute_script(<<~JS)
      Turbo.renderStreamMessage('<turbo-stream action="update" target="stream-modal"><template></template></turbo-stream>')
    JS

    assert_no_selector "[data-controller~='ui--modal']"
    assert_equal '', page.evaluate_script('document.body.style.overflow')
    assert page.evaluate_script("document.activeElement === document.getElementById('stream-modal-trigger')")
  end

  test 'M3: after Turbo navigation and Back, the modal is gone, unlocked, and the trigger opens a real modal again' do
    visit modal_path
    find('#stream-modal-trigger').click
    assert_selector 'dialog[open]'

    # The open dialog's native backdrop blocks every click, including a sidebar link, so
    # trigger the Turbo visit directly -- this is exactly the path a real navigation takes.
    page.execute_script('Turbo.visit(arguments[0])', installation_path)
    assert_selector 'h1', text: 'Installation'

    page.go_back
    assert_selector 'h1', text: 'Modal'
    assert_no_selector "[data-controller~='ui--modal']"
    assert_equal '', page.evaluate_script('document.body.style.overflow')

    find('#stream-modal-trigger').click
    assert_selector 'dialog[open]'
    assert page.evaluate_script("document.querySelector('dialog[open]').matches(':modal')")
  end

  test 'M4: a track_changes modal falls back to the browser confirm() when the default confirm dialog is missing' do
    visit modal_path
    inject_track_changes_modal

    page.execute_script("document.getElementById('m4-form').dispatchEvent(new CustomEvent('form:changed', { bubbles: true }))")
    page.execute_script("document.getElementById('default-confirm').remove()")

    accept_confirm do
      find('#m4-input').send_keys(:escape)
    end

    assert_no_selector "[data-controller~='ui--modal']"
  end

  test "M7: the demo modal's dialog is named via aria-labelledby pointing at its heading" do
    visit modal_path
    find('#stream-modal-trigger').click
    dialog = find('dialog[open]')
    labelledby = dialog['aria-labelledby']
    assert_equal 'stream-modal-title', labelledby
    assert_equal 'Acme rebrand', find("##{labelledby}").text
  end

  test 'stream pattern: closing then reopening via stream ends with the new modal open, locked, and focused' do
    visit modal_path
    find('#stream-modal-trigger').click
    assert_selector 'dialog[open]'
    find("[data-action='click->ui--modal#close']", text: 'Close').click
    assert_no_selector "[data-controller~='ui--modal']"

    find('#stream-modal-trigger').click
    assert_selector 'dialog[open]'
    assert_equal 'hidden', page.evaluate_script('document.body.style.overflow')
    assert page.evaluate_script("document.querySelector('dialog[open]').contains(document.activeElement)")
  end

  test 'stream pattern: a stream that replaces an open modal with another ends with the new one open, locked, and focused' do
    visit modal_path
    find('#stream-modal-trigger').click
    assert_selector 'dialog[open]'

    find('button', text: 'Replace via stream').click

    assert_selector 'dialog[open]', text: 'A different modal'
    assert_equal 'hidden', page.evaluate_script('document.body.style.overflow')
    assert page.evaluate_script("document.querySelector('dialog[open]').contains(document.activeElement)")
  end

  test 'stream/frame pattern: swapping only the inner content frame does not reopen the dialog' do
    visit modal_path
    stub_show_modal_call_counter

    find('#stream-modal-trigger').click
    assert_selector 'dialog[open]', text: 'Acme rebrand'
    assert_equal 1, page.evaluate_script('window.__showModalCalls')

    within find('turbo-frame#stream_modal_content') do
      click_link 'Edit'
    end
    assert_selector 'turbo-frame#stream_modal_content h2', text: 'Edit project'
    assert_equal 1, page.evaluate_script('window.__showModalCalls')

    within find('turbo-frame#stream_modal_content') do
      click_button 'Save'
    end
    assert_selector 'turbo-frame#stream_modal_content p#stream-name-error'
    assert_equal 1, page.evaluate_script('window.__showModalCalls')

    within find('turbo-frame#stream_modal_content') do
      fill_in 'Project name', with: 'Renamed'
      click_button 'Save'
    end
    assert_selector 'turbo-frame#stream_modal_content', text: 'Project saved'
    assert_equal 1, page.evaluate_script('window.__showModalCalls')
  end

  test 'stream/frame pattern: focus stays inside the dialog across an inner content frame swap' do
    visit modal_path

    find('#stream-modal-trigger').click
    track_frame_renders

    # Turbo swaps the frame's content, then waits two repaints before dispatching
    # turbo:frame-render, which is what moves focus. Seeing the new content isn't the
    # finish line; the frame-render event is.
    within find('turbo-frame#stream_modal_content') do
      click_link 'Edit'
    end
    assert_focus_in_dialog_after_frame_render(1)

    within find('turbo-frame#stream_modal_content') do
      fill_in 'Project name', with: 'Renamed'
      click_button 'Save'
    end
    assert_selector 'turbo-frame#stream_modal_content', text: 'Project saved'
    assert_focus_in_dialog_after_frame_render(2)
  end

  test 'stream/frame pattern: an autofocused field in the newly rendered frame keeps focus' do
    visit modal_path
    find('#stream-modal-trigger').click
    track_frame_renders
    page.execute_script(<<~JS)
      document.addEventListener('turbo:before-frame-render', function(event) {
        var field = event.detail.newFrame.querySelector('input[name="name"]')
        if (field) field.setAttribute('autofocus', '')
      })
    JS

    within find('turbo-frame#stream_modal_content') do
      click_link 'Edit'
    end
    assert_focus_in_dialog_after_frame_render(1)
    assert page.evaluate_script("document.activeElement.name === 'name'")
  end

  test 'stream/frame pattern: the turbo-frame trigger opens, navigates inside, closes, and reopens' do
    visit modal_path
    find('#frame-modal-trigger').click
    assert_selector 'turbo-frame#frame-modal dialog[open]'

    within find('turbo-frame#frame-modal') do
      click_link 'Edit'
    end
    assert_selector 'turbo-frame#frame-modal h2', text: 'Edit project'

    within find('turbo-frame#frame-modal') do
      find("[data-action='click->ui--modal#close']", text: 'Close').click
    end
    assert_no_selector "[data-controller~='ui--modal']"

    find('#frame-modal-trigger').click
    assert_selector 'turbo-frame#frame-modal dialog[open]'
  end

  private

  def track_frame_renders
    page.execute_script(<<~JS)
      window.__frameRenders = 0
      document.addEventListener('turbo:frame-render', function() { window.__frameRenders++ })
    JS
  end

  def assert_focus_in_dialog_after_frame_render(count)
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until page.evaluate_script('window.__frameRenders') >= count
    end
    assert page.evaluate_script("document.querySelector('dialog[open]').contains(document.activeElement)"),
           "expected focus inside the dialog, got #{page.evaluate_script('document.activeElement.outerHTML.slice(0, 80)')}"
  end

  def stub_show_modal_call_counter
    page.execute_script(<<~JS)
      window.__showModalCalls = 0
      var proto = HTMLDialogElement.prototype
      var original = proto.showModal
      proto.showModal = function(...args) {
        window.__showModalCalls++
        return original.apply(this, args)
      }
    JS
  end

  # The docs page has no track_changes demo, so build one matching the exact markup
  # Ui::ModalComponent renders (data-controller, targets and values), which Stimulus
  # picks up and connects the same as if it had come from the server.
  def inject_track_changes_modal
    page.execute_script(<<~JS)
      var wrapper = document.createElement('div')
      wrapper.id = 'm4-wrapper'
      wrapper.setAttribute('data-controller', 'ui--modal')
      wrapper.setAttribute('data-ui--modal-position-value', 'center')
      wrapper.setAttribute('data-ui--modal-track-changes-value', 'true')
      wrapper.setAttribute('data-ui--modal-close-on-backdrop-value', 'true')
      wrapper.setAttribute('data-action', 'click->ui--modal#closeOnBackdropClick keydown->ui--modal#closeOnEscape')
      wrapper.innerHTML = '<div data-ui--modal-target="backdrop" class="fixed inset-0 z-[60]"></div>' +
        '<dialog data-ui--modal-target="dialog" class="fixed z-[61] p-0 m-0">' +
        '<form id="m4-form"><input id="m4-input" type="text" name="title"></form>' +
        '</dialog>'
      document.body.appendChild(wrapper)
    JS
    assert_selector 'dialog[open]'
  end
end
