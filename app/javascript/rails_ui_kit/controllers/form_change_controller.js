import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    dirty: { type: Boolean, default: false }
  }

  connect() {
    this.element.formChangeController = this
    this.originalData = new FormData(this.element)

    this.element.addEventListener('input', this.handleChange.bind(this))
    this.element.addEventListener('change', this.handleChange.bind(this))
    this.element.addEventListener('turbo:submit-end', this.handleSubmitEnd.bind(this))
    this.element.addEventListener('reset', this.handleReset.bind(this))
  }

  disconnect() {
    delete this.element.formChangeController
  }

  handleChange(event) {
    const currentData = new FormData(this.element)
    const isDifferent = this.isFormDataDifferent(this.originalData, currentData)

    if (isDifferent && !this.dirtyValue) {
      this.dirtyValue = true
    } else if (!isDifferent && this.dirtyValue) {
      this.dirtyValue = false
    }
  }

  handleSubmitEnd(event) {
    if (event.detail.success) {
      this.markPristine()
    }
  }

  handleReset(event) {
    this.markPristine()
  }

  dirtyValueChanged() {
    if (this.dirtyValue) {
      this.dispatchChangeEvent('form:changed')
      this.dispatchChangeEvent('ui--form-change:changed')
    } else {
      this.dispatchChangeEvent('form:pristine')
      this.dispatchChangeEvent('ui--form-change:pristine')
    }
  }

  // form:changed / form:pristine collide with anything a host names form:*; every other kit
  // event is namespaced ui--<identifier>:<event>. The unnamespaced pair shipped in 0.2.0, so
  // both fire together until it's removed in 0.4.0 (docs/rails_ui_kit § Form Change).
  dispatchChangeEvent(name) {
    this.element.dispatchEvent(new CustomEvent(name, {
      bubbles: true,
      detail: { form: this.element }
    }))
  }

  markPristine() {
    this.dirtyValue = false
    this.originalData = new FormData(this.element)
  }

  markDirty() {
    this.dirtyValue = true
  }

  isFormDataDifferent(original, current) {
    const originalEntries = Array.from(original.entries())
    const currentEntries = Array.from(current.entries())

    if (originalEntries.length !== currentEntries.length) {
      return true
    }

    for (let i = 0; i < originalEntries.length; i++) {
      const [origKey, origValue] = originalEntries[i]
      const [currKey, currValue] = currentEntries[i]

      if (origKey !== currKey || origValue !== currValue) {
        return true
      }
    }

    return false
  }

  reset() {
    this.markPristine()
  }

  get isDirty() {
    return this.dirtyValue
  }
}
