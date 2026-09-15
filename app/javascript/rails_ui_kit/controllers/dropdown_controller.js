import { Controller } from "@hotwired/stimulus"

const FOCUSABLE = 'button, a[href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
const MENU_ITEM = '[role="menuitem"], [role="menuitemcheckbox"], [role="menuitemradio"]'
// Ordinary host markup for a menu: links and buttons, which kind: :menu adopts as its items
// when the caller hasn't written the roles itself.
const MENU_ITEM_CANDIDATE = 'a[href], button:not([disabled])'
const ROVING_ITEM = "data-ui--roving-focus-target"
// Placement, offset and match-width lived on ui--dropdown itself before positioning moved
// to ui--anchor. Markup written against that version still carries these attribute names.
const LEGACY_ANCHOR_ATTRIBUTES = ["placement-value", "offset-value", "match-width-value"]

// A click can reach toggle() twice when the caller also wires click->ui--dropdown#toggle on their
// own control, as markup written before Dropdown bound its trigger does; the second call must not
// undo the first.
const toggledEvents = new WeakSet()

// ui--overlay on this element, in layer mode, owns showing and hiding (a popover="auto" in the top
// layer, animated through presence), light dismiss, Escape, aria-expanded / aria-controls and focus
// return, and its ui--overlay:opened|closed|dismiss events are Dropdown's events. ui--anchor owns
// geometry, and ui--roving-focus a menu's arrows, Home, End and typeahead. What stays here is what
// none of them does: binding the trigger, the menu button's own keys, role adoption, activation,
// where focus lands on open, and closing when focus leaves.
export default class extends Controller {
  static targets = ["trigger", "content"]

  static values = {
    kind: { type: String, default: "menu" }
  }

  initialize() {
    this.onTriggerClick = (event) => {
      if (this.triggerControl.contains(event.target)) this.toggle(event)
    }
    this.onKeydown = this.handleKeydown.bind(this)
    this.onFocusout = this.handleFocusout.bind(this)
    this.onContentClick = this.handleContentClick.bind(this)
    this.onOpened = (event) => { if (event.target === this.element) this.handleOpened() }
    this.onClosed = (event) => { if (event.target === this.element) this.handleClosed() }
    // ui--overlay resets itself for the snapshot, without a closed event.
    this.onBeforeCache = () => this.handleClosed()
  }

  connect() {
    this.forwardLegacyAnchorAttributes()
    this.setupAccessibility()
    this.triggerTarget.addEventListener("click", this.onTriggerClick)
    this.element.addEventListener("keydown", this.onKeydown)
    this.element.addEventListener("focusout", this.onFocusout)
    this.contentTarget.addEventListener("click", this.onContentClick)
    this.element.addEventListener("ui--overlay:opened", this.onOpened)
    this.element.addEventListener("ui--overlay:closed", this.onClosed)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    this.triggerTarget.removeEventListener("click", this.onTriggerClick)
    this.element.removeEventListener("keydown", this.onKeydown)
    this.element.removeEventListener("focusout", this.onFocusout)
    this.contentTarget.removeEventListener("click", this.onContentClick)
    this.element.removeEventListener("ui--overlay:opened", this.onOpened)
    this.element.removeEventListener("ui--overlay:closed", this.onClosed)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    this.initialFocus = null
  }

  // Reads the open value rather than ui--overlay's own toggle, which treats a press during the exit
  // animation as "stay closed": a menu chosen from and reopened straight away has to reopen.
  toggle(event) {
    if (event) {
      if (toggledEvents.has(event)) return
      toggledEvents.add(event)
      event.preventDefault()
    }

    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.overlay?.open()
  }

  close() {
    this.overlay?.close()
  }

  handleOpened() {
    this.prepareMenuItems()
    this.setAnchored(true)
    this.focusContent()
  }

  handleClosed() {
    this.initialFocus = null
    this.setAnchored(false)
  }

  get isOpen() {
    return this.overlayController?.openValue === true
  }

  // The trigger target wraps the caller's control, normally a <button>. Clicks, ARIA state and
  // focus belong on that control: a wrapping <div> is neither focusable nor announced with state,
  // and in a block layout it spans the full width. Falls back to the wrapper when it holds nothing
  // focusable.
  get triggerControl() {
    if (this.triggerTarget.matches(FOCUSABLE)) return this.triggerTarget
    return this.triggerTarget.querySelector(FOCUSABLE) || this.triggerTarget
  }

  get overlayController() {
    return this.application.getControllerForElementAndIdentifier(this.element, "ui--overlay")
  }

  get overlay() {
    const controller = this.overlayController
    if (!controller) this.warnMissingCompanion("ui--overlay", this.element, "opening, closing and dismissal do nothing")
    return controller
  }

  get rovingFocus() {
    const controller = this.application.getControllerForElementAndIdentifier(this.contentTarget, "ui--roving-focus")
    if (!controller) {
      this.warnMissingCompanion("ui--roving-focus", this.contentTarget, "arrow keys, Home, End and typeahead do nothing")
    }
    return controller
  }

