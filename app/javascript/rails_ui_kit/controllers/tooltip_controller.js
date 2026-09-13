import { Controller } from "@hotwired/stimulus"
import { computePosition, flip, shift, offset, arrow } from "@floating-ui/dom"

const FOCUSABLE = 'button, a[href], input, select, textarea, [tabindex]:not([tabindex="-1"])'

// Grace period after the pointer/focus leaves the control before the tooltip actually
// hides. Lets the pointer travel from the control onto the tooltip content itself, and
// absorbs a fast leave-then-enter without ever fully hiding.
const HIDE_GRACE_DELAY = 150
const HIDE_ANIMATION_DELAY = 100

export default class extends Controller {
  static targets = ["trigger", "content", "arrow"]

  static values = {
    placement: { type: String, default: "top" },
    offset: { type: Number, default: 6 }
  }

  connect() {
    this.isHovered = false
    this.isFocused = false
    this.hideTimeout = null
    this.hideAnimationTimeout = null

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
    this.onKeydown = (event) => this.handleKeydown(event)
    this.onBeforeCache = () => this.resetForCache()

    this.controlElement.addEventListener("mouseenter", this.onControlEnter)
    this.controlElement.addEventListener("mouseleave", this.onControlLeave)
    this.controlElement.addEventListener("focusin", this.onControlFocusIn)
    this.controlElement.addEventListener("focusout", this.onControlFocusOut)
    this.contentElement.addEventListener("mouseenter", this.onContentEnter)
    this.contentElement.addEventListener("mouseleave", this.onContentLeave)

    // Capture phase, ahead of any bubble-phase Escape handler (Modal, Dropdown, Popover)
    // that might sit between the focused/hovered element and document. Consuming the key
    // here guarantees the tooltip wins the keypress before an ancestor dialog can act on
    // it, regardless of where in the tree that ancestor's own listener lives.
    document.addEventListener("keydown", this.onKeydown, { capture: true })
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    this.cancelHide()
    this.cancelHideAnimation()

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

    document.removeEventListener("keydown", this.onKeydown, { capture: true })
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
    this.show()
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
      if (!this.isHovered && !this.isFocused) this.hide()
    }, HIDE_GRACE_DELAY)
  }

  cancelHide() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
      this.hideTimeout = null
    }
  }

  cancelHideAnimation() {
    if (this.hideAnimationTimeout) {
      clearTimeout(this.hideAnimationTimeout)
      this.hideAnimationTimeout = null
    }
  }

  handleKeydown(event) {
    if (event.key !== "Escape") return
    if (this.contentElement.classList.contains("hidden")) return

    // stopPropagation alone only blocks other listeners (e.g. Modal's closeOnEscape) from
    // running; it does nothing to the browser's own default action, which for a native
    // <dialog> is to close on Escape independent of any JS listener. preventDefault stops
    // that default so Escape dismisses only the tooltip, not a surrounding native dialog.
    event.stopPropagation()
    event.preventDefault()

    this.isHovered = false
    this.isFocused = false
    this.cancelHide()
    this.hide()
  }

  resetForCache() {
    this.cancelHide()
    this.cancelHideAnimation()
    this.isHovered = false
    this.isFocused = false
    this.contentElement.classList.remove("opacity-100")
    this.contentElement.classList.add("opacity-0", "hidden")
  }

  show() {
    this.cancelHideAnimation()
    this.position()
    this.contentElement.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.contentElement.classList.remove("opacity-0")
      this.contentElement.classList.add("opacity-100")
    })
  }

  hide() {
    this.contentElement.classList.remove("opacity-100")
    this.contentElement.classList.add("opacity-0")
    this.hideAnimationTimeout = setTimeout(() => {
      this.hideAnimationTimeout = null
      this.contentElement.classList.add("hidden")
    }, HIDE_ANIMATION_DELAY)
  }

  position() {
    const arrowEl = this.arrowTarget

    computePosition(this.controlElement, this.contentElement, {
      placement: this.placementValue,
      middleware: [
        offset(this.offsetValue),
        flip(),
        shift({ padding: 8 }),
        arrow({ element: arrowEl })
      ]
    }).then(({ x, y, placement, middlewareData }) => {
      Object.assign(this.contentElement.style, {
        left: `${x}px`,
        top: `${y}px`
      })

      const { x: arrowX, y: arrowY } = middlewareData.arrow
      const staticSide = { top: 'bottom', right: 'left', bottom: 'top', left: 'right' }[placement.split('-')[0]]

      Object.assign(arrowEl.style, {
        left: arrowX != null ? `${arrowX}px` : '',
        top: arrowY != null ? `${arrowY}px` : '',
        right: '',
        bottom: '',
        [staticSide]: '-4px'
      })
    })
  }
}
