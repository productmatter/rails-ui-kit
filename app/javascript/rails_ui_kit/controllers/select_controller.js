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
const GROUP = '[role="group"]'
// Keys that move the caret rather than the list: in search mode they hand visual focus back to
// the text field, which is APG's rule for an editable combobox.
const CARET_KEYS = ["ArrowLeft", "ArrowRight", "Home", "End"]
// How long typing has to settle before the result count is announced, so a screen reader isn't
// interrupted on every keystroke.
const ANNOUNCE_DELAY = 250

// Case- and diacritic-insensitive, so "e" matches "É" (§ Behavior, item 21).
function normalise(text) {
  return text.trim().toLowerCase().normalize("NFD").replace(/\p{Diacritic}/gu, "")
}

export default class extends Controller {
  static targets = ["select", "combobox", "label", "popup", "showOptions", "empty", "status"]

  static values = {
    search: { type: Boolean, default: false },
    // Every plural form the locale defines, and the locale that rendered them. The count is only
    // known here, so CLDR's own rules pick the form -- `one` is a category, not the number one.
    results: Object,
    locale: { type: String, default: "" },
    // The platform picker beats anything we can draw on a phone, and the unenhanced select is
    // already the no-JavaScript path, so select-only mode keeps it on a coarse pointer
    // (ui-select open-questions.md). Search mode always enhances: no native picker searches.
    nativeOnTouch: { type: Boolean, default: true }
  }

  initialize() {
    this.typed = []
    this.onSelectFocus = this.forwardFocus.bind(this)
    this.onFormReset = this.restoreAfterReset.bind(this)
    this.onBeforeCache = () => this.rest()
    this.onMorph = this.renderFromMorph.bind(this)
    this.onPointerChange = () => this.applyEnhancement()
  }

  connect() {
    this.selectTarget.addEventListener("focus", this.onSelectFocus)
    this.watchPointer()
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
    document.addEventListener("turbo:morph-element", this.onMorph)
    this.form?.addEventListener("reset", this.onFormReset)

    this.applyEnhancement()
    this.render()
  }

