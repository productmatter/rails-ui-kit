import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this.boundShowCustomDialog = this.showCustomDialog.bind(this)
    this.boundShowDefaultDialog = this.showDefaultDialog.bind(this)

    this.previousCustomConfirmDialog = window.customConfirmDialog
    this.previousDefaultConfirmDialog = window.defaultConfirmDialog

    window.customConfirmDialog = this.boundShowCustomDialog
    window.defaultConfirmDialog = this.boundShowDefaultDialog

    this.pendingConfirms = new Map()
    this.boundBeforeCache = this.closeBeforeCache.bind(this)
    document.addEventListener("turbo:before-cache", this.boundBeforeCache)
  }

  disconnect() {
    if (window.customConfirmDialog === this.boundShowCustomDialog) {
      window.customConfirmDialog = this.previousCustomConfirmDialog
    }
    if (window.defaultConfirmDialog === this.boundShowDefaultDialog) {
      window.defaultConfirmDialog = this.previousDefaultConfirmDialog
    }

    document.removeEventListener("turbo:before-cache", this.boundBeforeCache)
  }

  // Cancel any open confirm so Turbo never caches, and later restores, a dialog in its open state.
  closeBeforeCache() {
    for (const dialog of [...this.pendingConfirms.keys()]) {
      if (dialog.open) dialog.close("cancel")
      this.settle(dialog)
    }
  }

  async showCustomDialog(dialogSelector) {
    const dialog = this.findDialog(dialogSelector)

    if (!dialog) {
      console.error(`Dialog not found: ${dialogSelector}`)
      throw new Error(`Dialog not found: ${dialogSelector}`)
    }

    return this.showDialog(dialog)
  }

  async showDefaultDialog(messageOrOptions) {
    const dialog = this.findDialog("default-confirm")

    if (!dialog) {
      console.error("Default confirm dialog not found. Ensure a dialog with id='default-confirm' exists.")
      throw new Error("Default confirm dialog not found")
    }

    const options = this.normalizeOptions(dialog, messageOrOptions)
    this.updateDialogContent(dialog, options)

    return this.showDialog(dialog)
  }

  findDialog(selector) {
    if (!selector) {
      return document.getElementById("default-confirm")
    }

    if (selector instanceof HTMLElement) {
      return selector
    }

    return document.querySelector(selector) || document.getElementById(selector)
  }

  // Ui::ConfirmDialogComponent renders its own (I18n-translated) title and message and stamps
  // them again as data-default-title/data-default-message, so this reads them back off the
  // dialog rather than keeping a second, English-only copy of the same strings. A hand-written
  // <dialog> with neither attribute still works, falling back to English.
  normalizeOptions(dialog, messageOrOptions) {
    const defaults = {
      title: dialog.dataset.defaultTitle || "Confirmation required",
      message: dialog.dataset.defaultMessage || "Are you sure?"
    }

    if (typeof messageOrOptions === "string") {
      return { ...defaults, message: messageOrOptions }
    }

    if (typeof messageOrOptions === "object" && messageOrOptions !== null) {
      return { ...defaults, ...messageOrOptions }
    }

    return defaults
  }

  updateDialogContent(dialog, options) {
    const titleElement = dialog.querySelector("[data-ui--dialog-title]")
    const messageElement = dialog.querySelector("[data-ui--dialog-message]")

    if (titleElement) {
      titleElement.textContent = options.title
    }

    if (messageElement) {
      messageElement.textContent = options.message
    }
  }

  showDialog(dialog) {
    // The previous confirm on this dialog may have closed with its "close" event still queued; settle it with
    // its own answer now, before this confirm resets returnValue. One still open is superseded and resolves false.
    this.settle(dialog)

    dialog.returnValue = ""
    const overlay = this.application.getControllerForElementAndIdentifier(dialog, "ui--overlay")

    if (overlay) {
      overlay.open()
    } else {
      // A host's own <dialog> without ui--overlay opens natively. A page restored from Turbo's cache can carry a
      // non-modal `open` attribute; showModal() throws on it.
      if (dialog.open && !dialog.matches(":modal")) dialog.removeAttribute("open")
      dialog.showModal()
    }

    return new Promise((resolve) => {
      // A "close" that arrives while the dialog is open again belongs to an earlier confirm; ignore it.
      const handleClose = () => {
        if (!dialog.open) this.settle(dialog)
      }

      // With ui--overlay, a button answers the confirm and the overlay closes the dialog, so it can animate out,
      // release its scroll lock and return focus. Closed natively, the overlay would only learn of it from the queued
      // "close" event, which would then close a confirm reopened in the same task.
      const handleSubmit = (event) => {
        if (event.target.method !== "dialog" || event.target.closest("dialog") !== dialog) return

        event.preventDefault()
        dialog.returnValue = event.submitter?.value ?? ""
        this.settle(dialog)
        overlay.close()
      }

      dialog.addEventListener("close", handleClose)
      if (overlay) dialog.addEventListener("submit", handleSubmit)
      this.pendingConfirms.set(dialog, { resolve, handleClose, handleSubmit })
    })
  }

  settle(dialog) {
    const pending = this.pendingConfirms.get(dialog)
    if (!pending) return

    this.pendingConfirms.delete(dialog)
    dialog.removeEventListener("close", pending.handleClose)
    dialog.removeEventListener("submit", pending.handleSubmit)
    pending.resolve(dialog.returnValue === "confirm")
  }
}
