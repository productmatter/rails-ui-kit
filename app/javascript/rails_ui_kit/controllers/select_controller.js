import { Controller } from "@hotwired/stimulus"

// Select. The real <select> is the only place the value lives: this controller mirrors it into
// a combobox and a listbox, and writes it back when the user chooses. It owns nothing a
// primitive already does -- ui--overlay places and dismisses the popup, ui--anchor positions it,
// ui--roving-focus moves the active option -- so what is left here is the mirror, the key table
// for each mode, and the commit.
//
//   <div data-controller="ui--select ui--overlay ui--anchor ui--roving-focus">
//     <select data-ui--select-target="select">…</select>
//     <div role="combobox" data-ui--select-target="combobox">…</div>
//     <div data-ui--select-target="popup">…</div>
//   </div>
//
// Events: none of its own. Choosing dispatches `input` and `change` from the select, which is
// what a host's change-> action, ui--form-change and an auto-submitting form already listen for.
const OPTION = '[role="option"]'

export default class extends Controller {
  static targets = ["select", "combobox", "label", "popup"]

  static values = {
    search: { type: Boolean, default: false },
    // The platform picker beats anything we can draw on a phone, and the unenhanced select is
    // already the no-JavaScript path, so select-only mode leaves it alone on a coarse pointer
    // (ui-select open-questions.md). Search mode always enhances: no native picker searches.
    nativeOnTouch: { type: Boolean, default: true }
  }

  initialize() {
    this.typed = []
    this.onSelectFocus = this.forwardFocus.bind(this)
    this.onFormReset = this.restoreAfterReset.bind(this)
    this.onBeforeCache = () => this.rest()
    this.onMorph = this.renderFromMorph.bind(this)
    this.onMediaChange = () => this.applyEnhancement()
  }

  connect() {
    this.selectTarget.addEventListener("focus", this.onSelectFocus)
    this.element.addEventListener("ui--media-query:change", this.onMediaChange)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
    document.addEventListener("turbo:morph-element", this.onMorph)
    this.form?.addEventListener("reset", this.onFormReset)

    this.applyEnhancement()
    this.render()
  }

  disconnect() {
    this.selectTarget.removeEventListener("focus", this.onSelectFocus)
    this.element.removeEventListener("ui--media-query:change", this.onMediaChange)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    document.removeEventListener("turbo:morph-element", this.onMorph)
    this.form?.removeEventListener("reset", this.onFormReset)
    clearTimeout(this.resetTimer)
  }

  // --- enhancement -------------------------------------------------------------------------

  // Enhanced and unenhanced are the same box, and the select keeps rendering either way, laid
  // over the combobox: a browser cannot focus an invalid control it does not render, so a
  // display:none or inert select with `required` would block submission with nothing to show
  // for it.
  applyEnhancement() {
    const enhance = !this.nativeOnly
    this.element.dataset.enhanced = enhance ? "true" : "false"

    this.comboboxTarget.toggleAttribute("hidden", !enhance)
    this.selectTarget.setAttribute("aria-hidden", enhance ? "true" : "false")
    if (enhance) {
      this.selectTarget.setAttribute("tabindex", "-1")
      this.nameCombobox()
    } else {
      this.selectTarget.removeAttribute("tabindex")
      this.close()
    }
  }

  // A <div role="combobox"> is not a labelable element, so a <label for> cannot name it. Inside
  // a Field the label names the select and carries an id derived the same way, which is what
  // the combobox and its listbox point aria-labelledby at. A caller's own aria-label or
  // aria-labelledby is already on both, and wins.
  nameCombobox() {
    if (this.comboboxTarget.hasAttribute("aria-label") || this.comboboxTarget.hasAttribute("aria-labelledby")) return

    const label = document.getElementById(`${this.selectTarget.id}-label`)
    if (!label) return

    this.comboboxTarget.setAttribute("aria-labelledby", label.id)
    this.listbox?.setAttribute("aria-labelledby", label.id)
  }

  get listbox() {
    return this.popupTarget.querySelector('[role="listbox"]')
  }

  get enhanced() {
    return this.element.dataset.enhanced === "true"
  }

  get nativeOnly() {
    return !this.searchValue && this.nativeOnTouchValue && this.element.dataset.mediaMatches === "true"
  }

  // --- the mirror --------------------------------------------------------------------------

  // Every visible state, re-derived from the select in one path: the label, which option holds
  // the value, the disabled state, and the aria the control carries. Bound to the select's own
  // change event, so a choice made here and one made by host code look identical.
  render() {
    const chosen = this.selectTarget.selectedOptions[0]
    const value = chosen ? chosen.value : ""

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = chosen ? chosen.textContent : ""
      this.labelTarget.dataset.placeholder = value === "" ? "true" : "false"
    }

