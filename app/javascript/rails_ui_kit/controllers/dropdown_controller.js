import { Controller } from "@hotwired/stimulus"
import { computePosition, flip, shift, offset } from "@floating-ui/dom"

const FOCUSABLE = 'button, a[href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
const MENU_ITEM = '[role="menuitem"], [role="menuitemcheckbox"], [role="menuitemradio"]'
// Ordinary host markup for a menu: links and buttons, which kind: :menu adopts as its items
// when the caller hasn't written the roles itself.
const MENU_ITEM_CANDIDATE = 'a[href], button:not([disabled])'
const TYPEAHEAD_TIMEOUT = 500

export default class extends Controller {
  static targets = ["trigger", "content"]

  static values = {
    kind: { type: String, default: "menu" },
    placement: { type: String, default: "bottom-start" },
    offset: { type: Number, default: 4 },
    matchWidth: { type: Boolean, default: false },
    open: Boolean
  }

  initialize() {
    this.onKeydown = this.handleKeydown.bind(this)
    this.onFocusout = this.handleFocusout.bind(this)
    this.onContentClick = this.handleContentClick.bind(this)
    this.onBeforeCache = () => this.reset()
  }

  connect() {
    this.setupAccessibility()
    this.reset()
    this.element.addEventListener("keydown", this.onKeydown)
    this.element.addEventListener("focusout", this.onFocusout)
    this.contentTarget.addEventListener("click", this.onContentClick)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
    this.connected = true
  }

  disconnect() {
    this.connected = false
    this.element.removeEventListener("keydown", this.onKeydown)
    this.element.removeEventListener("focusout", this.onFocusout)
    this.contentTarget.removeEventListener("click", this.onContentClick)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    this.reset()
  }

