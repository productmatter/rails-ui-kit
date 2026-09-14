import { Controller } from "@hotwired/stimulus"

const FOCUSABLE = 'button, a[href], input, select, textarea, [tabindex]:not([tabindex="-1"])'

// A click can reach toggle() twice when the caller also wires click->ui--popover#toggle
// on their own control; the second call must not undo the first.
const toggledEvents = new WeakSet()

// ui--overlay on this element, in layer mode, owns showing, hiding, light dismiss, Escape,
// aria-expanded / aria-controls and focus return; ui--anchor owns geometry. What stays here is
// binding the click to the caller's control rather than the slot, and positioning only while
// the panel is rendered.
export default class extends Controller {
  static targets = ["trigger"]

  initialize() {
    this.onTriggerClick = (event) => {
      if (this.triggerControl.contains(event.target)) this.toggle(event)
    }
    this.onOpened = (event) => { if (event.target === this.element) this.setAnchored(true) }
    this.onClosed = (event) => { if (event.target === this.element) this.setAnchored(false) }
    this.onBeforeCache = () => this.setAnchored(false)
  }

  connect() {
    this.triggerControl.setAttribute("aria-haspopup", "dialog")

    this.triggerTarget.addEventListener("click", this.onTriggerClick)
    this.element.addEventListener("ui--overlay:opened", this.onOpened)
    this.element.addEventListener("ui--overlay:closed", this.onClosed)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    this.triggerTarget.removeEventListener("click", this.onTriggerClick)
    this.element.removeEventListener("ui--overlay:opened", this.onOpened)
    this.element.removeEventListener("ui--overlay:closed", this.onClosed)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  toggle(event) {
    if (event) {
      if (toggledEvents.has(event)) return
      toggledEvents.add(event)
    }
    this.overlay?.toggle(event)
  }

  open() {
    this.overlay?.open()
  }

  close() {
    this.overlay?.close()
  }

  // The trigger target wraps the caller's control, normally a <button>. Clicks and ARIA belong
  // on that control: the wrapping <div> is neither focusable nor announced, and in a block
  // layout it spans the full width. Falls back to the wrapper when it holds nothing focusable.
  get triggerControl() {
    if (this.triggerTarget.matches(FOCUSABLE)) return this.triggerTarget
    return this.triggerTarget.querySelector(FOCUSABLE) || this.triggerTarget
  }

  get overlay() {
    return this.application.getControllerForElementAndIdentifier(this.element, "ui--overlay")
  }

  // Active from opened until the exit animation has finished, however the panel was closed.
  setAnchored(active) {
    const anchor = this.application.getControllerForElementAndIdentifier(this.element, "ui--anchor")
    if (anchor) anchor.activeValue = active
  }
}