    this.options.forEach((option) => {
      const holdsValue = value !== "" && option.dataset.value === value
      if (holdsValue) {
        option.setAttribute("data-selected", "true")
      } else {
        option.removeAttribute("data-selected")
      }
    })

    this.renderDisabled()
    this.mirrorAria("aria-invalid")
    this.mirrorAria("aria-describedby")
  }

  // A disabled Select doesn't open and isn't in the tab order, which is what disabling a native
  // select does; it stays announced, so a screen reader user still meets the control.
  renderDisabled() {
    const disabled = this.selectTarget.disabled
    this.comboboxTarget.setAttribute("aria-disabled", disabled ? "true" : "false")

    if (disabled) {
      this.comboboxTarget.removeAttribute("tabindex")
      this.close()
    } else {
      this.comboboxTarget.setAttribute("tabindex", "0")
    }
  }

  mirrorAria(name) {
    const value = this.selectTarget.getAttribute(name)
    if (value === null) return this.comboboxTarget.removeAttribute(name)

    this.comboboxTarget.setAttribute(name, value)
  }

  // Writing the select is what choosing means; the events are what make it observable, and
  // re-rendering from them is what keeps one render path. Choosing what is already chosen
  // dispatches nothing, exactly as a native select does.
  commit(option) {
    if (!option || this.isDisabled(option)) return

    const value = option.dataset.value
    if (value === this.selectTarget.value) return

    this.selectTarget.value = value
    this.selectTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  restoreAfterReset() {
    // The browser restores the select's default selectedness after the reset event finishes.
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => this.rest())
  }

  renderFromMorph(event) {
    if (this.element === event.target || this.element.contains(event.target)) this.rest()
  }

  // The resting state: closed, nothing active, the label showing whatever the select holds. The
  // value is never reset here -- it lives in the select, and Turbo's snapshot carries a select's
  // selectedness, so Back restores a closed Select still showing the value the user left.
  rest() {
    this.close()
    this.render()
  }

  // Focus belongs on the combobox while the widget is enhanced: the Field label's `for` names
  // the select, and so does the browser when it reports a required select invalid.
  forwardFocus() {
    if (!this.enhanced || this.selectTarget.disabled) return

    this.comboboxTarget.focus()
  }

  // --- opening and closing -----------------------------------------------------------------

  open({ activate = "selected" } = {}) {
    if (!this.enhanced || this.selectTarget.disabled || this.expanded) return

    this.pendingActivate = activate
    this.overlay?.open()
  }

  close() {
    this.overlay?.close()
  }

  // The overlay says when the popup is actually rendered and in the top layer, which is the
  // first moment ui--roving-focus can measure an option to move to. Waiting for it rather than
  // for a frame is also what keeps a key pressed during the open from being handled out of order.
  opened(event) {
    if (event.target !== this.element) return

    this.setAnchored(true)
    this.activateOnOpen(this.pendingActivate)
    this.flushTyped()
  }

  // Every close arrives here, including the ones this controller never asked for: Escape and an
  // outside click are the browser's light dismiss, which the overlay turns into this event.
  closed(event) {
    if (event.target !== this.element) return

    this.setAnchored(false)
    this.opening = false
    this.typed = []
    // A closed list ends the search that was running in it: reopening and typing starts a fresh
    // one rather than continuing a buffer the user has already finished with.
    this.rovingFocus?.resetTypeahead()
    if (this.rovingFocus?.activeIdValue) this.rovingFocus.activeIdValue = ""
    this.markActive()
  }

  get expanded() {
    return this.comboboxTarget.getAttribute("aria-expanded") === "true"
  }

  activateOnOpen(activate) {
    const roving = this.rovingFocus
    this.pendingActivate = null
    if (!roving || !activate || activate === "none") return
    // A key pressed in the frame it takes to render the popup has already moved the group; the
    // newer intent wins over the one the open was started with.
    if (roving.activeIdValue) return this.markActive()

    if (activate === "first") {
      roving.focusFirst()
    } else if (activate === "last") {
      roving.focusLast()
    } else {
      // Opening without moving visual focus still announces the current choice, so the active
      // option is the selected one where there is one, and nothing where there isn't.
      const selected = this.options.find((option) => option.dataset.selected === "true")
      roving.activeIdValue = selected ? selected.id : ""
    }
    // Setting activeId directly announces nothing, so the mark is applied here rather than
    // waiting for an activated event that isn't coming.
    this.markActive()
  }

  // Characters typed at a closed Select belong to a list that isn't rendered yet, and a second
  // character can arrive before it is. They are held until the popup opens and replayed in order,
  // so typeahead stays ui--roving-focus's single implementation rather than being partly rebuilt
  // here, and "ne" still reaches New York.
  flushTyped() {
    const keys = this.typed
    this.typed = []
    this.opening = false
    keys.forEach((key) => {
      this.comboboxTarget.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true }))
    })
  }

  queueTyped(event) {
    if (!this.opening || event.altKey || event.ctrlKey || event.metaKey || event.key.length !== 1) return false

    this.typed.push(event.key)
    return true
  }

  // aria-selected marks where visual focus is, not what the value is: it belongs on the option
  // aria-activedescendant names and on no other (§ Behavior, item 19). Driven by the group's own
  // activated event, so there is no second place that decides which option is active.
  markActive() {
    const activeId = this.rovingFocus?.activeIdValue
    this.options.forEach((option) => {
      option.setAttribute("aria-selected", option.id === activeId ? "true" : "false")
    })
  }

  setAnchored(active) {
    const anchor = this.application.getControllerForElementAndIdentifier(this.element, "ui--anchor")
    if (anchor) anchor.activeValue = active
  }

  // --- keys and pointer --------------------------------------------------------------------

  // Bound to the combobox, so it sees a key before ui--roving-focus on the root does. Every key
  // this table claims is marked handled, which is how the group knows to leave it alone.
  keydown(event) {
    if (event.defaultPrevented || event.isComposing) return
    if (!this.enhanced || this.selectTarget.disabled) return

    const handled = this.queueTyped(event) || (this.expanded ? this.openKeydown(event) : this.closedKeydown(event))
    if (handled) event.preventDefault()
  }

  // Closed. Everything here opens the list without changing the value, and Enter never submits.
  closedKeydown(event) {
    const { key, altKey, ctrlKey, metaKey } = event
    if (ctrlKey || metaKey) return false

    if (key === "ArrowDown" || key === "Enter" || key === " ") return this.openWith("selected")
    if (key === "ArrowUp") return this.openWith(altKey ? "selected" : "first")
    if (altKey) return false
    if (key === "Home") return this.openWith("first")
    if (key === "End") return this.openWith("last")
    if (key.length === 1) {
      this.opening = true
      this.typed = [key]
      this.open({ activate: "none" })
      return true
    }

    return false
  }

  openWith(activate) {
    this.open({ activate })
    return true
  }

  // Open. Arrows, Home, End, the page keys and typeahead are the group's; what is left is
  // choosing, closing, and keeping Enter away from the form.
  openKeydown(event) {
    const { key, altKey, ctrlKey, metaKey } = event
    if (ctrlKey || metaKey) return false

    if (key === "Enter" || key === " " || (altKey && key === "ArrowUp")) {
      this.commit(this.activeOption)
      this.close()
      return true
    }

    if (key === "Tab") {
      // Not prevented: the browser moves focus on, and the choice is made on the way out.
      this.commit(this.activeOption)
      this.close()
      return false
    }

    return false
  }

  // A click on an option. Its mousedown was already cancelled by ui--roving-focus, so DOM focus
  // never left the combobox and there is nothing to restore here.
  choose(event) {
    const option = event.target.closest(OPTION)
    if (!option) return

    event.preventDefault()
    if (this.isDisabled(option)) return

    this.commit(option)
    this.close()
  }

  toggle(event) {
    event.preventDefault()
    if (this.expanded) return this.close()

    this.open()
  }

  // --- state ---------------------------------------------------------------------------------

  get options() {
    return Array.from(this.popupTarget.querySelectorAll(OPTION))
  }

  get activeOption() {
    const id = this.rovingFocus?.activeIdValue
    return id ? this.options.find((option) => option.id === id) : null
  }

  isDisabled(option) {
    return option.getAttribute("aria-disabled") === "true"
  }

  get form() {
    return this.selectTarget.form
  }

  get overlay() {
    return this.companion("ui--overlay", "opening, closing and dismissal do nothing")
  }

  get rovingFocus() {
    return this.companion("ui--roving-focus", "arrow keys, Home, End, the page keys and typeahead do nothing")
  }

  // The companions are declared in this component's own markup, so a missing one means markup
  // that has drifted from it. Warned once per identifier per instance, never thrown: a Select
  // that cannot open is still a working form control.
  companion(identifier, consequence) {
    const controller = this.application.getControllerForElementAndIdentifier(this.element, identifier)
    if (controller) return controller

    this.warned ||= new Set()
    if (!this.warned.has(identifier)) {
      this.warned.add(identifier)
      console.warn(
        `ui--select: no "${identifier}" controller found, so ${consequence}. ` +
        `Add "${identifier}" to this element's data-controller.`,
        this.element
      )
    }
    return null
  }
}
