import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.setupConfirmMethod()
  }

  setupConfirmMethod() {
    Turbo.config.forms.confirm = (message, element, submitter) => {
      return this.showConfirmDialog(message, submitter)
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

  disconnect() {
    Turbo.config.forms.confirm = (message) => {
      return window.confirm(message)
    }
  }
}
