import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    enterFrom: Array,
    enterTo: Array,
    leaveFrom: Array,
    leaveTo: Array,
    selfDestruct: Number
  }

  static targets = ["timer", "title", "body"]

  connect() {
    this.element.classList.add(...this.enterFromValue)

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
      this.dismissTimer = setTimeout(() => {
        this.close()
      }, this.selfDestructValue)
    }
  }

  close() {
    if (this.dismissTimer) {
      clearTimeout(this.dismissTimer)
    }

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

  disconnect() {
    if (this.dismissTimer) {
      clearTimeout(this.dismissTimer)
    }
  }
}