  disconnect() {
    this.selectTarget.removeEventListener("focus", this.onSelectFocus)
    this.coarsePointer?.removeEventListener("change", this.onPointerChange)
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
  //
  // Which of the two is visible on a touch screen is the component's own CSS, a media query the
  // browser re-evaluates live. What CSS can't reach is the accessibility tree and the tab order,
  // so they are set here, and again whenever the primary pointer changes: a screen reader meets
  // exactly the control that is showing.
  applyEnhancement() {
    const enhance = !this.nativeOnly
    this.element.dataset.enhanced = "true"

    this.comboboxTarget.hidden = false
    if (this.hasShowOptionsTarget) this.showOptionsTarget.hidden = false
    this.selectTarget.setAttribute("aria-hidden", enhance ? "true" : "false")
    if (enhance) {
      this.selectTarget.setAttribute("tabindex", "-1")
      this.nameCombobox()
    } else {
      this.selectTarget.removeAttribute("tabindex")
      this.close()
    }
  }

  // The same query the component's pointer-coarse: classes compile to, watched only where it
  // decides anything.
  watchPointer() {
    if (this.searchValue || !this.nativeOnTouchValue) return

    this.coarsePointer = window.matchMedia("(pointer: coarse)")
    this.coarsePointer.addEventListener("change", this.onPointerChange)
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

  // Whether the combobox is the control: connected, and not on a touch screen that keeps the
  // platform picker.
  get enhanced() {
    return this.element.dataset.enhanced === "true" && !this.nativeOnly
  }

  get nativeOnly() {
    return this.coarsePointer?.matches === true
  }

  // --- the mirror --------------------------------------------------------------------------

  // Every visible state, re-derived from the select in one path: the label, which option holds
  // the value, the disabled state, and the aria the control carries. Bound to the select's own
  // change event, so a choice made here and one made by host code look identical.
  render(event) {
    // Only the select's own change is the mirror's: a text field fires change of its own when it
    // loses focus after an edit, and that is not a new value.
    if (event && event.target !== this.selectTarget) return

    const chosen = this.selectTarget.selectedOptions[0]
    const value = chosen ? chosen.value : ""

    this.renderLabel(chosen, value)

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
    this.mirrorRequired()
  }

  // What the control shows: the text field's value when searching, the label element otherwise.
  renderLabel(chosen, value) {
    const text = chosen ? chosen.textContent : ""
    if (this.searchValue) {
      this.comboboxTarget.value = text
      return
    }
    if (!this.hasLabelTarget) return

    this.labelTarget.textContent = text
    this.labelTarget.dataset.placeholder = value === "" ? "true" : "false"
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

  // `required` is a plain attribute on the select, not an aria one, so it is translated rather
  // than copied byte for byte the way mirrorAria copies aria-invalid and aria-describedby.
  // Removed rather than set to "false" when absent, matching how the server never renders it.
  mirrorRequired() {
    if (this.selectTarget.required) {
      this.comboboxTarget.setAttribute("aria-required", "true")
    } else {
      this.comboboxTarget.removeAttribute("aria-required")
    }
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
    this.clearFilter()
    this.clearActive()
    this.render()
  }

  // Focus belongs on the combobox while the widget is enhanced: the Field label's `for` names
  // the select, and so does the browser when it reports a required select invalid.
  forwardFocus() {
    if (!this.enhanced || this.selectTarget.disabled) return

    this.comboboxTarget.focus()
  }

  // --- filtering -----------------------------------------------------------------------------

  // Typing filters the listbox, never the select: the value that can submit is never hidden away
  // (§ Behavior, item 21). Bound to the text field's own input event, so every way of editing it
  // -- typing, pasting, cutting -- runs the same path.
  filter() {
    this.open({ activate: "none" })

    const query = normalise(this.comboboxTarget.value)
    const matches = this.options.filter((option) => {
      const hidden = query !== "" && !normalise(option.textContent).includes(query)
      option.hidden = hidden
      return !hidden
    })

    // A group with nothing left in it is hidden too, rather than left as a heading over nothing.
    this.groups.forEach((group) => {
      group.hidden = !Array.from(group.querySelectorAll(OPTION)).some((option) => !option.hidden)
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = matches.length > 0
    // APG: after a filter, visual focus is back on the text field.
    this.clearActive()
    this.announce(matches.length)
  }

  // Announced once typing settles, so a screen reader user hears that the list narrowed -- or
  // emptied -- without arrowing into it, and isn't interrupted on every keystroke.
  announce(count) {
    if (!this.hasStatusTarget) return

    clearTimeout(this.announceTimer)
    this.announceTimer = setTimeout(() => {
      this.statusTarget.textContent = this.resultsText(count)
    }, ANNOUNCE_DELAY)
  }

  // Rails' `zero` is an explicit zero form rather than a CLDR category, so it wins at 0 where a
  // locale file defines one; everything else is CLDR's. An unmatched category falls back to
  // `other`, which every locale has, so a translation missing a form degrades instead of blanking.
  resultsText(count) {
    const forms = this.resultsValue || {}
    const category = count === 0 && forms.zero ? "zero" : this.pluralCategory(count)
    const form = forms[category] ?? forms.other ?? ""

    return form.replace("%{count}", this.formatCount(count))
  }

  // An unknown or malformed locale tag makes Intl throw rather than guess; the count still has to
  // be announced, so both fall back rather than failing.
  pluralCategory(count) {
    try {
      return new Intl.PluralRules(this.localeValue || undefined).select(count)
    } catch {
      return "other"
    }
  }

  formatCount(count) {
    try {
      return new Intl.NumberFormat(this.localeValue || undefined).format(count)
    } catch {
      return String(count)
    }
  }

  clearFilter() {
    clearTimeout(this.announceTimer)
    this.options.forEach((option) => { option.hidden = false })
    this.groups.forEach((group) => { group.hidden = false })
    if (this.hasEmptyTarget) this.emptyTarget.hidden = true
    if (this.hasStatusTarget) this.statusTarget.textContent = ""
  }

  clearActive() {
    if (this.rovingFocus?.activeIdValue) this.rovingFocus.activeIdValue = ""
    this.markActive()
  }

  // The text field only ever shows a real option's label once the list closes: what was chosen,
  // blank where the field was emptied and the select has a blank option, and otherwise whatever
  // the select still holds. What the user typed is never silently turned into a choice.
  commitOnClose() {
    const blank = this.options.find((option) => option.dataset.value === "")
    if (this.comboboxTarget.value.trim() === "" && blank) this.commit(blank)

    this.render()
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
    this.clearActive()
    if (this.searchValue) {
      this.clearFilter()
      this.commitOnClose()
    }
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
    if (this.searchValue) return this.closedSearchKeydown(key, altKey)

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

  // Search mode, closed. Enter is deliberately missing: it is not handled, so implicit form
  // submission proceeds exactly as it does for any other text field.
  closedSearchKeydown(key, altKey) {
    if (altKey) return key === "ArrowDown" ? this.openWith("none") : false
    if (key === "ArrowDown") return this.openWith("first")
    if (key === "ArrowUp") return this.openWith("last")
    if (key === "Escape") return this.restoreText()

    return false
  }

  // Escape on a closed field is the cancel key: it puts the text back to what the select holds
  // and changes nothing else. A faithful transcription of the APG table would clear the field,
  // but in that example the text *is* the value; here the value lives in the select, so clearing
  // the text would either strand an empty field over a real value or make Escape destroy a
  // committed answer -- and dispatch input and change from a keystroke that means "never mind".
  // Clearing a choice is what a blank option is for.
  restoreText() {
    // Unclaimed when there is nothing to put back, so the key still reaches a surrounding Modal.
    const chosen = this.selectTarget.selectedOptions[0]
    if (this.comboboxTarget.value === (chosen ? chosen.textContent : "")) return false

    this.render()
    this.clearFilter()
    return true
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
    if (this.searchValue) return this.openSearchKeydown(key, altKey)

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

  // Search mode, open. Enter takes the active option if there is one and closes either way, and
  // it is always prevented, so the key can never submit the form while the list is open. Tab
  // closes without selecting: what the user typed is never turned into a choice by walking away.
  openSearchKeydown(key, altKey) {
    if (altKey) return false

    if (key === "Enter") {
      this.commit(this.activeOption)
      this.close()
      return true
    }

    if (key === "Tab") {
      this.close()
      return false
    }

    // The caret keys belong to the text field; taking them back means clearing visual focus.
    if (CARET_KEYS.includes(key)) {
      this.clearActive()
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

  // The trigger in select-only mode, and the show-options button in search mode -- which is a
  // real button, so pressing it takes DOM focus; focus goes straight back to the field it belongs
  // to (§ Behavior, item 18).
  toggle(event) {
    event.preventDefault()
    if (this.expanded) {
      this.close()
    } else {
      this.open()
    }
    if (this.searchValue) this.comboboxTarget.focus()
  }

  // --- state ---------------------------------------------------------------------------------

  get options() {
    return Array.from(this.popupTarget.querySelectorAll(OPTION))
  }

  get groups() {
    return Array.from(this.popupTarget.querySelectorAll(GROUP))
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
