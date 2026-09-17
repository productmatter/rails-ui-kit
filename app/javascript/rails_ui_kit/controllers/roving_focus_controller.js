import { Controller } from "@hotwired/stimulus"

// Group keyboard navigation with two focus models, declared by the group and never mixed.
//
//   roving            -- menu, toolbar, tabs. Real DOM focus moves between the items; exactly one
//                        item is tabindex="0", so the group is a single Tab stop.
//   activedescendant  -- listbox, combobox. DOM focus stays on the input target; the active item
//                        is announced through aria-activedescendant and shown with the active class.
//
//   <div role="menu" data-controller="ui--roving-focus" data-ui--roving-focus-typeahead-value="true">
//     <button role="menuitem" data-ui--roving-focus-target="item">Edit</button>
//     …
//   </div>

const DISABLED = '[disabled], [aria-disabled="true"], [data-disabled]'
const EDITABLE = 'input:not([type="button"]):not([type="checkbox"]):not([type="radio"]), textarea, [contenteditable=""], [contenteditable="true"]'

const NEXT_KEYS = { vertical: ["ArrowDown"], horizontal: ["ArrowRight"], both: ["ArrowDown", "ArrowRight"] }
const PREVIOUS_KEYS = { vertical: ["ArrowUp"], horizontal: ["ArrowLeft"], both: ["ArrowUp", "ArrowLeft"] }

let idCounter = 0

// Real focus. The item that holds focus is the position, and moving means calling focus().
// Never touches aria-activedescendant.
const rovingModel = {
  owner(controller, event) {
    return controller.itemTargets.find(item => item.contains(event.target)) || null
  },

  current(controller, event) {
    return this.owner(controller, event)
  },

  render(controller, active) {
    controller.itemTargets.forEach(item => item.setAttribute("tabindex", item === active ? "0" : "-1"))
  },

  move(controller, item) {
    item.focus()
  },

  // Pointer or hover activation moves focus only when the group already has it, so hovering a
  // toolbar never pulls focus out of a field the user is typing in.
  follow(controller, item) {
    if (controller.element.contains(document.activeElement)) item.focus()
  },

  // An editable input's own editing keys are never taken from it.
  editing() {
    return false
  }
}

// Virtual focus. The input keeps DOM focus throughout; the position lives only in activeId,
// aria-activedescendant and the active class. Never calls focus() on an item.
const activeDescendantModel = {
  owner(controller, event) {
    return controller.hasInputTarget && event.target === controller.inputTarget ? controller.inputTarget : null
  },

  current(controller) {
    return controller.activeItem
  },

  render(controller, active) {
    controller.itemTargets.forEach(item => {
      item.setAttribute("tabindex", "-1")
      controller.activeClasses.forEach(name => item.classList.toggle(name, item === active))
    })

    if (!controller.hasInputTarget) return
    if (active) {
      controller.inputTarget.setAttribute("aria-activedescendant", active.id)
    } else {
      controller.inputTarget.removeAttribute("aria-activedescendant")
    }
  },

  // Nothing scrolls a virtually focused option into view for us, the way real focus does.
  move(controller, item) {
    item.scrollIntoView({ block: "nearest" })
  },

  follow(controller, item) {
    this.move(controller, item)
  },

  // Home, End and typed characters belong to a text input: they move its caret and type into it.
  // Only a non-editable input (a select-only combobox) hands them to the group.
  editing(controller) {
    return controller.hasInputTarget && controller.inputTarget.matches(EDITABLE)
  }
}

export default class extends Controller {
  static targets = ["item", "input"]
  static classes = ["active"]

  static values = {
    focusModel: { type: String, default: "roving" },
    orientation: { type: String, default: "vertical" },
    loop: { type: Boolean, default: true },
    typeahead: { type: Boolean, default: false },
    typeaheadTimeout: { type: Number, default: 500 },
    activeId: { type: String, default: "" },
    skipDisabled: { type: Boolean, default: false },
    pageStep: { type: Number, default: 0 }
  }

  initialize() {
    this.onKeydown = this.handleKeydown.bind(this)
    this.onGuard = this.guardDisabled.bind(this)
    this.onFocusin = this.handleFocusin.bind(this)
    this.onFocusout = this.handleFocusout.bind(this)
    this.onMousedown = this.handleMousedown.bind(this)
    this.snapshot = []
  }

  connect() {
    this.element.addEventListener("keydown", this.onKeydown)
    this.element.addEventListener("keydown", this.onGuard, true)
    this.element.addEventListener("click", this.onGuard, true)
    this.element.addEventListener("focusin", this.onFocusin)
    this.element.addEventListener("focusout", this.onFocusout)
    this.element.addEventListener("mousedown", this.onMousedown)
    this.connected = true
    // Normalises the markup and restores a stored activeId. Never moves focus: a page restored
    // from Turbo's cache does not pull focus into the group.
    this.normalise()
  }

