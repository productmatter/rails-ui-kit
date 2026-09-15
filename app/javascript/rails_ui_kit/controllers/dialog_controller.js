import { Controller } from "@hotwired/stimulus"

// What a confirmation may set, in the one spelling Ruby, JavaScript and a data attribute share
// (ui-toast § Business rules, rule 1). Everything else, including anything carrying markup, is
// invalid rather than ignored.
const OPTION_KEYS = ["title", "message", "confirm_label", "cancel_label", "confirm_variant"]
const CONFIRM_VARIANT_ATTRIBUTE = "data-ui--dialog-confirm-variant"

// Ui::ConfirmDialogComponent carries this controller on its own <dialog>, so rendering the
// component is all a host does -- no wrapper element. A page can render several (the shared
// default and a host's rich ones), so the globals belong to the page, not to one instance:
// installed when the first connects, delegated to the newest, restored when the last leaves.
// Pending confirms are shared the same way, keyed by the dialog that shows them.
const connected = []
const pendingConfirms = new Map()
let previousGlobals = null

const newest = () => connected[connected.length - 1]

function installGlobals() {
  previousGlobals = { custom: window.customConfirmDialog, default: window.defaultConfirmDialog }
  window.customConfirmDialog = (selector) => newest().showCustomDialog(selector)
  window.defaultConfirmDialog = (messageOrOptions) => newest().showDefaultDialog(messageOrOptions)
}

function restoreGlobals() {
  window.customConfirmDialog = previousGlobals.custom
  window.defaultConfirmDialog = previousGlobals.default
  previousGlobals = null
}

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    if (connected.length === 0) installGlobals()
    connected.push(this)

    this.boundBeforeCache = this.closeBeforeCache.bind(this)
    document.addEventListener("turbo:before-cache", this.boundBeforeCache)
  }

  // A dialog leaving the page can't be answered any more, so whoever is awaiting it hears false
  // rather than waiting forever.
  disconnect() {
    document.removeEventListener("turbo:before-cache", this.boundBeforeCache)

    for (const dialog of [...pendingConfirms.keys()]) {
      if (dialog === this.element || this.element.contains(dialog) || !dialog.isConnected) this.settle(dialog, false)
    }

    connected.splice(connected.indexOf(this), 1)
    if (connected.length === 0) restoreGlobals()
  }

  // Cancel any open confirm so Turbo never caches, and later restores, a dialog in its open state.
  closeBeforeCache() {
    for (const dialog of [...pendingConfirms.keys()]) {
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

    // Reading first: an invalid option rejects before anything opens or is written.
    const options = this.readOptions(dialog, messageOrOptions)
    this.updateDialogContent(dialog, options)

    return this.showDialog(dialog)
  }

  // An id first: "1-delete" is a valid id and an invalid selector, and querySelector throws on it
  // before any fallback could run.
  findDialog(selector) {
    if (!selector) return document.getElementById("default-confirm")
    if (selector instanceof HTMLElement) return selector

    const byId = document.getElementById(selector)
    if (byId) return byId

    try {
      return document.querySelector(selector)
    } catch {
      return null
    }
  }

  // Every confirmation starts from what the component rendered: the dialog carries its own
  // title, message, labels and confirm variant as data-default-*, so nothing one confirmation
  // sets leaks into the next, and this controller keeps no second copy of the kit's strings
  // (ui-confirm-dialog § Behavior, item 7). A hand-written <dialog> without them still works.
  renderedDefaults(dialog) {
    return {
      title: dialog.dataset.defaultTitle || "Confirmation required",
      message: dialog.dataset.defaultMessage || "Are you sure?",
      confirm_label: dialog.dataset.defaultConfirmLabel,
      cancel_label: dialog.dataset.defaultCancelLabel,
      confirm_variant: dialog.dataset.defaultConfirmVariant
    }
  }

  // Loud in development and test, safe in production -- decided in Ruby and rendered as
  // data-strict, never inferred here (ui-toast § Business rules, rule 4).
  readOptions(dialog, messageOrOptions) {
    const given = typeof messageOrOptions === "string"
      ? { message: messageOrOptions }
      : (messageOrOptions && typeof messageOrOptions === "object" ? { ...messageOrOptions } : {})
    const strict = dialog.dataset.strict === "true"
    const accepted = {}

    for (const [key, value] of Object.entries(given)) {
      if (value === undefined || value === null) continue

      const problem = this.optionProblem(dialog, key, value)
      if (!problem) {
        accepted[key] = value
      } else if (strict) {
        throw new Error(`defaultConfirmDialog: ${problem}`)
      } else {
        console.warn(`[rails_ui_kit] defaultConfirmDialog: ${problem} Using the dialog's rendered default.`)
      }
    }

    return { ...this.renderedDefaults(dialog), ...accepted }
  }

  optionProblem(dialog, key, value) {
    if (!OPTION_KEYS.includes(key)) {
      return `${key} is not an option. Expected one of: ${OPTION_KEYS.join(", ")}. An icon or any other ` +
        "markup comes from a Ruby-rendered dialog opened with customConfirmDialog, never from here."
    }
    if (typeof value !== "string") return `${key} must be a string, got ${typeof value}.`
    if (key === "confirm_variant" && !this.confirmTemplate(dialog, value)) {
      return `this dialog renders no confirm button for the variant ${value}.`
    }
    if (key === "message" && dialog.querySelector("[data-ui--dialog-body]")) {
      return "this dialog renders rich content in its body slot, which a message would overwrite."
    }
    return null
  }

  // Text and a server-rendered element, never a class or a markup string (ui-toast
  // § Business rules, rule 2).
  updateDialogContent(dialog, options) {
    this.writeText(dialog.querySelector("[data-ui--dialog-title]"), options.title)
    this.writeText(dialog.querySelector("[data-ui--dialog-message]"), options.message)
    this.writeText(dialog.querySelector("button[value='cancel']"), options.cancel_label)
    this.updateConfirmButton(dialog, options)
  }

  updateConfirmButton(dialog, options) {
    let confirm = dialog.querySelector("button[value='confirm']")
    if (!confirm) return

    const variant = options.confirm_variant
    const template = variant && this.confirmTemplate(dialog, variant)
    if (template && confirm.getAttribute(CONFIRM_VARIANT_ATTRIBUTE) !== variant) {
      const replacement = template.content.firstElementChild.cloneNode(true)
      confirm.replaceWith(replacement)
      confirm = replacement
    }

    this.writeText(confirm, options.confirm_label)
  }

  confirmTemplate(dialog, variant) {
    return dialog.querySelector(`template[data-ui--dialog-confirm-template="${CSS.escape(variant)}"]`)
  }

  writeText(element, text) {
    if (element && text !== undefined) element.textContent = text
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
      pendingConfirms.set(dialog, { resolve, handleClose, handleSubmit })
    })
  }

  settle(dialog, answer = dialog.returnValue === "confirm") {
    const pending = pendingConfirms.get(dialog)
    if (!pending) return

    pendingConfirms.delete(dialog)
    dialog.removeEventListener("close", pending.handleClose)
    dialog.removeEventListener("submit", pending.handleSubmit)
    pending.resolve(answer)
  }
}