  toggle(event) {
    event?.preventDefault()
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  // Stimulus replays a stored open-value before connect(), which is how a page restored
  // from Turbo's cache used to reopen the menu and pull focus into it. Only act once connected.
  openValueChanged() {
    if (!this.connected) return

    if (this.openValue) {
      this.show()
    } else {
      this.hide()
    }
  }

  show() {
    if (this.shown) return
    this.shown = true
    this.cancelPending()

    this.prepareMenuItems()
    this.position()

    this.contentTarget.classList.remove("hidden")
    this.frame = requestAnimationFrame(() => {
      this.contentTarget.classList.remove("opacity-0", "scale-95")
      this.contentTarget.classList.add("opacity-100", "scale-100")
    })

    this.triggerControl.setAttribute("aria-expanded", "true")

    this.setupListeners()
    this.focusTimer = setTimeout(() => this.focusContent(), 10)
  }

  hide() {
    if (!this.shown) return
    this.shown = false
    this.initialFocus = null
    this.cancelPending()
    this.cleanup()

    this.contentTarget.classList.remove("opacity-100", "scale-100")
    this.contentTarget.classList.add("opacity-0", "scale-95")
    this.hideTimer = setTimeout(() => {
      this.contentTarget.classList.add("hidden")
    }, 100)

    this.triggerControl.setAttribute("aria-expanded", "false")
  }

  // The closed resting state, applied at once: no animation, no pending timers or frames,
  // no open-state listeners. Runs on connect, on disconnect and on turbo:before-cache, so
  // the cached snapshot is always closed.
  reset() {
    this.shown = false
    this.initialFocus = null
    this.cancelPending()
    this.cleanup()

    this.contentTarget.classList.remove("opacity-100", "scale-100")
    this.contentTarget.classList.add("hidden", "opacity-0", "scale-95")
    this.triggerControl.setAttribute("aria-expanded", "false")

    if (this.openValue) this.openValue = false
  }

  // The trigger target wraps the caller's control, normally a <button>. ARIA state, focus
  // and positioning belong on that control: a wrapping <div> is neither focusable nor
  // announced with state, and in a block layout it spans the full width. Falls back to the
  // wrapper when it holds nothing focusable.
  get triggerControl() {
    if (this.triggerTarget.matches(FOCUSABLE)) return this.triggerTarget
    return this.triggerTarget.querySelector(FOCUSABLE) || this.triggerTarget
  }

  position() {
    const reference = this.triggerControl

    if (this.matchWidthValue) {
      this.contentTarget.style.width = `${reference.offsetWidth}px`
    }

    computePosition(reference, this.contentTarget, {
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

    this.triggerControl.setAttribute("aria-haspopup", ariaPopupType)
    this.triggerControl.setAttribute("aria-expanded", "false")

    if (!this.contentTarget.hasAttribute("role")) {
      this.contentTarget.setAttribute("role", ariaPopupType)
    }

    this.prepareMenuItems()
  }

  // A menu is one tab stop: the trigger. Its items are reached with the arrow keys and take
  // focus from script only, so Tab never walks through them. Markup that carries no menu roles
  // -- plain links and buttons, which is what a host app usually writes -- is adopted as the
  // items, so it navigates like a menu rather than not at all. Runs on connect and on every
  // open, so content swapped in later (a lazy Turbo frame, say) is picked up too.
  prepareMenuItems() {
    if (this.kindValue !== "menu") return

    let items = Array.from(this.contentTarget.querySelectorAll(MENU_ITEM))

    if (items.length === 0) {
      items = Array.from(this.contentTarget.querySelectorAll(MENU_ITEM_CANDIDATE))
      items.forEach(item => item.setAttribute("role", "menuitem"))
    }

    items.forEach(item => item.setAttribute("tabindex", "-1"))
  }

  setupListeners() {
    // Registered after the current click finishes dispatching, so a click that opened the
    // menu from outside this element (an outlet, say) doesn't close it straight away.
    this.clickOutsideHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this.close()
      }
    }
    this.listenTimer = setTimeout(() => {
      document.addEventListener("click", this.clickOutsideHandler)
    }, 0)

    this.documentKeydownHandler = (event) => {
      const active = document.activeElement
      if (event.key === "Escape" && (!active || active === document.body)) this.closeOnEscape(event)
    }
    document.addEventListener("keydown", this.documentKeydownHandler)

    this.scrollHandler = () => this.position()
    window.addEventListener("scroll", this.scrollHandler, true)
    window.addEventListener("resize", this.scrollHandler)
  }

  cleanup() {
    if (this.clickOutsideHandler) {
      document.removeEventListener("click", this.clickOutsideHandler)
      this.clickOutsideHandler = null
    }

    if (this.documentKeydownHandler) {
      document.removeEventListener("keydown", this.documentKeydownHandler)
      this.documentKeydownHandler = null
    }

    if (this.scrollHandler) {
      window.removeEventListener("scroll", this.scrollHandler, true)
      window.removeEventListener("resize", this.scrollHandler)
      this.scrollHandler = null
    }
  }

  cancelPending() {
    clearTimeout(this.hideTimer)
    clearTimeout(this.focusTimer)
    clearTimeout(this.listenTimer)
    clearTimeout(this.typeaheadTimer)
    cancelAnimationFrame(this.frame)
    this.typeahead = ""
  }

  // Bound to this element, so it only sees keys pressed while focus is inside the dropdown:
  // on the trigger or in the content. Escape never pulls focus back from elsewhere.
  handleKeydown(event) {
    if (event.key === "Escape") return this.closeOnEscape(event)
    if (event.defaultPrevented || event.isComposing) return

    if (this.kindValue === "menu" && this.triggerTarget.contains(event.target)) {
      return this.handleTriggerKeydown(event)
    }

    if (!this.shown) return
    if (this.kindValue === "dialog" || !this.contentTarget.contains(event.target)) return

    if (event.key === "Tab") {
      // Move focus to the trigger and hide at once, without animating: the browser's own Tab
      // then moves on from the trigger, past the hidden items. Shift+Tab stops on the trigger.
      this.triggerControl.focus()
      this.reset()
      if (event.shiftKey) event.preventDefault()
      return
    }

    if (this.kindValue === "menu") return this.handleMenuKeydown(event)

    this.handleKeyNavigation(event)
  }

  // Menu button keys, pressed on the trigger. Enter and Space reach the trigger's own click
  // handler and open it the way a mouse does; the arrows have no default of their own here
  // (ArrowDown would scroll the page), so they open the menu themselves and say which end to
  // focus. While the menu is already open they just move focus into it.
  handleTriggerKeydown(event) {
    if (event.altKey || event.ctrlKey || event.metaKey) return

    const end = { ArrowDown: "first", ArrowUp: "last" }[event.key]
    if (!end) return

    event.preventDefault()

    if (this.shown) return this.focusEnd(end)

    this.initialFocus = end
    this.open()
  }

  handleMenuKeydown(event) {
    if (event.altKey || event.ctrlKey || event.metaKey) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        return this.moveFocus(1)
      case "ArrowUp":
        event.preventDefault()
        return this.moveFocus(-1)
      case "Home":
        event.preventDefault()
        return this.focusEnd("first")
      case "End":
        event.preventDefault()
        return this.focusEnd("last")
      case "Enter":
      case " ":
        return this.activateItem(event)
      default:
        if (event.key.length === 1) this.typeaheadTo(event)
    }
  }