  disconnect() {
    this.connected = false
    this.element.removeEventListener("keydown", this.onKeydown)
    this.element.removeEventListener("keydown", this.onGuard, true)
    this.element.removeEventListener("click", this.onGuard, true)
    this.element.removeEventListener("focusin", this.onFocusin)
    this.element.removeEventListener("focusout", this.onFocusout)
    this.element.removeEventListener("mousedown", this.onMousedown)
    this.resetTypeahead()
    this.focusedItem = null
  }

  // Turbo Stream updates are the normal case. Stimulus reports every added or removed item, and
  // after each the group again has exactly one tab stop.
  itemTargetConnected() {
    this.normalise({ announce: true })
  }

  itemTargetDisconnected() {
    this.normalise({ announce: true })
  }

  activeIdValueChanged() {
    this.normalise()
  }

  // --- actions ---

  focusFirst() {
    this.moveTo(this.step(null, 1))
  }

  focusLast() {
    this.moveTo(this.step(null, -1))
  }

  // For pointer interaction: data-action="mouseenter->ui--roving-focus#activate" on an item keeps
  // the active item in step with hover and click.
  activate(event) {
    const item = this.itemTargets.find(candidate => candidate.contains(event.target))
    if (!item || !this.isNavigable(item)) return

    this.setActive(item)
    this.model.follow(this, item)
  }

  // --- state ---

  get model() {
    return this.focusModelValue === "activedescendant" ? activeDescendantModel : rovingModel
  }

  get activeItem() {
    return this.activeIdValue ? this.itemTargets.find(item => item.id === this.activeIdValue) || null : null
  }

  isDisabled(item) {
    return item.matches(DISABLED)
  }

  // Disabled items take the position by default (a menu item stays discoverable, per the APG) and
  // are only refused activation; skipDisabled leaves them out of navigation altogether.
  isNavigable(item) {
    if (this.skipDisabledValue && this.isDisabled(item)) return false
    // A natively disabled control cannot take focus and cannot be tabbed to, so in the roving
    // model it can only be a dead end and a tab stop that leads nowhere. aria-disabled is the
    // attribute that keeps an item discoverable; `disabled` is the one that removes it.
    if (this.model === rovingModel && item.matches(":disabled")) return false
    return !item.hidden && item.getClientRects().length > 0
  }

  setActive(item, { announce = true } = {}) {
    const previous = this.activeItem
    if (item.id !== this.activeIdValue) this.activeIdValue = item.id
    this.model.render(this, item)

    if (announce && item !== previous) {
      this.dispatch("activated", { detail: { item, id: item.id, index: this.itemTargets.indexOf(item) } })
    }
  }

  moveTo(item) {
    if (!item) return
    this.setActive(item)
    this.model.move(this, item)
  }

  // Rebuilds the group's attributes from activeId. When the active item has left the DOM the
  // position clamps to the nearest surviving item -- the next one, else the previous -- and a
  // roving group whose focused item was removed puts focus there, rather than on <body>.
  normalise({ announce = false } = {}) {
    if (!this.connected) return

    const items = this.itemTargets
    items.forEach(item => { if (!item.id) item.id = `ui-roving-focus-item-${++idCounter}` })

    let active = this.activeItem
    const removed = this.activeIdValue && !active ? this.snapshot.find(item => item.id === this.activeIdValue) : null

    if (removed) active = this.survivorOf(removed, items)
    if (active && this.skipDisabledValue && this.isDisabled(active)) active = this.survivorOf(active, items)
    // A roving group always has a tab stop; a listbox has no active option until one is chosen.
    if (!active && this.model === rovingModel) active = items.find(item => !this.isDisabled(item)) || null

    this.snapshot = items

    if (!active) {
      if (this.activeIdValue) this.activeIdValue = ""
      return this.model.render(this, null)
    }

    this.setActive(active, { announce: announce && Boolean(removed) })

    const focusLost = !document.activeElement || document.activeElement === document.body
    if (removed && removed === this.focusedItem && focusLost && this.model === rovingModel) active.focus()
  }

  // The nearest item to `item` that is still in the group: the ones after it in order, then the
  // ones before it, nearest first.
  survivorOf(item, items) {
    const source = this.snapshot.includes(item) ? this.snapshot : items
    const index = source.indexOf(item)
    const pool = index === -1 ? items : [...source.slice(index + 1), ...source.slice(0, index).reverse()]

    const usable = candidate => !this.skipDisabledValue || !this.isDisabled(candidate)
    return pool.find(candidate => candidate !== item && items.includes(candidate) && usable(candidate)) || null
  }

  // --- keyboard ---

  handleKeydown(event) {
    if (event.defaultPrevented || event.isComposing) return
    if (!this.model.owner(this, event)) return

    const target = this.targetFor(event)
    if (target === undefined) return

    // Only keys the group actually handles are cancelled, so an ArrowLeft it ignores still moves
    // the caret in an input.
    event.preventDefault()
    if (target && target !== this.model.current(this, event)) this.moveTo(target)
  }

