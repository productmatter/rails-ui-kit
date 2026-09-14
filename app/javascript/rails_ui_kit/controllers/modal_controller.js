import { Controller } from "@hotwired/stimulus"

// Ui::ModalComponent. ui--overlay, on the same element, owns everything a modal overlay needs:
// the top layer, Escape, the backdrop click, the scroll lock, focus in, back and kept inside, and
// the exit animation. What is left here is what makes it this component: it removes itself once
// closed, it never survives into Turbo's page cache, and it asks before discarding unsaved
// changes -- both of the last two through ui--overlay's own events.
export default class extends Controller {
  static values = {
    trackChanges: { type: Boolean, default: false },
    closeOnBackdrop: { type: Boolean, default: true }
  }

  connect() {
    this.formDirty = false

    if (this.trackChangesValue) {
      this.boundFormChanged = this.handleFormChanged.bind(this)
      this.boundFormPristine = this.handleFormPristine.bind(this)

      this.element.addEventListener('form:changed', this.boundFormChanged)
      this.element.addEventListener('form:pristine', this.boundFormPristine)
      this.setupBeforeUnloadHandler()
    }

    this.boundBeforeCache = this.remove.bind(this)
    document.addEventListener('turbo:before-cache', this.boundBeforeCache)
  }

  disconnect() {
    if (this.trackChangesValue) {
      this.element.removeEventListener('form:changed', this.boundFormChanged)
      this.element.removeEventListener('form:pristine', this.boundFormPristine)
    }

    document.removeEventListener('turbo:before-cache', this.boundBeforeCache)
    this.removeBeforeUnloadHandler()
  }

  // Public action for buttons inside the modal. A person closing it, so it asks first, the same
  // as Escape and the backdrop do.
  close(event) {
    if (event) {
      event.preventDefault()
    }

    this.overlay?.dismiss()
  }

  // ui--overlay:dismiss, cancelable, before any Escape, backdrop or close-button dismissal, and
  // named: close_on_backdrop refuses one gesture without refusing the rest.
  guardDismiss(event) {
    if (!this.closeOnBackdropValue && event.detail.reason === 'outside') return event.preventDefault()
    if (!this.trackChangesValue || !this.formDirty) return

    event.preventDefault()
    this.confirmClose()
  }

  async confirmClose() {
    const message = "You have unsaved changes. Are you sure you want to close?"
    let confirmed

    try {
      if (typeof window.defaultConfirmDialog !== 'function') throw new Error("Confirm dialog not available")
      confirmed = await window.defaultConfirmDialog({ title: "Unsaved Changes", message })
    } catch (error) {
      console.error("ui--modal: falling back to browser confirm()", error)
      confirmed = confirm(message)
    }

    if (confirmed) {
      this.formDirty = false
      this.overlay?.close()
    }
  }

  // Closed is the resting state: the modal's own element leaves the page, its container stays
  // reusable. Also runs on turbo:before-cache, so Back never restores a modal.
  remove() {
    this.element.remove()
  }

  handleFormChanged(event) {
    this.formDirty = true
  }

  handleFormPristine(event) {
    this.formDirty = false
  }

  setupBeforeUnloadHandler() {
    this.beforeUnloadHandler = (event) => {
      if (this.formDirty) {
        event.preventDefault()
        event.returnValue = ''
      }
    }
    window.addEventListener('beforeunload', this.beforeUnloadHandler)
  }

  removeBeforeUnloadHandler() {
    if (this.beforeUnloadHandler) {
      window.removeEventListener('beforeunload', this.beforeUnloadHandler)
      this.beforeUnloadHandler = null
    }
  }

  get overlay() {
    return this.application.getControllerForElementAndIdentifier(this.element, 'ui--overlay')
  }
}
