import { Controller } from "@hotwired/stimulus"
import { computePosition, flip, shift, offset } from "@floating-ui/dom"

export default class extends Controller {
  static targets = ["trigger", "content"]

  static values = {
    kind: { type: String, default: "menu" },
    placement: { type: String, default: "bottom-start" },
    offset: { type: Number, default: 4 },
    matchWidth: { type: Boolean, default: false },
    open: Boolean
  }

  connect() {
    this.openValue = false
    this.setupAccessibility()
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

    if (this.kindValue === "menu" || this.kindValue === "listbox") {
      setTimeout(() => this.focusFirstItem(), 10)
    }
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
    if (this.matchWidthValue) {
      this.contentTarget.style.width = `${this.triggerTarget.offsetWidth}px`
    }

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

  setupAccessibility() {
    const ariaPopupType = {
      menu: "menu",
      listbox: "listbox",
      dialog: "dialog"
    }[this.kindValue] || "menu"

    this.triggerTarget.setAttribute("aria-haspopup", ariaPopupType)
    this.triggerTarget.setAttribute("aria-expanded", "false")

    if (!this.contentTarget.hasAttribute("role")) {
      this.contentTarget.setAttribute("role", ariaPopupType)
    }
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

    if (this.kindValue === "menu" || this.kindValue === "listbox") {
      this.keyNavigationHandler = this.handleKeyNavigation.bind(this)
      this.contentTarget.addEventListener("keydown", this.keyNavigationHandler)
    }
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

    if (this.keyNavigationHandler) {
      this.contentTarget.removeEventListener("keydown", this.keyNavigationHandler)
      this.keyNavigationHandler = null
    }

    if (this.scrollHandler) {
      window.removeEventListener("scroll", this.scrollHandler, true)
      window.removeEventListener("resize", this.scrollHandler)
      this.scrollHandler = null
    }
  }

  handleKeyNavigation(event) {
    const items = this.getFocusableItems()
    if (items.length === 0) return

    const currentIndex = items.indexOf(document.activeElement)

    switch (event.key) {
      case "ArrowDown": {
        event.preventDefault()
        const nextIndex = currentIndex < items.length - 1 ? currentIndex + 1 : 0
        items[nextIndex]?.focus()
        break
      }
      case "ArrowUp": {
        event.preventDefault()
        const prevIndex = currentIndex > 0 ? currentIndex - 1 : items.length - 1
        items[prevIndex]?.focus()
        break
      }
      case "Home":
        event.preventDefault()
        items[0]?.focus()
        break
      case "End":
        event.preventDefault()
        items[items.length - 1]?.focus()
        break
      case "Enter":
      case " ":
        if (this.kindValue === "listbox") {
          event.preventDefault()
          document.activeElement.click()
        }
        break
    }
  }

  focusFirstItem() {
    const items = this.getFocusableItems()
    items[0]?.focus()
  }

  getFocusableItems() {
    const selector = this.kindValue === "menu"
      ? '[role="menuitem"]'
      : this.kindValue === "listbox"
        ? '[role="option"]'
        : 'a, button, input, select, textarea, [tabindex]:not([tabindex="-1"])'

    return Array.from(this.contentTarget.querySelectorAll(selector))
      .filter(item => !item.disabled && item.offsetParent !== null)
  }
}
