import { Controller } from "@hotwired/stimulus"
import * as presence from "rails_ui_kit/overlay/presence"

const REDUCED_MOTION = "(prefers-reduced-motion: reduce)"

// One toast: its announcement, its countdown and its exit (ui-toast § Behavior, items 10, 13, 14).
//
// The markup is Ui::ToastComponent's, whichever entry point put it here, so this controller writes
// no class. Enter and exit are Primitive D's; the countdown is the only timer, and it pauses while
// the pointer is over the toast, while focus is inside it, and while the page is hidden.
export default class extends Controller {
  static values = { type: String, duration: Number }
  static targets = ["timer", "title", "description", "actions"]

  connect() {
    this.pointerOver = false
    this.focusWithin = false
    this.remaining = this.durationValue
    this.closing = false

    this.onPointerEnter = () => { this.pointerOver = true; this.updatePause() }
    this.onPointerLeave = () => { this.pointerOver = false; this.updatePause() }
    this.onFocusIn = () => { this.focusWithin = true; this.updatePause() }
    this.onFocusOut = (event) => {
      if (event.relatedTarget && this.element.contains(event.relatedTarget)) return
      this.focusWithin = false
      this.updatePause()
    }
    this.onVisibilityChange = () => this.updatePause()

    this.element.addEventListener("mouseenter", this.onPointerEnter)
    this.element.addEventListener("mouseleave", this.onPointerLeave)
    this.element.addEventListener("focusin", this.onFocusIn)
    this.element.addEventListener("focusout", this.onFocusOut)
    document.addEventListener("visibilitychange", this.onVisibilityChange)

    presence.enter(this.element)
    this.announce()
    if (this.countsDown) this.updatePause()
  }

  disconnect() {
    this.stopCountdown()
    this.element.removeEventListener("mouseenter", this.onPointerEnter)
    this.element.removeEventListener("mouseleave", this.onPointerLeave)
    this.element.removeEventListener("focusin", this.onFocusIn)
    this.element.removeEventListener("focusout", this.onFocusOut)
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
  }

  get countsDown() {
    return this.durationValue > 0
  }

  get container() {
    const element = this.element.closest('[data-controller~="ui--toast-container"]')
    return element && this.application.getControllerForElementAndIdentifier(element, "ui--toast-container")
  }

  // --- Announcement ------------------------------------------------------------------------

  // Once, into the container's persistent live region for this type: title, description, and the
  // hint when there are actions to reach. Cleared first and written a frame later, so a repeat of
  // the same words is announced again. Nothing else is ever announced (§ Behavior, item 13).
  announce() {
    const name = this.typeValue === "error" ? "assertiveRegion" : "politeRegion"
    const region = document.querySelector(`[data-ui--toast-container-target="${name}"]`)
    if (!region) return this.warnMissingLiveRegion(name)

    const text = this.announcementText()
    if (!text) return

    region.textContent = ""
    requestAnimationFrame(() => { region.textContent = text })
  }

  announcementText() {
    const parts = []
    if (this.hasTitleTarget) parts.push(this.titleTarget.textContent.trim())
    if (this.hasDescriptionTarget) parts.push(this.descriptionTarget.textContent.trim())

    const words = parts.filter(Boolean).join(". ")
    const hint = this.hasActions ? this.container?.actionsHintValue : ""
    if (!hint) return words

    return words ? `${words}${/[.!?]$/.test(words) ? " " : ". "}${hint}` : hint
  }

  get hasActions() {
    return this.hasActionsTarget && this.actionsTarget.children.length > 0
  }

  // A missing live region means every toast is silently never announced, while looking normal to
  // everyone else. Warned once per container, which outlives any one toast.
  warnMissingLiveRegion(name) {
    const owner = this.container || this
    if (owner.warnedMissingLiveRegion) return
    owner.warnedMissingLiveRegion = true

    console.warn(
      `ui--toast: no [data-ui--toast-container-target="${name}"] found, so toasts will not ` +
      "be announced to screen readers. Render Ui::ToastContainerComponent instead of " +
      "hand-rolled toast container markup."
    )
  }

  // --- Countdown ---------------------------------------------------------------------------

  updatePause() {
    if (!this.countsDown || this.closing) return

    const paused = this.pointerOver || this.focusWithin || document.visibilityState === "hidden"
    paused ? this.pause() : this.resume()
  }

  resume() {
    if (this.running) return
    if (this.remaining <= 0) return this.close()

    this.running = true
    this.startedAt = Date.now()
    this.dismissTimer = setTimeout(() => this.close(), this.remaining)
    this.runBar()
  }

  pause() {
    if (!this.running) return

    this.remaining = Math.max(0, this.remaining - (Date.now() - this.startedAt))
    this.stopCountdown()
    this.setBar(this.remaining / this.durationValue)
  }

  stopCountdown() {
    this.running = false
    clearTimeout(this.dismissTimer)
    clearInterval(this.stepTimer)
    this.dismissTimer = null
    this.stepTimer = null
  }

  // The bar shows the time left. With reduced motion it has no transition, and steps to the
  // remaining fraction once a second instead; the dismissal timing is the same either way.
  runBar() {
    if (!this.hasTimerTarget) return

    const fraction = this.remaining / this.durationValue
    if (window.matchMedia(REDUCED_MOTION).matches) {
      this.setBar(fraction)
      this.stepTimer = setInterval(() => {
        const left = Math.max(0, this.remaining - (Date.now() - this.startedAt))
        this.setBar(left / this.durationValue)
      }, 1000)
      return
    }

    this.setBar(fraction)
    void this.timerTarget.offsetWidth // commits the start, so the transition runs from it
    this.timerTarget.style.transition = `scale ${this.remaining}ms linear`
    this.timerTarget.style.scale = "0 1"
  }

  setBar(fraction) {
    if (!this.hasTimerTarget) return

    this.timerTarget.style.transition = "none"
    this.timerTarget.style.scale = `${fraction} 1`
  }

  // --- Dismissal ---------------------------------------------------------------------------

  // An action that dismisses closes the toast after its click has reached Turbo's document
  // listeners, so the link is followed and the form submitted before the element leaves.
  activate(event) {
    if (event.params.dismiss === false) return
    setTimeout(() => this.close())
  }

  dismissOnEscape(event) {
    if (event.key !== "Escape" || event.defaultPrevented) return

    // Taken, so a Modal or anything else listening for Escape knows it was handled.
    event.preventDefault()
    this.close()
  }

  close() {
    if (this.closing) return
    this.closing = true
    this.stopCountdown()

    // Focus never waits in an element that is animating out.
    if (this.element.contains(document.activeElement)) this.container?.restoreFocus(this.element)
    presence.exit(this.element).then(() => this.element.remove())
  }
}
