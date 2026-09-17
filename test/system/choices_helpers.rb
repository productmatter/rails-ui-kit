# frozen_string_literal: true

# Shared probes for the Ui::ChoicesComponent browser tests. Not a test file and not a second
# harness: ApplicationSystemTestCase stays the base class, and these are the few Choices-specific
# reads that would otherwise be copied into every file. `press` and `focused_id` come from
# ApplicationSystemTestCase's BrowserHelpers.
module ChoicesHelpers
  def focused_tag
    page.evaluate_script('document.activeElement && document.activeElement.tagName.toLowerCase()')
  end

  # What the browser would actually post for a form: its own FormData, which is the only honest
  # account of which inputs submit and which don't.
  def form_entries(selector)
    page.evaluate_script(<<~JS, selector)
      Array.from(new FormData(document.querySelector(arguments[0])).entries())
    JS
  end

  # Every checked input inside a container, in DOM order -- disabled ones included, because a
  # locked checked box is still checked and that is exactly what the carrier exists for.
  def checked_values(container)
    page.evaluate_script(<<~JS, container)
      Array.from(document.querySelectorAll(arguments[0] + ' input[type=checkbox], ' + arguments[0] + ' input[type=radio]'))
           .filter((input) => input.checked).map((input) => input.value)
    JS
  end

  def validation_message(selector)
    page.evaluate_script('document.querySelector(arguments[0]).validationMessage', selector)
  end

  # A marker on the current document: still there means nothing navigated or re-rendered.
  def mark_document
    page.execute_script('window.__choicesMark = (window.__choicesMark || 0) + 1')
    page.evaluate_script('window.__choicesMark')
  end

  def document_mark
    page.evaluate_script('window.__choicesMark || 0')
  end
end
