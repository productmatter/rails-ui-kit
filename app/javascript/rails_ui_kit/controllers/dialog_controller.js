import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    window.customConfirmDialog = this.showCustomDialog.bind(this)
    window.defaultConfirmDialog = this.showDefaultDialog.bind(this)
  }

  disconnect() {
    delete window.customConfirmDialog
    delete window.defaultConfirmDialog
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
    dialog.returnValue = ""
    dialog.showModal()

    return new Promise((resolve) => {
      const handleClose = () => {
        const confirmed = dialog.returnValue === "confirm"
        dialog.removeEventListener("close", handleClose)
        resolve(confirmed)
      }

      dialog.addEventListener("close", handleClose, { once: true })
    })
  }
}
