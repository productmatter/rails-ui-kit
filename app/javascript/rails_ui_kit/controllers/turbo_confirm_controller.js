import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (typeof Turbo === "undefined" || !Turbo.config?.forms) {
      console.warn("ui--turbo-confirm: Turbo is not loaded; controller is inert.")
      return
    }

    this.boundConfirm = (message, element, submitter) => this.showConfirmDialog(message, element, submitter)
    this.previousConfirm = Turbo.config.forms.confirm
    Turbo.config.forms.confirm = this.boundConfirm

    this.boundRememberLink = this.rememberLink.bind(this)
    document.addEventListener("click", this.boundRememberLink, true)
  }

  disconnect() {
    document.removeEventListener("click", this.boundRememberLink, true)

    if (typeof Turbo === "undefined" || !Turbo.config?.forms) return

    if (Turbo.config.forms.confirm === this.boundConfirm) {
      Turbo.config.forms.confirm = this.previousConfirm
    }
  }

  // Turbo submits a `data-turbo-method` link through a hidden <form> it builds itself. It copies
  // data-turbo-confirm onto that form but not data-turbo-confirm-title, and never passes the link to
  // confirm(), so remember the clicked link to read its title back.
  rememberLink(event) {
    this.clickedLink = event.target.closest?.("a[data-turbo-confirm]") || null
  }

  async showConfirmDialog(message, form, submitter) {
    const title = this.confirmTitle(message, form, submitter)

    if (!window.defaultConfirmDialog) {
      console.warn("Dialog system not available, falling back to browser confirm()")
      return window.confirm(message)
    }

    try {
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

  confirmTitle(message, form, submitter) {
    const link = this.clickedLink
    this.clickedLink = null

    const title = submitter?.dataset?.turboConfirmTitle || form?.dataset?.turboConfirmTitle
    if (title) return title

    const formBuiltFromLink = link && !submitter && form?.hidden && link.getAttribute("data-turbo-confirm") === message
    return formBuiltFromLink ? link.dataset.turboConfirmTitle : undefined
  }
}
