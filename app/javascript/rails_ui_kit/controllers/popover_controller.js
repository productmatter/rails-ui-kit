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
    const controller = this.application.getControllerForElementAndIdentifier(this.element, "ui--overlay")
    if (!controller) this.warnMissingCompanion("ui--overlay", "opening, closing and dismissal do nothing")
    return controller
  }

  // Active from opened until the exit animation has finished, however the panel was closed.
  setAnchored(active) {
    const anchor = this.application.getControllerForElementAndIdentifier(this.element, "ui--anchor")
    if (!anchor) return this.warnMissingCompanion("ui--anchor", "positioning silently does nothing")
    anchor.activeValue = active
  }

  // Stimulus does not warn about a data-controller identifier that simply isn't present, so
  // markup missing "ui--overlay" or "ui--anchor" -- old copy-pasted markup predating the move
  // onto the shared primitives in 144d104, say -- still opens: it just silently keeps whatever
  // position it already had, or the trigger click does nothing at all, with nothing in the
  // console saying why. Warned once per identifier per instance; never thrown, since a missing
  // companion has to fail soft, not break Popover outright.
  warnMissingCompanion(identifier, consequence) {
    this.warnedMissingCompanions ||= new Set()
    if (this.warnedMissingCompanions.has(identifier)) return
    this.warnedMissingCompanions.add(identifier)

    console.warn(
      `ui--popover: no "${identifier}" controller found, so ${consequence}. ` +
      `Add "${identifier}" to this element's data-controller.`,
      this.element
    )
  }
}
