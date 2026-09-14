import { Controller } from "@hotwired/stimulus"

const FOCUSABLE = 'button, a[href], input, select, textarea, [tabindex]:not([tabindex="-1"])'

// Grace period after the pointer/focus leaves the control before the tooltip actually
// hides. Lets the pointer travel from the control onto the tooltip content itself, and
// absorbs a fast leave-then-enter without ever fully hiding.
const HIDE_GRACE_DELAY = 150

// ui--overlay on this element, in hint mode, owns showing and hiding (a popover="manual" in the
// top layer, animated through presence) and the capture-phase Escape that WCAG 1.4.13 asks for;
// ui--anchor owns geometry and the arrow. What stays here is when to show: hover and focus
// tracked separately, with a grace period, plus aria-describedby on the caller's control.
export default class extends Controller {
  static targets = ["trigger", "content"]

  connect() {
    this.isHovered = false
    this.isFocused = false
    this.hideTimeout = null

    // Resolved once and cached: this.triggerTarget/this.contentTarget are live Stimulus
    // target lookups that can throw once the scope starts tearing down, so disconnect()
    // must not depend on them.
    this.controlElement = this.resolveTriggerControl()
    this.contentElement = this.contentTarget

    this.tooltipId = `ui-tooltip-${Math.random().toString(36).slice(2, 9)}`
    this.contentElement.id = this.tooltipId
    this.contentElement.setAttribute("role", "tooltip")

    const existingDescribedBy = this.controlElement.getAttribute("aria-describedby")
    this.controlElement.setAttribute(
      "aria-describedby",
      existingDescribedBy ? `${existingDescribedBy} ${this.tooltipId}` : this.tooltipId
    )

    this.onControlEnter = () => this.handleShow("hover")
    this.onControlLeave = () => this.handleHide("hover")
    this.onControlFocusIn = () => this.handleShow("focus")
    this.onControlFocusOut = () => this.handleHide("focus")
    this.onContentEnter = () => this.handleShow("hover")
    this.onContentLeave = () => this.handleHide("hover")
    this.onOpened = (event) => { if (event.target === this.element) this.setAnchored(true) }
    this.onClosed = (event) => { if (event.target === this.element) this.setAnchored(false) }
    this.onDismiss = (event) => { if (event.target === this.element) this.forget() }
    this.onBeforeCache = () => {
      this.forget()
      this.setAnchored(false)
    }

    this.controlElement.addEventListener("mouseenter", this.onControlEnter)
    this.controlElement.addEventListener("mouseleave", this.onControlLeave)
    this.controlElement.addEventListener("focusin", this.onControlFocusIn)
    this.controlElement.addEventListener("focusout", this.onControlFocusOut)
    this.contentElement.addEventListener("mouseenter", this.onContentEnter)
    this.contentElement.addEventListener("mouseleave", this.onContentLeave)
    this.element.addEventListener("ui--overlay:opened", this.onOpened)
    this.element.addEventListener("ui--overlay:closed", this.onClosed)
    this.element.addEventListener("ui--overlay:dismiss", this.onDismiss)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    this.cancelHide()

    const existingDescribedBy = this.controlElement.getAttribute("aria-describedby")
    if (existingDescribedBy) {
      const remaining = existingDescribedBy.split(" ").filter((id) => id && id !== this.tooltipId).join(" ")
      if (remaining) {
        this.controlElement.setAttribute("aria-describedby", remaining)
      } else {
        this.controlElement.removeAttribute("aria-describedby")
      }
    }

    this.controlElement.removeEventListener("mouseenter", this.onControlEnter)
    this.controlElement.removeEventListener("mouseleave", this.onControlLeave)
    this.controlElement.removeEventListener("focusin", this.onControlFocusIn)
    this.controlElement.removeEventListener("focusout", this.onControlFocusOut)
    this.contentElement.removeEventListener("mouseenter", this.onContentEnter)
    this.contentElement.removeEventListener("mouseleave", this.onContentLeave)
    this.element.removeEventListener("ui--overlay:opened", this.onOpened)
    this.element.removeEventListener("ui--overlay:closed", this.onClosed)
    this.element.removeEventListener("ui--overlay:dismiss", this.onDismiss)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  // The trigger target wraps the caller's control, normally a <button>. Positioning,
  // hover/focus binding and aria-describedby all belong on that control: a wrapping
  // <div> in a block layout is full-width and isn't the thing being pointed at or
  // focused. Falls back to the wrapper when it holds nothing focusable.
  resolveTriggerControl() {
    if (this.triggerTarget.matches(FOCUSABLE)) return this.triggerTarget
    return this.triggerTarget.querySelector(FOCUSABLE) || this.triggerTarget
  }

  handleShow(source) {
    if (source === "hover") this.isHovered = true
    if (source === "focus") this.isFocused = true

    this.cancelHide()
    this.overlay?.open()
  }

  handleHide(source) {
    if (source === "hover") this.isHovered = false
    if (source === "focus") this.isFocused = false

    this.scheduleHide()
  }

  scheduleHide() {
    this.cancelHide()
    this.hideTimeout = setTimeout(() => {
      this.hideTimeout = null
      if (!this.isHovered && !this.isFocused) this.overlay?.close()
    }, HIDE_GRACE_DELAY)
  }

  cancelHide() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
      this.hideTimeout = null
    }
  }

  // Escape, or a snapshot about to be cached: whatever was holding the tooltip open no longer is.
  forget() {
    this.isHovered = false
    this.isFocused = false
    this.cancelHide()
  }

  get overlay() {
    return this.application.getControllerForElementAndIdentifier(this.element, "ui--overlay")
  }

  // Active from opened until the exit animation has finished, however the tooltip was hidden.
  setAnchored(active) {
    const anchor = this.application.getControllerForElementAndIdentifier(this.element, "ui--anchor")
    if (anchor) anchor.activeValue = active
  }
}
