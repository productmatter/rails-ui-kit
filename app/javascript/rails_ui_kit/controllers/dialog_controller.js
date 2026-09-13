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

    this.openDialogs = new Set()
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
    this.openDialogs.forEach((dialog) => dialog.close("cancel"))
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

    const options = this.normalizeOptions(messageOrOptions)
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

  normalizeOptions(messageOrOptions) {
    const defaults = {
      title: "Confirmation required",
      message: "Are you sure?"
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
    // A page restored from Turbo's cache can carry a non-modal `open` attribute; showModal() throws on it.
    if (dialog.open && !dialog.matches(":modal")) dialog.removeAttribute("open")

    dialog.returnValue = ""
    dialog.showModal()
    this.openDialogs.add(dialog)

    return new Promise((resolve) => {
      const handleClose = () => {
        const confirmed = dialog.returnValue === "confirm"
        dialog.removeEventListener("close", handleClose)
        this.openDialogs.delete(dialog)
        resolve(confirmed)
      }

      dialog.addEventListener("close", handleClose, { once: true })
    })
  }
}
