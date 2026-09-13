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

    this.boundBeforeCache = this.resetBeforeCache.bind(this)
    document.addEventListener('turbo:before-cache', this.boundBeforeCache)

    this.boundKeepFocus = this.keepFocusInDialog.bind(this)
    this.element.addEventListener('turbo:frame-render', this.boundKeepFocus)
  }

  // Runs however the modal leaves the page: closed, emptied by a Turbo Stream, or navigated away.
  disconnect() {
    if (this.trackChangesValue) {
      this.element.removeEventListener('form:changed', this.boundFormChanged)
      this.element.removeEventListener('form:pristine', this.boundFormPristine)
    }

    document.removeEventListener('turbo:before-cache', this.boundBeforeCache)
    this.element.removeEventListener('turbo:frame-render', this.boundKeepFocus)
    clearTimeout(this.closeTimeout)
    this.removeBeforeUnloadHandler()
    this.unlockScroll()
    this.restoreFocus()
  }

  dialogTargetConnected() {
    this.open()
  }

  dialogTargetDisconnected() {
    this.removeBeforeUnloadHandler()
  }

  open() {
    const dialog = this.dialogTarget
    if (dialog.matches(':modal')) return
    // A page restored from Turbo's cache can carry a non-modal `open` attribute; showModal() throws on it.
    if (dialog.open) dialog.removeAttribute('open')

    this.previouslyFocused = document.activeElement
    dialog.showModal()
    this.lockScroll()

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
      this.performClose()
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

    clearTimeout(this.closeTimeout)
    this.closeTimeout = setTimeout(() => this.teardown(), 300)
  }

  // Closed is the resting state: the modal's own element leaves the page, its container stays reusable.
  teardown() {
    if (this.dialogTarget.open) this.dialogTarget.close()
    this.unlockScroll()
    this.element.remove()
  }

  resetBeforeCache() {
    clearTimeout(this.closeTimeout)
    this.removeBeforeUnloadHandler()
    this.teardown()
  }

  lockScroll() {
    document.body.style.overflow = 'hidden'
    this.scrollLocked = true
  }

  unlockScroll() {
    if (!this.scrollLocked) return
    document.body.style.overflow = ''
    this.scrollLocked = false
  }

  // Swapping a turbo-frame inside the modal removes the focused element; keep focus in the dialog, not on <body>.
  keepFocusInDialog() {
    if (document.activeElement && document.activeElement !== document.body) return
    if (!this.dialogTarget.open) return

    this.dialogTarget.tabIndex = -1
    this.dialogTarget.focus({ preventScroll: true })
  }

  restoreFocus() {
    const target = this.previouslyFocused
    this.previouslyFocused = null
    const focusLost = !document.activeElement || document.activeElement === document.body
    if (focusLost && target?.isConnected) target.focus({ preventScroll: true })
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
