# frozen_string_literal: true

require 'application_system_test_case'
require 'tmpdir'

# Ui::FileComponent in the browser, on the File page: the native input is the one control, a chosen
# file collapses the drop area to the file row, a drop `accept` refuses is stopped before the
# browser takes it, and a reset puts back what the server rendered.
class FileControlTest < ApplicationSystemTestCase
  EMPTY = 'form_pdf'
  CHOSEN = 'edit_pdf'

  setup do
    visit file_path
    disable_transitions
  end

  def root(id)
    "[data-slot='file']:has(##{id})"
  end

  def fixture(name, bytes = 372_000)
    path = File.join(Dir.mktmpdir, name)
    File.binwrite(path, "\0" * bytes)
    path
  end

  def choose_file(id, path)
    find("##{id}", visible: :all).send_keys(path)
  end

  def state(id)
    find(root(id))['data-state']
  end

  # A synthetic drop carrying one file, dispatched on the input the way a real drop lands, so what
  # the controller does with it can be read back: whether it stopped the browser, and what it said.
  def drop(id, name, type)
    page.evaluate_script(<<~JS, id, name, type)
      (() => {
        const input = document.getElementById(arguments[0])
        window.__fileEvents = []
        input.closest('[data-slot=file]').addEventListener('ui--file:rejected', (event) => {
          window.__fileEvents.push(event.detail.files.map((file) => file.name).join(','))
        })
        const transfer = new DataTransfer()
        transfer.items.add(new File(['x'], arguments[1], { type: arguments[2] }))
        const event = new DragEvent('drop', { dataTransfer: transfer, bubbles: true, cancelable: true })
        input.dispatchEvent(event)
        return { prevented: event.defaultPrevented, rejected: window.__fileEvents }
      })()
    JS
  end

  test 'FI1 choosing a file collapses the drop area to the file row, with its name and size' do
    assert_equal 'empty', state(EMPTY)
    choose_file(EMPTY, fixture('AmRisk_BOP_application.pdf'))

    assert_selector "#{root(EMPTY)} [data-slot='file-row']", text: 'AmRisk_BOP_application.pdf'
    assert_selector "#{root(EMPTY)} [data-ui--file-target='meta']", text: '372 kB'
    assert_selector "#{root(EMPTY)} [data-slot='file-drop']", visible: :hidden
    assert_equal 'chosen', state(EMPTY)
  end

  test 'FI2 choosing replaces a server-rendered file, and a form reset puts it back' do
    page.execute_script(<<~JS)
      const form = document.createElement('form')
      form.id = 'file-reset-form'
      const field = document.getElementById('#{CHOSEN}').closest('[data-slot=field]')
      field.parentNode.insertBefore(form, field)
      form.appendChild(field)
    JS
    choose_file(CHOSEN, fixture('replacement.pdf', 2_400_000))
    assert_selector "#{root(CHOSEN)} [data-slot='file-row']", text: 'replacement.pdf'
    assert_selector "#{root(CHOSEN)} [data-ui--file-target='meta']", text: '2.4 MB'

    page.execute_script("document.getElementById('file-reset-form').reset()")

    assert_selector "#{root(CHOSEN)} [data-slot='file-row']", text: 'ACORD_125_2016-03_partner_copy.pdf'
    assert_selector "#{root(CHOSEN)} [data-ui--file-target='meta']", text: '372 KB · 4 pages'
  end

  test 'FI3 a dropped file accept refuses is stopped and reported; an accepted one is left to the browser' do
    refused = drop(EMPTY, 'notes.txt', 'text/plain')
    assert refused['prevented'], 'a refused drop must be stopped before the browser takes it'
    assert_equal ['notes.txt'], refused['rejected']

    accepted = drop(EMPTY, 'form.pdf', 'application/pdf')
    refute accepted['prevented'], 'an accepted drop is the browser\'s own'
    assert_empty accepted['rejected']
  end

  test 'FI4 a file dragged over the box shows the drop target, and leaving clears it' do
    page.execute_script(<<~JS, EMPTY)
      const input = document.getElementById(arguments[0])
      const transfer = new DataTransfer()
      transfer.items.add(new File(['x'], 'form.pdf', { type: 'application/pdf' }))
      input.dispatchEvent(new DragEvent('dragenter', { dataTransfer: transfer, bubbles: true, cancelable: true }))
    JS
    assert_equal 'true', find(root(EMPTY))['data-dragging']

    page.execute_script("document.getElementById(arguments[0]).dispatchEvent(new DragEvent('dragleave', { bubbles: true }))", EMPTY)
    assert_nil find(root(EMPTY))['data-dragging']
  end

  test 'FI5 the input is the one tab stop, and its keyboard focus draws on the box' do
    page.execute_script(<<~JS, EMPTY)
      const before = document.createElement('button')
      before.id = 'before-file'
      before.textContent = 'Before'
      document.getElementById(arguments[0]).closest('[data-slot=field]').before(before)
      before.focus()
    JS
    press(:tab)
    assert_equal EMPTY, focused_id
    assert_equal '2px', page.evaluate_script('getComputedStyle(document.querySelector(arguments[0])).outlineWidth', root(EMPTY))

    press(:tab)
    assert_equal CHOSEN, focused_id, 'the Change button under the next control is not a tab stop either'
  end

  test 'FI6 the input is named by its label and described by the Field' do
    assert_equal EMPTY, find('#file-preview label', text: /\APDF/)[:for]
    assert_selector "input[type='file']##{EMPTY}", visible: :all
    assert_equal 'edit_pdf-description edit_pdf-file', find("##{CHOSEN}", visible: :all)['aria-describedby']
    assert_equal 'form_pdf-meta', find("##{EMPTY}", visible: :all)['aria-describedby']

    choose_file(EMPTY, fixture('form.pdf'))
    assert_selector "##{EMPTY}[aria-describedby='form_pdf-file']", visible: :all
  end

  test 'FI8 the description follows the state: the current file is what a screen reader hears' do
    description = page.evaluate_script(<<~'JS', CHOSEN)
      document.getElementById(arguments[0]).getAttribute('aria-describedby').split(' ')
        .map((id) => document.getElementById(id).textContent.replace(/\s+/g, ' ').trim()).join(' | ')
    JS

    assert_equal 'Mapped fields the new PDF still has are kept. | ACORD_125_2016-03_partner_copy.pdf 372 KB · 4 pages', description
  end

  test 'FI7 the previews pass axe, in light and dark' do
    [false, true].each do |dark|
      use_dark_mode(dark)
      assert_accessible within: '#file-preview'
      assert_accessible within: '#file-states-preview'
    end
    use_dark_mode(false)
  end
end
