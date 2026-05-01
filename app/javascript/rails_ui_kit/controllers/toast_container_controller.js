import { Controller } from "@hotwired/stimulus"

const TOAST_EVENT = "rails-ui-kit:toast"
const KNOWN_TYPES = ["success", "error", "notice", "alert", "info"]

export default class extends Controller {
  static targets = ["template", "stack"]

  connect() {
    this.boundEventHandler = this.handleToastEvent.bind(this)
    this.boundShowToast = this.showToast.bind(this)

    document.addEventListener(TOAST_EVENT, this.boundEventHandler)

    this.previousTriggerToast = window.triggerToast
    window.triggerToast = this.boundShowToast
  }

  disconnect() {
    document.removeEventListener(TOAST_EVENT, this.boundEventHandler)

    if (window.triggerToast === this.boundShowToast) {
      window.triggerToast = this.previousTriggerToast
    }
  }

  handleToastEvent(event) {
    const { type, message } = event.detail
    this.showToast(type, message)
  }

  /**
   * Show a toast notification.
   * @param {string} type - success | error | notice | alert | info
   * @param {string|Object} message - Simple string or { title, body, timeout }
   */
  showToast(type, message) {
    if (this.templateTargets.length === 0) {
      console.error("rails-ui-kit toast container is missing its <template> targets")
      return
    }

    const resolvedType = KNOWN_TYPES.includes(type) ? type : "info"
    const template = this.templateTargets.find(t => t.dataset.toastType === resolvedType)
      || this.templateTargets.find(t => t.dataset.toastType === "info")
      || this.templateTargets[0]

    const fragment = template.content.cloneNode(true)
    const root = fragment.firstElementChild
    if (!root) return

    const data = this.normalizeMessage(message)
    this.applyContent(root, data)
    this.applyTimeout(root, data.timeout, resolvedType)

    const target = this.hasStackTarget ? this.stackTarget : this.element
    target.appendChild(root)
  }

  applyContent(root, data) {
    const titleEl = root.querySelector('[data-ui--toast-target="title"]')
    const bodyEl = root.querySelector('[data-ui--toast-target="body"]')

    if (titleEl) titleEl.textContent = data.title || ""

    if (bodyEl) {
      if (data.body) {
        bodyEl.textContent = data.body
        bodyEl.classList.remove("hidden")
      } else {
        bodyEl.textContent = ""
        bodyEl.classList.add("hidden")
      }
    }
  }

  applyTimeout(root, explicitTimeout, type) {
    const timeout = explicitTimeout || (type === "error" ? 20000 : 3000)
    root.setAttribute("data-ui--toast-self-destruct-value", String(timeout))

    const timerInner = root.querySelector('[data-ui--toast-target="timer"]')
    if (timerInner) {
      timerInner.style.transitionDuration = `${timeout}ms`
    }
  }

  normalizeMessage(message) {
    if (message && typeof message === "object") {
      return { title: message.title, body: message.body, timeout: message.timeout }
    }
    if (typeof message === "string") {
      return { title: message }
    }
    return { title: "Notification" }
  }
}