  // The item a key moves to; null for a handled key that goes nowhere (an end reached with loop
  // off); undefined for a key the group does not handle.
  targetFor(event) {
    const { key, altKey, ctrlKey, metaKey, shiftKey } = event
    if (altKey || ctrlKey || metaKey) return undefined

    const current = this.model.current(this, event)
    const orientation = NEXT_KEYS[this.orientationValue] ? this.orientationValue : "vertical"

    if (!shiftKey && NEXT_KEYS[orientation].includes(key)) return this.step(current, 1)
    if (!shiftKey && PREVIOUS_KEYS[orientation].includes(key)) return this.step(current, -1)
    if (!shiftKey && this.pageStepValue > 0 && key === "PageDown") return this.page(current, 1)
    if (!shiftKey && this.pageStepValue > 0 && key === "PageUp") return this.page(current, -1)

    if (this.model.editing(this)) return undefined

    if (!shiftKey && key === "Home") return this.step(null, 1)
    if (!shiftKey && key === "End") return this.step(null, -1)

    if (this.typeaheadValue && key.length === 1 && key !== " ") return this.typeaheadFrom(current, key) || undefined

    return undefined
  }

  // The next navigable item in a direction from `from`, or from outside the group when `from` is
  // null (so a step of 1 finds the first item and -1 the last). Wraps when loop is on; clamps --
  // stays put -- when it is off.
  step(from, delta) {
    const items = this.itemTargets
    const count = items.length
    const start = items.indexOf(from)

    for (let distance = 1; distance <= count; distance++) {
      let index = start === -1 ? (delta > 0 ? distance - 1 : count - distance) : start + delta * distance

      if (this.loopValue) {
        index = (index % count + count) % count
      } else if (index < 0 || index >= count) {
        break
      }

      if (this.isNavigable(items[index])) return items[index]
    }

    return start === -1 ? null : from
  }

  // pageStep navigable items in a direction, stopping at the end rather than wrapping part-way
  // through a jump -- so PageDown near the bottom lands on the last item. Only a jump that starts
  // on the end item follows loop, the way an arrow key at that end does.
  page(from, delta) {
    const items = this.itemTargets
    let target = from

    for (let moved = 0; moved < this.pageStepValue; moved++) {
      const next = this.step(target, delta)
      if (!next || next === target) break

      const wrapped = target && (items.indexOf(next) - items.indexOf(target)) * delta < 0
      if (wrapped) return moved === 0 ? next : target
      target = next
    }

    return target
  }

  // Typed characters build a buffer that holds for typeaheadTimeout ms, so "du" reaches Duplicate
  // rather than stopping at Delete. A single character, or the same one repeated, searches from
  // the item after the current one and so steps through the items sharing an initial; a longer
  // buffer refines from the current item. Matches aria-label ahead of text.
  typeaheadFrom(current, key) {
    clearTimeout(this.typeaheadTimer)
    this.buffer = (this.buffer || "") + key.toLowerCase()
    this.typeaheadTimer = setTimeout(() => this.resetTypeahead(), this.typeaheadTimeoutValue)

    const repeated = [...this.buffer].every(character => character === this.buffer[0])
    const search = repeated ? this.buffer[0] : this.buffer

    const candidates = this.itemTargets.filter(item => this.isNavigable(item))
    const count = candidates.length
    const position = candidates.indexOf(current)
    const start = position === -1 ? 0 : position + (repeated ? 1 : 0)

    for (let offset = 0; offset < count; offset++) {
      const item = candidates[(start + offset) % count]
      if (this.labelOf(item).startsWith(search)) return item
    }

    return null
  }

  resetTypeahead() {
    clearTimeout(this.typeaheadTimer)
    this.buffer = ""
  }

  labelOf(item) {
    return (item.getAttribute("aria-label") || item.textContent || "").trim().toLowerCase()
  }

  // A disabled item can hold the position but is never activated. Runs in the capture phase, so
  // the browser's own activation (a link's navigation, a button's click on Enter or Space) is
  // cancelled and any handler on the item sees event.defaultPrevented.
  guardDisabled(event) {
    const item = event.type === "click"
      ? this.itemTargets.find(candidate => candidate.contains(event.target))
      : this.keyboardActivationTarget(event)

    if (item && this.isDisabled(item)) event.preventDefault()
  }

  keyboardActivationTarget(event) {
    if (event.key !== "Enter" && event.key !== " ") return null
    if (!this.model.owner(this, event)) return null
    if (event.key === " " && this.model.editing(this)) return null
    return this.model.current(this, event)
  }

  // --- focus and pointer ---

  // Focus that arrives some other way -- a click, a script -- moves the tab stop with it, so
  // Shift+Tab from that item leaves the group rather than landing on the stale tab stop.
  handleFocusin(event) {
    if (this.model !== rovingModel) return

    const item = this.model.owner(this, event)
    if (!item) return

    this.focusedItem = item
    if (item.id !== this.activeIdValue) this.setActive(item)
  }

  handleFocusout(event) {
    if (event.relatedTarget && !this.element.contains(event.relatedTarget)) this.focusedItem = null
  }

  // A press on an option would otherwise move DOM focus to it and out of the input.
  handleMousedown(event) {
    if (this.model !== activeDescendantModel || !this.hasInputTarget) return
    if (this.itemTargets.some(item => item.contains(event.target))) event.preventDefault()
  }
}
