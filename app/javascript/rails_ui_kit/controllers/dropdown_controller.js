import { Controller } from "@hotwired/stimulus"

const FOCUSABLE = 'button, a[href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
const MENU_ITEM = '[role="menuitem"], [role="menuitemcheckbox"], [role="menuitemradio"]'
// Ordinary host markup for a menu: links and buttons, which kind: :menu adopts as its items
// when the caller hasn't written the roles itself.
const MENU_ITEM_CANDIDATE = 'a[href], button:not([disabled])'
const ROVING_ITEM = "data-ui--roving-focus-target"

// Geometry belongs to ui--anchor on this element, and a menu's arrows, Home, End and typeahead to
// ui--roving-focus on its content. What stays here is what neither primitive does: opening and
// closing, ARIA on the trigger, role adoption, activation, and Escape, Tab and focusout.
export default class extends Controller {
  static targets = ["trigger", "content"]

  static values = {
    kind: { type: String, default: "menu" },
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

    this.contentTarget.classList.remove("hidden")
    this.setAnchored(true)
    this.frame = requestAnimationFrame(() => {
      this.contentTarget.classList.remove("opacity-0", "scale-95")
      this.contentTarget.classList.add("opacity-100", "scale-100")
    })

    this.triggerControl.setAttribute("aria-expanded", "true")

    this.setupListeners()
    this.focusContent()
  }

  hide() {
    if (!this.shown) return
    this.shown = false
    this.initialFocus = null
    this.cancelPending()
    this.cleanup()
    this.setAnchored(false)

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
    this.setAnchored(false)

    this.contentTarget.classList.remove("opacity-100", "scale-100")
    this.contentTarget.classList.add("hidden", "opacity-0", "scale-95")
    this.triggerControl.setAttribute("aria-expanded", "false")

    if (this.openValue) this.openValue = false
  }

  // The trigger target wraps the caller's control, normally a <button>. ARIA state and focus
  // belong on that control: a wrapping <div> is neither focusable nor announced with state, and
  // in a block layout it spans the full width. Falls back to the wrapper when it holds nothing
  // focusable.
  get triggerControl() {
    if (this.triggerTarget.matches(FOCUSABLE)) return this.triggerTarget
    return this.triggerTarget.querySelector(FOCUSABLE) || this.triggerTarget
  }

  get anchor() {
    return this.application.getControllerForElementAndIdentifier(this.element, "ui--anchor")
  }

  get rovingFocus() {
    return this.application.getControllerForElementAndIdentifier(this.contentTarget, "ui--roving-focus")
  }

  // Positioned only while shown. Written as the value so an anchor that connects later still
  // reads it, and so a snapshot taken on turbo:before-cache is cached inactive.
  setAnchored(active) {
    const anchor = this.anchor
    if (anchor) anchor.activeValue = active
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

  // Markup that carries no menu roles -- plain links and buttons, which is what a host app
  // usually writes -- is adopted as the items, so it navigates like a menu rather than not at
  // all. Every item becomes a ui--roving-focus item, which keeps the menu a single tab stop.
  // Runs on connect and on every open, so content swapped in later (a lazy Turbo frame, say) is
  // picked up too.
  prepareMenuItems() {
    if (this.kindValue !== "menu") return

    let items = Array.from(this.contentTarget.querySelectorAll(MENU_ITEM))

    if (items.length === 0) {
      items = Array.from(this.contentTarget.querySelectorAll(MENU_ITEM_CANDIDATE))
      items.forEach(item => item.setAttribute("role", "menuitem"))
    }

    items.forEach(item => { if (!item.hasAttribute(ROVING_ITEM)) item.setAttribute(ROVING_ITEM, "item") })
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
  }

  cancelPending() {
    clearTimeout(this.hideTimer)
    clearTimeout(this.listenTimer)
    cancelAnimationFrame(this.frame)
  }

  // Bound to this element, so it only sees keys pressed while focus is inside the dropdown:
  // on the trigger or in the content. Escape never pulls focus back from elsewhere. In a menu,
  // ui--roving-focus on the content sees each key first and cancels the ones it moves on.
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

    if (this.kindValue === "menu") return this.activateItem(event)

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

    if (this.shown) return this.focusMenuEnd(end)

    this.initialFocus = end
    this.open()
  }

  // Space activates the focused item. A link or button already activates itself on Enter --
  // including Ctrl/Cmd+Enter to open in a new tab -- so that is left alone; Space, and Enter on
  // anything that isn't natively activatable, is clicked from here. Choosing an item closes the
  // menu through the content click handler. A disabled item takes focus but never activates:
  // ui--roving-focus cancels the key before it arrives here, which also stops a disabled link
  // following its href on Enter.
  activateItem(event) {
    if (event.key !== "Enter" && event.key !== " ") return
    if (event.altKey || event.ctrlKey || event.metaKey) return

    const item = event.target.closest(MENU_ITEM)
    if (!item || !this.contentTarget.contains(item)) return

    if (!this.isEnabled(item)) return event.preventDefault()
    if (event.key === "Enter" && item.matches("a[href], button")) return

    event.preventDefault()
    item.click()
  }

  // Revealed before this runs: ui--roving-focus only moves to items that are rendered.
  focusMenuEnd(end) {
    const rovingFocus = this.rovingFocus
    if (!rovingFocus) return

    if (end === "last") {
      rovingFocus.focusLast()
    } else {
      rovingFocus.focusFirst()
    }
  }

  focusEnd(end) {
    const items = this.getFocusableItems()
    const item = end === "last" ? items[items.length - 1] : items[0]
    item?.focus()
  }

  isEnabled(item) {
    return item.getAttribute("aria-disabled") !== "true"
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

    if (this.kindValue === "menu") return this.focusMenuEnd(end)
    if (this.getFocusableItems().length > 0) return this.focusEnd(end)

    if (this.kindValue === "dialog") {
      if (!this.contentTarget.hasAttribute("tabindex")) this.contentTarget.setAttribute("tabindex", "-1")
      this.contentTarget.focus()
    }
  }

  getFocusableItems() {
    const selector = this.kindValue === "listbox"
      ? '[role="option"]'
      : 'a, button, input, select, textarea, [tabindex]:not([tabindex="-1"])'

    return Array.from(this.contentTarget.querySelectorAll(selector))
      .filter(item => !item.disabled && item.offsetParent !== null)
  }
}
