import { Controller } from "@hotwired/stimulus"

// Every part of a confirmation a Turbo call site can set, and the data attribute it travels on:
// data-turbo-confirm- plus the option key, dasherized, with no exceptions -- so the doubled
// confirm-confirm- is the price of a rule nobody has to look up (ui-confirm-dialog § Behavior,
// item 2). The message itself is Turbo's own data-turbo-confirm.
const ATTRIBUTE_OPTIONS = {
  title: "turboConfirmTitle",
  confirm_label: "turboConfirmConfirmLabel",
  cancel_label: "turboConfirmCancelLabel",
  confirm_variant: "turboConfirmConfirmVariant"
}

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
  // data-turbo-confirm onto that form but none of the kit's own attributes, and never passes the
  // link to confirm(), so remember the clicked link to read them back off it.
  rememberLink(event) {
    this.clickedLink = event.target.closest?.("a[data-turbo-confirm]") || null
  }

  async showConfirmDialog(message, form, submitter) {
    const options = { message, ...this.confirmOptions(message, form, submitter) }

    if (!window.defaultConfirmDialog) {
      console.warn("Dialog system not available, falling back to browser confirm()")
      return window.confirm(message)
    }

    try {
      return await window.defaultConfirmDialog(options)
    } catch (error) {
      console.error("Error showing confirmation dialog:", error)
      return window.confirm(message)
    }
  }

  // The submitter first, then the form, then the link Turbo built the form from. A part no
  // attribute names is left out, so the dialog's own rendered default applies -- which is why a
  // plain data-turbo-confirm is still destructive (§ Behavior, item 6).
  confirmOptions(message, form, submitter) {
    const link = this.clickedLink
    this.clickedLink = null
    const formBuiltFromLink = link && !submitter && form?.hidden && link.getAttribute("data-turbo-confirm") === message
    const sources = [submitter, form, formBuiltFromLink ? link : null]

    return Object.fromEntries(
      Object.entries(ATTRIBUTE_OPTIONS).flatMap(([key, attribute]) => {
        const source = sources.find((element) => element?.dataset?.[attribute])
        return source ? [[key, source.dataset[attribute]]] : []
      })
    )
  }
}
