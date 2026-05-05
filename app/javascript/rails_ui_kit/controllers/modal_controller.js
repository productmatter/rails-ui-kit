import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "backdrop"]

  static values = {
    position: { type: String, default: "center" },
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
    }
  }

  disconnect() {
    if (this.trackChangesValue) {
      this.element.removeEventListener('form:changed', this.boundFormChanged)
      this.element.removeEventListener('form:pristine', this.boundFormPristine)
    }

    this.removeBeforeUnloadHandler()
  }

  dialogTargetConnected() {
    this.open()
  }

  dialogTargetDisconnected() {
    this.removeBeforeUnloadHandler()
  }

  open() {
    this.dialogTarget.showModal()
    document.body.style.overflow = 'hidden'

    if (this.hasBackdropTarget) {
      requestAnimationFrame(() => {
        this.backdropTarget.classList.remove('opacity-0')
        this.backdropTarget.classList.add('opacity-100')
      })
    }

    requestAnimationFrame(() => {
      this.dialogTarget.classList.remove('opacity-0', ...this.translateOutClasses())
      this.dialogTarget.classList.add('opacity-100', ...this.translateInClasses())
    })

    if (this.trackChangesValue) {
      this.setupBeforeUnloadHandler()
    }
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }

    if (this.formDirty && this.trackChangesValue) {
      this.confirmClose()
      return
    }

    this.performClose()
  }

  async confirmClose() {
    if (typeof window.defaultConfirmDialog === 'function') {
      const confirmed = await window.defaultConfirmDialog({
        title: "Unsaved Changes",
        message: "You have unsaved changes. Are you sure you want to close?"
      })

      if (confirmed) {
        this.formDirty = false
        this.performClose()
      }
    } else {
      if (confirm("You have unsaved changes. Are you sure you want to close?")) {
        this.formDirty = false
        this.performClose()
      }
    }
  }

  performClose() {
    this.removeBeforeUnloadHandler()

    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove('opacity-100')
      this.backdropTarget.classList.add('opacity-0')
    }

    this.dialogTarget.classList.remove('opacity-100', ...this.translateInClasses())
    this.dialogTarget.classList.add('opacity-0', ...this.translateOutClasses())

    setTimeout(() => {
      this.dialogTarget.close()
      document.body.style.overflow = ''

      setTimeout(() => {
        const frame = this.element.closest('turbo-frame')
        if (frame) {
          frame.innerHTML = ''
        }
      }, 50)
    }, 300)
  }

  closeOnBackdropClick(event) {
    if (!this.closeOnBackdropValue) return
    if (event.target === this.dialogTarget) {
      this.close(event)
    }
  }

  closeOnEscape(event) {
    if (event.key === 'Escape') {
      event.preventDefault()
      if (this.formDirty && this.trackChangesValue) {
        this.confirmClose()
      } else {
        this.performClose()
      }
    }
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

  translateInClasses() {
    switch(this.positionValue) {
      case 'center': return ['modal-center-visible']
      case 'full_screen': return ['modal-full-screen-visible']
      case 'right': return ['modal-right-visible']
      case 'left': return ['modal-left-visible']
      case 'top': return ['modal-top-visible']
      case 'top_full': return ['modal-top-full-visible']
      case 'bottom': return ['modal-bottom-visible']
      case 'bottom_full': return ['modal-bottom-full-visible']
      default: return ['modal-center-visible']
    }
  }

  translateOutClasses() {
    switch(this.positionValue) {
      case 'center': return ['modal-center-hidden']
      case 'full_screen': return ['modal-full-screen-hidden']
      case 'right': return ['modal-right-hidden']
      case 'left': return ['modal-left-hidden']
      case 'top': return ['modal-top-hidden']
      case 'top_full': return ['modal-top-full-hidden']
      case 'bottom': return ['modal-bottom-hidden']
      case 'bottom_full': return ['modal-bottom-full-hidden']
      default: return ['modal-center-hidden']
    }
  }
}
