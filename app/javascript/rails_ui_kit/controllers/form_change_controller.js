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
      this.element.dispatchEvent(new CustomEvent('form:changed', {
        bubbles: true,
        detail: { form: this.element }
      }))
    } else {
      this.element.dispatchEvent(new CustomEvent('form:pristine', {
        bubbles: true,
        detail: { form: this.element }
      }))
    }
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