  // Enter and Space activate the focused item. A link or button already activates itself on
  // Enter -- including Ctrl/Cmd+Enter to open in a new tab -- so that is left alone; Space, and
  // anything that isn't natively activatable, is clicked from here. Choosing an item closes the
  // menu through the content click handler. A disabled item takes focus but never activates:
  // cancelling the keydown also stops a disabled link following its href on Enter.
  activateItem(event) {
    const item = event.target.closest(MENU_ITEM)
    if (!item || !this.contentTarget.contains(item)) return

    if (!this.isEnabled(item)) return event.preventDefault()
    if (event.key === "Enter" && item.matches("a[href], button")) return

    event.preventDefault()
    item.click()
  }

  // Printable characters move to the next item whose name starts with what's been typed. The
  // buffer holds for half a second, so "du" reaches Duplicate rather than stopping at Delete.
  typeaheadTo(event) {
    clearTimeout(this.typeaheadTimer)
    this.typeahead = (this.typeahead || "") + event.key.toLowerCase()
    this.typeaheadTimer = setTimeout(() => { this.typeahead = "" }, TYPEAHEAD_TIMEOUT)

    const items = this.menuItems
    if (items.length === 0) return

    // A single character searches from the item after the focused one, so repeating it steps
    // through the items that share an initial; further characters refine from the current one.
    const from = items.indexOf(document.activeElement) + (this.typeahead.length > 1 ? 0 : 1)

    for (let step = 0; step < items.length; step++) {
      const item = items[(from + step + items.length) % items.length]
      if (this.itemLabel(item).startsWith(this.typeahead)) {
        event.preventDefault()
        return item.focus()
      }
    }
  }

  // Steps to the next or previous item, wrapping at both ends.
  moveFocus(step) {
    const items = this.menuItems
    if (items.length === 0) return

    const index = items.indexOf(document.activeElement)
    const from = index === -1 && step < 0 ? items.length : index
    items[(from + step + items.length) % items.length].focus()
  }

  focusEnd(end) {
    const items = this.getFocusableItems()
    const item = end === "last" ? items[items.length - 1] : items[0]
    item?.focus()
  }

  itemLabel(item) {
    return (item.getAttribute("aria-label") || item.textContent || "").trim().toLowerCase()
  }

  isEnabled(item) {
    return item.getAttribute("aria-disabled") !== "true"
  }

  // Every item, aria-disabled ones included: per the APG, a disabled menu item stays focusable
  // so it can be discovered, and only activation is refused.
  get menuItems() {
    return Array.from(this.contentTarget.querySelectorAll(MENU_ITEM))
      .filter(item => !item.disabled && item.offsetParent !== null)
  }

  // Escape reaches this from two paths that never overlap: the element listener while focus
  // is inside, and the document listener while nothing has focus (a click on plain text in the
  // content leaves focus on <body>). preventDefault() marks it handled for everyone after.
  closeOnEscape(event) {
    if (!this.shown || event.defaultPrevented || event.isComposing) return

    event.preventDefault()
    this.close()
    this.triggerControl.focus()
  }

  handleFocusout(event) {
    if (!this.shown || !event.relatedTarget) return
    if (!this.element.contains(event.relatedTarget)) this.close()
  }

  handleContentClick(event) {
    const item = event.target.closest('[role="menuitem"]')
    if (!this.shown || !item || !this.contentTarget.contains(item)) return
    // A disabled item is inert: it doesn't close the menu, and a disabled link doesn't navigate.
    if (!this.isEnabled(item)) return event.preventDefault()

    const focusWasInside = this.contentTarget.contains(document.activeElement)
    this.close()
    if (focusWasInside) this.triggerControl.focus()
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

  focusContent() {
    // ArrowUp on the closed trigger asks for the last item; everything else opens on the first.
    const end = this.initialFocus || "first"
    this.initialFocus = null

    if (this.getFocusableItems().length > 0) return this.focusEnd(end)

    if (this.kindValue === "dialog") {
      if (!this.contentTarget.hasAttribute("tabindex")) this.contentTarget.setAttribute("tabindex", "-1")
      this.contentTarget.focus()
    }
  }

  getFocusableItems() {
    if (this.kindValue === "menu") return this.menuItems

    const selector = this.kindValue === "listbox"
      ? '[role="option"]'
      : 'a, button, input, select, textarea, [tabindex]:not([tabindex="-1"])'

    return Array.from(this.contentTarget.querySelectorAll(selector))
      .filter(item => !item.disabled && item.offsetParent !== null)
  }
}
