import { Controller } from "@hotwired/stimulus"
import { computePosition, flip, shift, offset } from "@floating-ui/dom"

export default class extends Controller {
  static targets = ["trigger", "content"]

  static values = {
    placement: { type: String, default: "top" },
    offset: { type: Number, default: 6 }
  }

  connect() {
    this.tooltipId = `ui-tooltip-${Math.random().toString(36).slice(2, 9)}`
    this.contentTarget.id = this.tooltipId
    this.contentTarget.setAttribute("role", "tooltip")
    this.triggerTarget.setAttribute("aria-describedby", this.tooltipId)
  }

  show() {
    this.position()
    this.contentTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.contentTarget.classList.remove("opacity-0")
      this.contentTarget.classList.add("opacity-100")
    })
  }

  hide() {
    this.contentTarget.classList.remove("opacity-100")
    this.contentTarget.classList.add("opacity-0")
    setTimeout(() => {
      this.contentTarget.classList.add("hidden")
    }, 100)
  }

  position() {
    computePosition(this.triggerTarget, this.contentTarget, {
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
}
