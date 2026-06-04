import { Controller } from "@hotwired/stimulus"
import { computePosition, flip, shift, offset } from "@floating-ui/dom"

export default class extends Controller {
  static targets = ["trigger", "content"]

  static values = {
    placement: { type: String, default: "bottom" },
    offset: { type: Number, default: 8 },
    open: Boolean
  }

  connect() {
    this.openValue = false
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.triggerTarget.setAttribute("aria-haspopup", "true")
  }

  disconnect() {
    this.cleanup()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  openValueChanged() {
    if (this.openValue) {
      this.show()
    } else {
      this.hide()
    }
  }

  show() {
    this.position()

    this.contentTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.contentTarget.classList.remove("opacity-0", "scale-95")
      this.contentTarget.classList.add("opacity-100", "scale-100")
    })

    this.triggerTarget.setAttribute("aria-expanded", "true")

    this.setupListeners()

    this.scrollHandler = () => this.position()
    window.addEventListener("scroll", this.scrollHandler, true)
    window.addEventListener("resize", this.scrollHandler)
  }

  hide() {
    this.contentTarget.classList.remove("opacity-100", "scale-100")
    this.contentTarget.classList.add("opacity-0", "scale-95")

    setTimeout(() => {
      this.contentTarget.classList.add("hidden")
    }, 100)

    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.cleanup()
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

  setupListeners() {
    this.clickOutsideHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this.close()
      }
    }
    setTimeout(() => {
      document.addEventListener("click", this.clickOutsideHandler)
    }, 10)

    this.escapeHandler = (event) => {
      if (event.key === "Escape") {
        this.close()
        this.triggerTarget.focus()
      }
    }
    document.addEventListener("keydown", this.escapeHandler)
  }

  cleanup() {
    if (this.clickOutsideHandler) {
      document.removeEventListener("click", this.clickOutsideHandler)
      this.clickOutsideHandler = null
    }

    if (this.escapeHandler) {
      document.removeEventListener("keydown", this.escapeHandler)
      this.escapeHandler = null
    }

    if (this.scrollHandler) {
      window.removeEventListener("scroll", this.scrollHandler, true)
      window.removeEventListener("resize", this.scrollHandler)
      this.scrollHandler = null
    }
  }
}