  // Stimulus does not warn about a data-controller identifier that simply isn't present, so
  // markup missing "ui--overlay", "ui--anchor" or "ui--roving-focus" -- old copy-pasted markup
  // predating the move onto the shared primitives, say -- fails with nothing in the console saying
  // why. Warned once per identifier per instance, in the style of forwardLegacyAnchorAttributes
  // below; never thrown, since a missing companion has to fail soft, not break Dropdown outright.
  warnMissingCompanion(identifier, element, consequence) {
    this.warnedMissingCompanions ||= new Set()
    if (this.warnedMissingCompanions.has(identifier)) return
    this.warnedMissingCompanions.add(identifier)

    console.warn(
      `ui--dropdown: no "${identifier}" controller found, so ${consequence}. ` +
      `Add "${identifier}" to this element's data-controller.`,
      element
    )
  }

  // Positioned from opened until the exit animation has finished, however the panel was closed.
  // Written as the value so a snapshot taken on turbo:before-cache is cached inactive. A missing
  // anchor is only worth a warning when there is something to position: on connect, or on the way
  // out, ui--anchor may simply not have connected yet.
  setAnchored(active) {
    const anchor = this.application.getControllerForElementAndIdentifier(this.element, "ui--anchor")
    if (anchor) {
      anchor.activeValue = active
    } else if (active) {
      this.warnMissingCompanion("ui--anchor", this.element, "positioning silently does nothing")
    }
  }

  // Stimulus does not warn about an attribute for a value nobody declares any more, so a
  // caller still writing data-ui--dropdown-placement-value (etc.) after the move to
  // ui--anchor just silently stops positioning: the menu still opens, drawn wherever CSS
  // happens to leave it, and only misses badly near a viewport edge. Forward each legacy
  // attribute onto its ui--anchor equivalent -- unless the caller already set that one,
  // which wins -- and warn once so the markup gets updated.
  forwardLegacyAnchorAttributes() {
    LEGACY_ANCHOR_ATTRIBUTES.forEach((attribute) => {
      const legacyAttribute = `data-ui--dropdown-${attribute}`
      if (!this.element.hasAttribute(legacyAttribute)) return

      const anchorAttribute = `data-ui--anchor-${attribute}`
      const alreadySet = this.element.hasAttribute(anchorAttribute)
      if (!alreadySet) this.element.setAttribute(anchorAttribute, this.element.getAttribute(legacyAttribute))

      console.warn(
        `ui--dropdown: "${legacyAttribute}" is deprecated and no longer read by Dropdown; ` +
        `use "${anchorAttribute}" instead (positioning moved to ui--anchor).` +
        (alreadySet
          ? ` "${anchorAttribute}" is already set on this element, so the legacy attribute is ignored.`
          : ' The old attribute is forwarded automatically for now.'),
        this.element
      )
    })
  }

  setupAccessibility() {
    const ariaPopupType = {
      menu: "menu",
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

  // Bound to this element, so it only sees keys pressed while focus is inside the dropdown: on the
  // trigger or in the panel. Escape is ui--overlay's. In a menu, ui--roving-focus on the panel sees
  // each key first and cancels the ones it moves on.
  handleKeydown(event) {
    if (event.defaultPrevented || event.isComposing) return

    if (this.kindValue === "menu" && this.triggerTarget.contains(event.target)) {
      return this.handleTriggerKeydown(event)
    }

    if (!this.isOpen || this.kindValue !== "menu" || !this.contentTarget.contains(event.target)) return

    if (event.key === "Tab") {
      // Move focus to the trigger and close at once, without animating: the browser's own Tab
      // then moves on from the trigger, past items that are no longer rendered. Shift+Tab stops
      // on the trigger.
      this.triggerControl.focus()
      this.overlay?.closeNow()
      if (event.shiftKey) event.preventDefault()
      return
    }

    this.activateItem(event)
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

    if (this.isOpen) return this.focusMenuEnd(end)

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

  // A menu button closes as soon as focus leaves it. ui--overlay's light dismiss covers a press
  // outside, not focus moving away, so this asks it for the same vetoable dismissal.
  handleFocusout(event) {
    if (!this.isOpen || !event.relatedTarget) return
    if (!this.element.contains(event.relatedTarget)) this.overlay?.dismissFor("outside")
  }

  handleContentClick(event) {
    const item = event.target.closest('[role="menuitem"]')
    if (!this.isOpen || !item || !this.contentTarget.contains(item)) return
    // A disabled item is inert: it doesn't close the menu, and a disabled link doesn't navigate.
    if (!this.isEnabled(item)) return event.preventDefault()

    const focusWasInside = this.contentTarget.contains(document.activeElement)
    this.close()
    if (focusWasInside) this.triggerControl.focus()
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
    const selector = 'a, button, input, select, textarea, [tabindex]:not([tabindex="-1"])'

    return Array.from(this.contentTarget.querySelectorAll(selector))
      .filter(item => !item.disabled && item.offsetParent !== null)
  }
}
