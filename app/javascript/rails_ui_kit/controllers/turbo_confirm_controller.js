import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (typeof Turbo === "undefined" || !Turbo.config?.forms) {
      console.warn("ui--turbo-confirm: Turbo is not loaded; controller is inert.")
      return
    }

    this.boundConfirm = (message, element, submitter) => this.showConfirmDialog(message, submitter)
    this.previousConfirm = Turbo.config.forms.confirm
    Turbo.config.forms.confirm = this.boundConfirm
  }

  disconnect() {
    if (typeof Turbo === "undefined" || !Turbo.config?.forms) return

    if (Turbo.config.forms.confirm === this.boundConfirm) {
      Turbo.config.forms.confirm = this.previousConfirm
    }
  }

  async showConfirmDialog(message, submitter) {
    if (!window.defaultConfirmDialog) {
      console.warn("Dialog system not available, falling back to browser confirm()")
      return window.confirm(message)
    }

    try {
      const title = submitter?.dataset?.turboConfirmTitle

      if (title) {
        return await window.defaultConfirmDialog({
          title: title,
          message: message
        })
      }

      return await window.defaultConfirmDialog(message)
    } catch (error) {
      console.error("Error showing confirmation dialog:", error)
      return window.confirm(message)
    }
  }
}
