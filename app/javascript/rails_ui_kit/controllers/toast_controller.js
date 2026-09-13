import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    enterFrom: Array,
    enterTo: Array,
    leaveFrom: Array,
    leaveTo: Array,
    selfDestruct: Number,
    type: String
  }

  static targets = ["timer", "title", "body"]

  connect() {
    this.element.classList.add(...this.enterFromValue)

    this.paused = false
    this.pointerOver = false
    this.focusWithin = false
    this.remainingValue = this.selfDestructValue

    this.announce()

    if (this.hasTimerTarget && this.selfDestructValue) {
      this.timerTarget.classList.remove("scale-x-0")
      this.timerTarget.classList.add("scale-x-100")
    }

    requestAnimationFrame(() => {
      this.fadeIn()

      if (this.hasTimerTarget && this.selfDestructValue) {
        requestAnimationFrame(() => {
          this.timerTarget.classList.remove("scale-x-100")
          this.timerTarget.classList.add("scale-x-0")
        })
      }
    })

    if (this.selfDestructValue) {
      this.armDismissTimer(this.selfDestructValue)
    }

    this.handlePointerEnter = () => {
      this.pointerOver = true
      this.updatePauseState()
    }
    this.handlePointerLeave = () => {
      this.pointerOver = false
      this.updatePauseState()
    }
    this.handleFocusIn = () => {
      this.focusWithin = true
      this.updatePauseState()
    }
    this.handleFocusOut = (event) => {
      if (event.relatedTarget && this.element.contains(event.relatedTarget)) return
      this.focusWithin = false
      this.updatePauseState()
    }

    this.element.addEventListener("mouseenter", this.handlePointerEnter)
    this.element.addEventListener("mouseleave", this.handlePointerLeave)
    this.element.addEventListener("focusin", this.handleFocusIn)
    this.element.addEventListener("focusout", this.handleFocusOut)
  }

  // Announce through the container's persistent polite/assertive live
  // regions (present on the page since it rendered, well before this toast
  // existed) rather than carrying a live-region role ourselves. Clearing
  // first, then writing a frame later, guarantees two distinct mutations so
  // a repeated identical message is announced again instead of silently
  // no-op'd.
  announce() {
    const region = this.liveRegion()
    const text = this.announcementText()
    if (!region || !text) return

    region.textContent = ""
    requestAnimationFrame(() => {
      region.textContent = text
    })
  }

  liveRegion() {
    const name = this.typeValue === "error" ? "assertiveRegion" : "politeRegion"
    return document.querySelector(`[data-ui--toast-container-target="${name}"]`)
  }

  announcementText() {
    const parts = []

    if (this.hasTitleTarget) {
      const title = this.titleTarget.textContent.trim()
      if (title) parts.push(title)
    }

    if (this.hasBodyTarget && !this.bodyTarget.classList.contains("hidden")) {
      const body = this.bodyTarget.textContent.trim()
      if (body) parts.push(body)
    }

    return parts.join(". ")
  }

  updatePauseState() {
    if (this.pointerOver || this.focusWithin) {
      this.pause()
    } else {
      this.resume()
    }
  }

  pause() {
    if (!this.selfDestructValue || this.paused) return
    this.paused = true

    if (this.dismissTimer) {
      clearTimeout(this.dismissTimer)
      this.dismissTimer = null
      const elapsed = Date.now() - this.dismissStartedAt
      this.remainingValue = Math.max(0, this.remainingValue - elapsed)
    }

    this.pauseTimerBar()
  }

  resume() {
    if (!this.selfDestructValue || !this.paused) return
    this.paused = false

    if (this.remainingValue <= 0) {
      this.close()
      return
    }

    this.armDismissTimer(this.remainingValue)
    this.resumeTimerBar(this.remainingValue)
  }

  armDismissTimer(duration) {
    this.dismissStartedAt = Date.now()
    this.dismissTimer = setTimeout(() => {
      this.close()
    }, duration)
  }

  pauseTimerBar() {
    if (!this.hasTimerTarget) return

    // Tailwind's scale-x-* utilities animate the CSS `scale` property (not
    // `transform`), so that's what we have to read and freeze.
    const scale = this.currentTimerScale()
    this.timerTarget.style.transitionDuration = "0ms"
    this.timerTarget.style.scale = `${scale} 1`
  }

  resumeTimerBar(duration) {
    if (!this.hasTimerTarget) return

    // Force a reflow so the frozen scale above is committed before we
    // animate again, otherwise the browser can coalesce the two style writes
    // and skip straight to the new target.
    void this.timerTarget.offsetWidth

    this.timerTarget.style.transitionDuration = `${duration}ms`
    requestAnimationFrame(() => {
      this.timerTarget.style.scale = "0 1"
    })
  }

  currentTimerScale() {
    if (!this.hasTimerTarget) return 0

    const scaleValue = window.getComputedStyle(this.timerTarget).scale
    if (!scaleValue || scaleValue === "none") return 0

    const parsed = parseFloat(scaleValue.split(" ")[0])
    return Number.isNaN(parsed) ? 0 : parsed
  }

  close() {
    if (this.dismissTimer) {
      clearTimeout(this.dismissTimer)
    }

    this.teardownPauseListeners()
    this.fadeOut()
  }

  fadeIn() {
    this.element.classList.remove(...this.enterFromValue)
    this.element.classList.add(...this.enterToValue)
  }

  fadeOut() {
    this.element.classList.remove(...this.leaveFromValue)
    this.element.classList.add(...this.leaveToValue)

    setTimeout(() => {
      this.element.remove()
    }, 500)
  }

  teardownPauseListeners() {
    this.element.removeEventListener("mouseenter", this.handlePointerEnter)
    this.element.removeEventListener("mouseleave", this.handlePointerLeave)
    this.element.removeEventListener("focusin", this.handleFocusIn)
    this.element.removeEventListener("focusout", this.handleFocusOut)
  }

  disconnect() {
    if (this.dismissTimer) {
      clearTimeout(this.dismissTimer)
    }

    this.teardownPauseListeners()
  }
}
