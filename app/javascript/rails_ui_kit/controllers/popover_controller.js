import { Controller } from "@hotwired/stimulus"
import { computePosition, flip, shift, offset } from "@floating-ui/dom"

const FOCUSABLE = 'button, a[href], input, select, textarea, [tabindex]:not([tabindex="-1"])'

// A click can reach toggle() twice when the caller also wires click->ui--popover#toggle
// on their own control; the second call must not undo the first.
const toggledEvents = new WeakSet()

export default class extends Controller {
  static targets = ["trigger", "content"]

  static values = {
    placement: { type: String, default: "bottom" },
    offset: { type: Number, default: 8 },
    open: Boolean
  }

  initialize() {
    this.onTriggerClick = (event) => {
      if (this.triggerControl.contains(event.target)) this.toggle(event)
    }
    this.onKeydown = this.handleKeydown.bind(this)
    this.onBeforeCache = () => this.reset()
  }

  connect() {
    if (!this.contentTarget.id) {
      this.contentTarget.id = `ui-popover-${Math.random().toString(36).slice(2, 10)}`
    }
    this.triggerControl.setAttribute("aria-haspopup", "dialog")
    this.triggerControl.setAttribute("aria-controls", this.contentTarget.id)
    this.reset()

    this.triggerTarget.addEventListener("click", this.onTriggerClick)
    this.element.addEventListener("keydown", this.onKeydown)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
    this.connected = true
  }

  disconnect() {
    this.connected = false
    this.triggerTarget.removeEventListener("click", this.onTriggerClick)
    this.element.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    this.reset()
  }

  toggle(event) {
    if (event) {
      if (toggledEvents.has(event)) return
      toggledEvents.add(event)
      event.preventDefault()
    }
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  // Stimulus replays a stored open-value before connect(); only act once connected, so a
  // page restored from Turbo's cache never reopens the panel.
  openValueChanged() {
    if (!this.connected) return

    if (this.openValue) {
      this.show()
    } else {
      this.hide()
    }
  }

  show() {
    if (this.shown) return
    this.shown = true
    this.cancelPending()

    this.position()

    this.contentTarget.classList.remove("hidden")
    this.frame = requestAnimationFrame(() => {
      this.contentTarget.classList.remove("opacity-0", "scale-95")
      this.contentTarget.classList.add("opacity-100", "scale-100")
    })

    this.triggerControl.setAttribute("aria-expanded", "true")

    this.setupListeners()
  }

  hide() {
    if (!this.shown) return
    this.shown = false
    this.cancelPending()
    this.cleanup()

    this.contentTarget.classList.remove("opacity-100", "scale-100")
    this.contentTarget.classList.add("opacity-0", "scale-95")
    this.hideTimer = setTimeout(() => {
      this.contentTarget.classList.add("hidden")
    }, 100)

    this.triggerControl.setAttribute("aria-expanded", "false")
  }

  // The closed resting state, applied at once: no animation, no pending timers or frames,
  // no open-state listeners. Runs on connect, on disconnect and on turbo:before-cache, so
  // the cached snapshot is always closed.
  reset() {
    this.shown = false
    this.cancelPending()
    this.cleanup()

    this.contentTarget.classList.remove("opacity-100", "scale-100")
    this.contentTarget.classList.add("hidden", "opacity-0", "scale-95")
    this.triggerControl.setAttribute("aria-expanded", "false")

    if (this.openValue) this.openValue = false
  }

  // The trigger target wraps the caller's control, normally a <button>. Clicks, ARIA state,
  // focus and positioning belong on that control: the wrapping <div> is neither focusable
  // nor announced, and in a block layout it spans the full width. Falls back to the wrapper
  // when it holds nothing focusable.
  get triggerControl() {
    if (this.triggerTarget.matches(FOCUSABLE)) return this.triggerTarget
    return this.triggerTarget.querySelector(FOCUSABLE) || this.triggerTarget
  }

  position() {
    computePosition(this.triggerControl, this.contentTarget, {
      placement: this.placementValue,
      middleware: [
        offset(this.offsetValue),
        flip(),
        shift({ padding: 8 })
      ]
    }).then(({ x, y }) => {
      Object.assign(this.contentTarget.style, {
        left: `${x}px`,
        top: `${y}px`
      })
    })
  }

  setupListeners() {
    // Registered after the current click finishes dispatching, so a click that opened the
    // panel from outside this element doesn't close it straight away.
    this.clickOutsideHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this.close()
      }
    }
    this.listenTimer = setTimeout(() => {
      document.addEventListener("click", this.clickOutsideHandler)
    }, 0)

    this.documentKeydownHandler = (event) => {
      const active = document.activeElement
      if (event.key === "Escape" && (!active || active === document.body)) this.closeOnEscape(event)
    }
    document.addEventListener("keydown", this.documentKeydownHandler)

    this.scrollHandler = () => this.position()
    window.addEventListener("scroll", this.scrollHandler, true)
    window.addEventListener("resize", this.scrollHandler)
  }

  cleanup() {
    if (this.clickOutsideHandler) {
      document.removeEventListener("click", this.clickOutsideHandler)
      this.clickOutsideHandler = null
    }

    if (this.documentKeydownHandler) {
      document.removeEventListener("keydown", this.documentKeydownHandler)
      this.documentKeydownHandler = null
    }

    if (this.scrollHandler) {
      window.removeEventListener("scroll", this.scrollHandler, true)
      window.removeEventListener("resize", this.scrollHandler)
      this.scrollHandler = null
    }
  }

  cancelPending() {
    clearTimeout(this.hideTimer)
    clearTimeout(this.listenTimer)
    cancelAnimationFrame(this.frame)
  }

  // Bound to this element, so it only sees keys pressed while focus is on the trigger or inside
  // the panel. Escape never pulls focus back from another focusable element elsewhere.
  handleKeydown(event) {
    if (event.key === "Escape") this.closeOnEscape(event)
  }

  // Escape reaches this from two paths that never overlap: the element listener while focus
  // is inside, and the document listener while nothing has focus (a click on plain text in the
  // panel leaves focus on <body>). preventDefault() marks it handled for everyone after.
  closeOnEscape(event) {
    if (!this.shown || event.defaultPrevented || event.isComposing) return

    event.preventDefault()
    this.close()
    this.triggerControl.focus()
  }
}
