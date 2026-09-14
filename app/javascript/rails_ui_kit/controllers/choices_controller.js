import { Controller } from "@hotwired/stimulus"

// The one thing a checkbox group cannot say for itself: "at least one of these". `required` on a
// checkbox means that box must be checked, and the `group` role has no required state, so a
// required checkbox group is enforced here -- and nowhere else. Everything else a group does
// (toggling, arrow keys, single selection, reset, the checked and focus styling) is the
// platform's or CSS's (ui-choices § Behavior, item 14).
//
//   <fieldset data-controller="ui--choices" data-action="change->ui--choices#derive">
//     <input type="checkbox" data-ui--choices-target="checkbox">
//     <span class="sr-only" data-ui--choices-target="hint">Select at least one option.</span>
//   </fieldset>
//
// It holds no value, registers no key, click or document-level listener beyond the morph it has
// to re-derive on, and is attached only when the group is both `multiple:` and `required:`.
export default class extends Controller {
  static targets = ["checkbox", "hint"]

  initialize() {
    this.onFormReset = this.deriveAfterReset.bind(this)
    this.onMorph = this.deriveFromMorph.bind(this)
  }

  connect() {
    document.addEventListener("turbo:morph-element", this.onMorph)
    this.form?.addEventListener("reset", this.onFormReset)

    this.derive()
  }

  disconnect() {
    document.removeEventListener("turbo:morph-element", this.onMorph)
    this.form?.removeEventListener("reset", this.onFormReset)
    clearTimeout(this.resetTimer)
  }

  // One fact, kept in sync with the DOM: while nothing is checked, the first enabled checkbox
  // carries the custom validity, so the browser blocks the submission, fires `invalid` on that
  // box, focuses it and shows the message. A checked, locked box counts -- its value is carried
  // by a hidden input -- so a group whose only checked box is locked is valid.
  derive() {
    const anyChecked = this.checkboxTargets.some((checkbox) => checkbox.checked)
    const carrier = anyChecked ? null : this.checkboxTargets.find((checkbox) => !checkbox.disabled)

    this.checkboxTargets.forEach((checkbox) => {
      checkbox.setCustomValidity(checkbox === carrier ? this.message : "")
    })
  }

  // The message has one source: the hint the component rendered, which is the chrome string the
  // locale file or the call site resolved. Nothing here holds an English fallback.
  get message() {
    return this.hasHintTarget ? this.hintTarget.textContent.trim() : ""
  }

  deriveAfterReset() {
    // The browser restores each box's default checkedness after the reset event finishes.
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => this.derive())
  }

  deriveFromMorph(event) {
    if (this.element === event.target || this.element.contains(event.target)) this.derive()
  }

  get form() {
    return this.element.closest("form")
  }
}
