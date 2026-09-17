import { Controller } from "@hotwired/stimulus"
import * as presence from "rails_ui_kit/overlay/presence"
import {
  FALLBACK_Z_INDEX,
  lockScroll,
  recoverFromLightDismiss,
  relockScroll,
  supportsTopLayer,
  unlockScroll
} from "rails_ui_kit/overlay/overlay_stack"

// Primitive B -- the overlay stack.
//
// Its three modes are platform primitives, not component names, and most of what an overlay
// needs comes with them: the top layer places them, and being in the top layer is what makes
// Escape close exactly the top one, LIFO, with no ordering of ours anywhere:
//
//   modal → a <dialog> opened with showModal(). Focus trap, top layer, Escape: the browser's.
//   layer → popover="auto". Top layer, light dismiss, Escape ordering: the browser's. No trap,
//           which is what a menu or a listbox wants.
//   hint  → popover="manual". Top layer, and critically no light dismiss, so a tooltip
//           appearing never closes the menu the pointer is inside.
//
// What is left for this controller is what the platform does not give: presence (so an
// overlay can animate out at all), backdrop dismiss for <dialog>, a reference-counted body
// scroll lock, focus return, focus kept inside when content is swapped out from under it, and a
// cancelable dismiss event -- including, for a modal, taking Escape from the key, because the
// browser only lets a close request be vetoed while it holds fresh user activation
// (see dismissOnEscape).
//
//   <div data-controller="ui--overlay"
//        data-ui--overlay-mode-value="modal"
//        data-ui--overlay-scroll-lock-value="true"
//        data-ui--overlay-initial-focus-value="input"
//        data-action="ui--overlay:dismiss->unsaved#confirm">
//     <button data-ui--overlay-target="trigger" data-action="ui--overlay#toggle">Open</button>
//     <dialog data-ui--overlay-target="content">…</dialog>
//   </div>
//
// Events: ui--overlay:opened, ui--overlay:closed, ui--overlay:dismiss (cancelable -- calling
// preventDefault() on it keeps the overlay open; detail.reason names the gesture as "escape",
// "outside" or "programmatic", so a listener can refuse one and allow the rest).
const FOCUSABLE = 'button, a[href], input, select, textarea, [tabindex]:not([tabindex="-1"])'

// What this controller writes into the markup it was given (see prepareContent). A Turbo morph
// sets every attribute to the server's markup, which has none of it: the content would stop being
// a popover, so the next open throws, and the trigger would lose its ARIA. What it only adds where
// the markup has none is kept from removal, and the author's own value still morphs.
const OWNED = { content: ["popover"], trigger: ["aria-expanded"] }
// The open state itself, which lives in attributes a morph towards the server's markup would
// rewrite: the content's own attributes (popover, hidden, data-state, the anchor's inline
// position) and this element's open value. An open Dropdown, Popover or Select survives a morphing
// refresh -- a refresh another user's write triggered must not close the menu this user is in
// (ui-stress-page/open-questions.md, decided 2026-09-15).
const OPEN_VALUE_ATTRIBUTE = "data-ui--overlay-open-value"

let sequence = 0

export default class extends Controller {
  static targets = ["content", "trigger", "backdrop"]

  static values = {
    open: Boolean,
    mode: { type: String, default: "layer" },
    dismissible: { type: Boolean, default: true },
    scrollLock: { type: Boolean, default: false },
    restoreFocus: { type: Boolean, default: true },
    initialFocus: { type: String, default: "" },
    moveFocus: { type: Boolean, default: true }
  }

  initialize() {
    this.onBeforeCache = () => this.reset()
    // A Turbo 8 morphing refresh morphs <body>, which takes the scroll lock's inline styles with
    // it while this overlay is still open.
    this.onMorph = () => { if (this.shown && this.scrollLockValue) relockScroll() }
    this.onPointerDown = this.rememberPress.bind(this)
    this.onClick = this.dismissOnBackdrop.bind(this)
    this.onCancel = this.dismissOnCancel.bind(this)
    this.onClose = this.finishNativeClose.bind(this)
    this.onBeforeToggle = this.interceptLightDismiss.bind(this)
    this.onContentKeydown = this.dismissOnEscape.bind(this)
    this.onContentMutated = () => this.keepFocusInside()
    this.onBeforeMorphAttribute = this.keepOwnAttributes.bind(this)
    this.onMorphElement = this.resyncAfterMorph.bind(this)
    this.onBeforeMorphElement = this.keepOpenContent.bind(this)
    this.onHintKeydown = this.dismissHintOnEscape.bind(this)
    this.onFallbackKeydown = this.dismissFallbackOnEscape.bind(this)
    this.onFallbackFocusOut = this.dismissFallbackOnFocusOut.bind(this)
  }

  connect() {
    // Stimulus replays a stored value before connect(), which is how a page restored from
    // Turbo's cache would otherwise reopen an overlay and pull focus into it. An overlay
    // rendered open -- a Modal delivered by a Turbo Stream, say -- still opens, from the
    // closed resting state, through the normal enter path.
    const renderedOpen = this.openValue

    this.shown = false
    this.closing = false
    this.prepareContent()
    this.addListeners()
    this.reset()
    this.connected = true
    if (!renderedOpen) return

    // Opened here rather than by putting the value back, because Stimulus reads a value's
    // change from the live attribute: reset() clearing it and this restoring it inside one task
    // look to it like no change at all, and the callback never runs.
    this.openValue = true
    this.show()
  }

  disconnect() {
    this.connected = false
    this.removeListeners()
    // However the overlay leaves the page -- closed, emptied by a Turbo Stream, navigated
    // away from -- removal without a close is a close.
    this.reset()
  }

  // The content element can be replaced or emptied on its own, without the controller element
  // going anywhere. That is a close too.
  contentTargetDisconnected() {
    this.reset()
  }

  openValueChanged() {
    if (!this.connected) return

    if (this.openValue) {
      this.show()
    } else {
      this.hide()
    }
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  toggle(event) {
    event?.preventDefault()
    this.openValue = !this.active
  }

  // Open, or on its way out. A trigger press while the overlay is animating out means "stay
  // closed": the browser's light dismiss has usually already started closing a layer by the
  // time the click on its trigger lands.
  get active() {
    if (this.shown || this.closing) return true

    return this.hasContentTarget && this.contentTarget.dataset.state === "closing"
  }

  // --- Opening -----------------------------------------------------------------------------

  show() {
    if (this.shown || !this.hasContentTarget) return

    this.shown = true
    this.escapePressed = false
    this.returnTarget = this.focusReturnTarget()
    // The trigger's id, remembered beside the element itself: the response that closes an overlay
    // is often the one that re-renders the region the trigger sits in, and the id is the app's own
    // name for that control (see restoreFocusIfLost).
    this.returnTargetId = this.returnTarget?.id || null
    if (this.scrollLockValue) lockScroll(this)

    // Rendered before it is placed: showModal() and showPopover() can only move focus into an
    // element the browser is actually laying out.
    this.contentTarget.removeAttribute("hidden")
    if (this.hasBackdropTarget) this.backdropTarget.removeAttribute("hidden")
    this.place()

    presence.enter(this.contentTarget)
    if (this.hasBackdropTarget) presence.enter(this.backdropTarget)

    this.moveFocusIn()
    this.watchForLostFocus()
    this.setExpanded(true)
    if (this.modeValue === "hint" && this.dismissibleValue) {
      document.addEventListener("keydown", this.onHintKeydown, true)
    }

    this.dispatch("opened")
  }

  place() {
    const content = this.contentTarget

    if (this.modeValue === "modal") {
      if (typeof content.showModal !== "function") {
        console.error("ui--overlay: mode \"modal\" needs a <dialog> content target", content)
        return
      }
      // A page restored from Turbo's cache can carry a non-modal `open` attribute; showModal()
      // throws on it.
      if (content.open && !content.matches(":modal")) content.removeAttribute("open")
      if (!content.matches(":modal")) content.showModal()
      return
    }

    if (!supportsTopLayer() || content.matches(":popover-open")) return

    // `source` ties the popover to its trigger, so the browser's light dismiss counts a click
    // on the trigger as inside the popover rather than as a dismissal.
    content.showPopover(this.triggerControl ? { source: this.triggerControl } : undefined)
  }

  moveFocusIn() {
    // A hint describes the control the pointer or focus is already on; taking focus off it
    // would be the bug, not the feature. moveFocusValue false is the same opt-out for a layer
    // that must not steal focus either -- a panel that only ever supplements what's already
    // focused, the way a hint does, but wants everything else layer mode gives it.
    if (this.modeValue === "hint" || !this.moveFocusValue) return

    const content = this.contentTarget
    const initial = this.initialFocusValue && content.querySelector(this.initialFocusValue)
    if (initial) return initial.focus()

    // An explicit autofocus is the author saying where focus goes; honour it. What is not
    // honoured is the browser's fallback of focusing the first focusable descendant, which is
    // arbitrary -- a menu's first item, a modal's "Open a layer inside" button.
    const autofocus = content.querySelector("[autofocus]")
    if (autofocus) return autofocus.focus()

    // An overlay with no focusable children still receives focus, and still returns it.
    if (!content.hasAttribute("tabindex")) content.setAttribute("tabindex", "-1")
    content.focus()
  }

  // --- Closing -----------------------------------------------------------------------------

  async hide() {
    if (!this.shown || !this.hasContentTarget) return

    this.shown = false
    this.setExpanded(false)
    this.stopHintEscape()
    // Cleared now, when hiding starts, not once the exit animation finishes: a dismissal that
    // calls hide() directly -- Escape, a backdrop click, a light dismiss recovering into a real
    // close -- never touches openValue itself, so leaving this until finish() means open() during
    // the exit is comparing true to true. Stimulus sees no change and never calls show(): the
    // overlay just stays hidden until the animation runs out on its own. finish() still clears it
    // too, for the path that never calls hide() at all (a native close already out of the top
    // layer, or a nested popover displaced to make room for another).
    if (this.openValue) this.openValue = false

    // Awaited before close() / hidePopover(), which is the only reason a <dialog> can animate
    // out at all: closing it first takes it out of the top layer and nothing renders.
    const closed = presence.exit(this.contentTarget)
    if (this.hasBackdropTarget) presence.exit(this.backdropTarget)
    if (!(await closed)) return // a re-open overtook this close; the overlay stays open

    this.unplace()
    this.finish()
  }

  unplace() {
    const content = this.contentTarget

    if (content.open && typeof content.close === "function") return content.close()
    if (content.matches(":popover-open")) content.hidePopover()
  }

  finish() {
    this.stopWatchingForLostFocus()
    unlockScroll(this)
    this.restoreFocusIfLost()
    // Already cleared by hide() for the normal path; still needed here for finishClosed(), whose
    // callers never go through hide() at all.
    if (this.openValue) this.openValue = false

    this.dispatch("closed")
  }

  // Closed without an exit animation, because something else already took the element out of
  // the top layer: a native close, or another popover opening over this one.
  finishClosed() {
    presence.reset(this.contentTarget)
    if (this.hasBackdropTarget) presence.reset(this.backdropTarget)
    this.setExpanded(false)
    this.stopHintEscape()
    this.finish()
  }

  // Dismissal -- Escape, an outside click, or a component asking on a person's behalf -- is
  // vetoable. This is the seam a dirty-form confirmation hooks into; a programmatic close() skips
  // it. `reason` is what lets a listener veto one gesture and allow another, so a Modal can refuse
  // a backdrop click without also refusing Escape.
  requestDismiss(reason) {
    if (!this.dismissibleValue) return false

    return !this.dispatch("dismiss", { cancelable: true, detail: { reason } }).defaultPrevented
  }

  // The public action: a component asking for the same vetoable close a gesture would get.
  dismiss() {
    this.dismissFor("programmatic")
  }

  dismissFor(reason) {
    // Remembered for the focus restore below: only a pointer gesture competes with the
    // browser's own focus, and only that case defers.
    this.dismissReason = reason
    if (this.requestDismiss(reason)) this.hide()
  }

  // Closed at once, with no exit animation, for a component whose next move needs the content gone
  // in this task: Dropdown's Tab, which lets the browser move focus on from the trigger past items
  // that would otherwise still be rendered. A close all the same, so it says so.
  closeNow() {
    if (!this.active) return

    this.reset()
    this.dispatch("closed")
  }

  // The closed resting state, applied at once: no exit animation, no pending timer or frame,
  // nothing left on <body> and no focus stranded on it. Runs on connect, on disconnect and on
  // turbo:before-cache.
  reset() {
    this.shown = false
    this.closing = false
    this.escapePressed = false
    clearTimeout(this.escapeTimer)
    this.stopHintEscape()
    this.stopWatchingForLostFocus()

    if (this.hasContentTarget) {
      const content = this.contentTarget
      // Never call showModal() on a <dialog> restored with a stale `open` attribute.
      if (content.open && !content.matches(":modal")) content.removeAttribute("open")
      this.unplace()
      presence.reset(content)
    }
    if (this.hasBackdropTarget) presence.reset(this.backdropTarget)

    unlockScroll(this)
    this.setExpanded(false)
    this.restoreFocusIfLost()
    if (this.openValue) this.openValue = false
  }

  // --- Dismiss gestures --------------------------------------------------------------------

  rememberPress(event) {
    this.pressTarget = event.target
  }

  // The one dismiss gesture the platform doesn't give us: a modal <dialog> has no native
  // backdrop dismiss. Both the press and the click have to land on the dialog itself (a click
  // on the ::backdrop targets the dialog), so drag-selecting text from inside the panel out
  // onto the backdrop leaves the overlay open.
  dismissOnBackdrop(event) {
    if (!this.shown || this.modeValue !== "modal") return
    if (!this.isBackdrop(event.target) || !this.isBackdrop(this.pressTarget)) return

    this.dismissFor("outside")
  }

  isBackdrop(node) {
    if (!node) return false

    return node === this.contentTarget || (this.hasBackdropTarget && node === this.backdropTarget)
  }

  // Escape for a modal <dialog>, taken from the key rather than from `cancel`. `cancel` is
  // cancelable only while the window has fresh history-action user activation, which Chrome
  // consumes on the first vetoed close request: Escape, veto, Escape again and the second one is
  // uncancelable, so an unsaved-changes guard loses its veto exactly when it matters. Preventing
  // the keydown's default action stops the close request itself, whatever the activation state.
  //
  // This is not an ordering of our own. The listener is bound to the content, never to the
  // document, so it only ever sees a key pressed inside this overlay, and it stands aside while
  // anything the browser would close first is open (below). `cancel` stays wired for the close
  // requests that never come through a key at all.
  dismissOnEscape(event) {
    if (event.key !== "Escape" || event.defaultPrevented || event.isComposing || !this.shown) return

    // Remembered for the light-dismiss path, which is told that the overlay is closing but not by
    // what. Cleared at the end of this task, so a later outside click is never read as this key.
    this.escapePressed = true
    clearTimeout(this.escapeTimer)
    this.escapeTimer = setTimeout(() => { this.escapePressed = false })

    if (this.modeValue !== "modal" || this.coveredByLayer()) return

    event.preventDefault()
    this.dismissFor("escape")
  }

  // Whether something sits above this overlay in the top layer, which is the browser's own
  // ordering and not a stack of ours: a layer this content is not inside was opened after it, so
  // the browser closes that one first and this key is not ours to take. Hints opt out of the
  // browser's Escape handling entirely (popover="manual"), so they never displace anyone -- a
  // visible tooltip consumes the key itself, in its own capture-phase listener, before this runs.
  coveredByLayer() {
    return Array.from(document.querySelectorAll(":popover-open")).some(
      (other) => other.popover === "auto" && !other.contains(this.contentTarget)
    )
  }

  // <dialog> fires `cancel` for a close request that never came through a key this overlay saw --
  // a back gesture, requestClose(), a close request while focus sits outside the dialog. Where it
  // is cancelable it is still the veto seam; where it is not, the `close` listener picks the
  // bookkeeping up.
  dismissOnCancel(event) {
    if (event.target !== this.contentTarget || !this.shown) return
    // Chrome refuses to let a close request be trapped twice with nothing in between: the
    // second Escape fires `cancel` non-cancelable and closes the dialog regardless. The
    // `close` listener picks the bookkeeping up from there.
    if (!event.cancelable) return

    event.preventDefault()
    this.dismissFor("escape")
  }

  // Whatever closed the dialog without coming through this controller -- that second Escape, a
  // <form method="dialog"> submit, a close() from other code -- still has to leave the page
  // unlocked, the focus back where it came from and the state closed.
  finishNativeClose(event) {
    if (event.target !== this.contentTarget || !this.shown) return
    // close() queues its event as a task, so a dialog closed and opened again inside one task is
    // open by the time this arrives. That close belongs to the cycle before this one; acting on it
    // would leave a dialog that is rendered and :modal marked closed, inerting the page invisibly.
    if (this.contentTarget.open) return

    this.shown = false
    this.finishClosed()
  }

  // `popover` gives a layer its top-layer placement, its Escape ordering and its light
  // dismiss. What it does not give is any say in that dismissal: beforetoggle is cancelable
  // only on the way in, and the hide is immediate -- so there is nowhere to run an exit
  // animation, and no way to honour a vetoed ui--overlay:dismiss. The browser has not painted
  // when beforetoggle fires, so putting the popover back before the next frame is invisible,
  // and from there this controller closes it on its own terms.
  interceptLightDismiss(event) {
    if (event.target !== this.contentTarget || event.newState !== "closed" || !this.shown) return
    // <dialog> fires these too, and it has `cancel` -- a preventable close request -- instead.
    if (this.modeValue === "modal") return

    this.shown = false
    this.closing = true
    const focused = this.contentTarget.contains(document.activeElement) ? document.activeElement : null
    // The browser says a light dismiss is happening, never which gesture did it. This runs inside
    // the same task as that gesture, so an Escape this content has just seen is this dismissal's.
    const reason = this.escapePressed ? "escape" : "outside"
    this.escapePressed = false

    recoverFromLightDismiss(this.contentTarget, () => this.recover(focused, reason))
  }

  recover(focused, reason) {
    // reset() -- a disconnect, or turbo:before-cache -- got here first and already closed it.
    if (!this.closing) return

    this.closing = false
    // Another auto popover opened over this one, so the browser closed this one to make room.
    // That is not a dismissal: there is nothing to veto and nothing to animate.
    if (this.displacedByAnotherPopover()) return this.finishClosed()

    const dismissed = this.requestDismiss(reason)
    this.place()
    this.shown = true

    if (dismissed) return this.hide()
    // Vetoed: the browser moved focus out when it hid the popover, so put it back.
    if (focused?.isConnected) focused.focus()
  }

  displacedByAnotherPopover() {
    const content = this.contentTarget

    return Array.from(document.querySelectorAll(":popover-open")).some(
      (other) => other.popover === "auto" && !other.contains(content) && !content.contains(other)
    )
  }

  // The one named exception to "no document-level dismissal listener". popover="manual" opts
  // out of the browser's Escape handling, so hint content has none to inherit and this is what
  // gives it Escape at all. Capture phase, only while visible, consuming the key with both
  // preventDefault() and stopPropagation() so it never also closes a surrounding <dialog> or
  // another layer (WCAG 1.4.13).
  dismissHintOnEscape(event) {
    if (event.key !== "Escape" || event.defaultPrevented || event.isComposing || !this.shown) return

    event.preventDefault()
    event.stopPropagation()
    this.dismissFor("escape")
  }

  stopHintEscape() {
    document.removeEventListener("keydown", this.onHintKeydown, true)
  }

  // Both of these run only where `popover` is unsupported and there is no light dismiss to
  // delegate to. They are bound to this controller's own element, never to the document, and
  // a nested overlay consumes the key before its ancestor sees it.
  dismissFallbackOnEscape(event) {
    if (!this.shown || this.modeValue === "modal") return
    if (event.key !== "Escape" || event.defaultPrevented || event.isComposing) return

    event.preventDefault()
    this.dismissFor("escape")
  }

  dismissFallbackOnFocusOut(event) {
    if (!this.shown || this.modeValue !== "layer") return
    if (event.relatedTarget && this.element.contains(event.relatedTarget)) return

    this.dismissFor("outside")
  }

  // --- Wiring ------------------------------------------------------------------------------

  prepareContent() {
    if (!this.hasContentTarget) return

    const content = this.contentTarget
    if (!content.id) {
      // Remembered, so a morph that strips a generated id gets the same one back and the
      // trigger's aria-controls keeps resolving.
      this.generatedId ||= `ui-overlay-${(sequence += 1)}`
      content.id = this.generatedId
    }

    if (this.modeValue !== "modal") {
      if (supportsTopLayer()) {
        content.popover = this.modeValue === "hint" ? "manual" : "auto"
      } else {
        // The only stacking value in the kit, applied once by the stack module's constant --
        // not per depth, and never as a literal in a component.
        content.style.zIndex = FALLBACK_Z_INDEX
        if (!content.hasAttribute("tabindex")) content.setAttribute("tabindex", "-1")
      }
    }

    const trigger = this.triggerControl
    if (!trigger || this.modeValue === "hint") return

    // An aria-controls the markup already carries is the author's: a combobox names the listbox
    // inside the content, not the wrapper around it. One this controller gave is re-pointed, in
    // case a morph took the id it named away.
    if (!trigger.hasAttribute("aria-controls") || this.ownsAriaControls) {
      trigger.setAttribute("aria-controls", content.id)
      this.ownsAriaControls = true
    }
    this.setExpanded(this.shown === true)
  }

  // A morph rewrites this overlay's markup to the server's, which has none of what the controller
  // put there. Whatever survived is left alone; whatever went is put back, in the same task as the
  // morph, so nothing is painted without it.
  resyncAfterMorph(event) {
    if (event.target !== this.element && !this.element.contains(event.target)) return

    this.prepareContent()
  }

  // Markup the server renders without an id -- a Dropdown's panel, a Select's root -- doesn't
  // match the open one by id, so a morph swaps the element out rather than updating it, which
  // disconnects the controller and closes the layer the user is in. While it is open, this overlay
  // and its content are left exactly as they are; both morph normally again as soon as it closes.
  keepOpenContent(event) {
    if (!this.guardsOpenState) return
    if (event.target === this.element || (this.hasContentTarget && event.target === this.contentTarget)) event.preventDefault()
  }

  // Whether a morph must leave this overlay's open state alone. A modal is excluded: whether one
  // survives a refresh is the host's own decision, taken by marking its container
  // `data-turbo-permanent` (ui-modal-turbo), and a modal that isn't marked is morphed away. The
  // ruling this implements is about the layer a user is choosing from.
  get guardsOpenState() {
    return this.active && this.modeValue !== "modal"
  }

  keepOwnAttributes(event) {
    const { attributeName } = event.detail
    // While it is open, the content's attributes are the open state: the server's markup says
    // closed, and applying it would hide a layer the user is in and strip the position the anchor
    // computed. The element's own open value goes with them.
    if (this.guardsOpenState) {
      if (this.hasContentTarget && event.target === this.contentTarget) return event.preventDefault()
      if (event.target === this.element && attributeName === OPEN_VALUE_ATTRIBUTE) return event.preventDefault()
    }

    const part = this.hasContentTarget && event.target === this.contentTarget ? "content"
      : this.modeValue !== "hint" && event.target === this.triggerControl ? "trigger" : null
    if (part && OWNED[part].includes(attributeName)) event.preventDefault()
  }

  addListeners() {
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
    document.addEventListener("turbo:morph", this.onMorph)
    this.element.addEventListener("pointerdown", this.onPointerDown, true)
    this.element.addEventListener("click", this.onClick)
    this.element.addEventListener("turbo:before-morph-attribute", this.onBeforeMorphAttribute)
    this.element.addEventListener("turbo:morph-element", this.onMorphElement)
    this.element.addEventListener("turbo:before-morph-element", this.onBeforeMorphElement)

    if (this.hasContentTarget) {
      this.contentTarget.addEventListener("cancel", this.onCancel)
      this.contentTarget.addEventListener("close", this.onClose)
      this.contentTarget.addEventListener("beforetoggle", this.onBeforeToggle)
      this.contentTarget.addEventListener("keydown", this.onContentKeydown)
    }

    if (supportsTopLayer()) return

    this.element.addEventListener("keydown", this.onFallbackKeydown)
    this.element.addEventListener("focusout", this.onFallbackFocusOut)
  }

  removeListeners() {
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    document.removeEventListener("turbo:morph", this.onMorph)
    this.element.removeEventListener("pointerdown", this.onPointerDown, true)
    this.element.removeEventListener("click", this.onClick)
    this.element.removeEventListener("turbo:before-morph-attribute", this.onBeforeMorphAttribute)
    this.element.removeEventListener("turbo:morph-element", this.onMorphElement)
    this.element.removeEventListener("turbo:before-morph-element", this.onBeforeMorphElement)
    this.element.removeEventListener("keydown", this.onFallbackKeydown)
    this.element.removeEventListener("focusout", this.onFallbackFocusOut)

    if (!this.hasContentTarget) return

    this.contentTarget.removeEventListener("cancel", this.onCancel)
    this.contentTarget.removeEventListener("close", this.onClose)
    this.contentTarget.removeEventListener("beforetoggle", this.onBeforeToggle)
    this.contentTarget.removeEventListener("keydown", this.onContentKeydown)
  }

  // --- Focus -------------------------------------------------------------------------------

  // Where focus goes when this overlay closes. An open() that overtakes a close still animating
  // out finds focus inside the overlay's own content, which is about to stop being rendered:
  // recording that would return focus to a dead node, so the target the interrupted cycle
  // recorded is kept instead.
  focusReturnTarget() {
    // The trigger, when there is one: item 12 says focus returns to it, and reading the focused
    // element instead gets this wrong exactly when two layers change hands in one gesture -- a
    // click on this trigger that light-dismisses another overlay lets that one's focus return run
    // first, and its trigger would be recorded here as "where focus came from".
    const trigger = this.triggerControl
    if (trigger?.isConnected) return trigger

    const active = document.activeElement
    const inside = this.hasContentTarget && this.contentTarget.contains(active)
    if (active && active !== document.body && !inside) return active

    return this.returnTarget?.isConnected ? this.returnTarget : this.triggerControl
  }

  // An open overlay whose focused element is removed -- a Turbo Stream or frame swap inside it --
  // is left with focus on <body>, outside the overlay, where Tab starts from the top of the page
  // and a screen reader is no longer in the dialog. Nothing announces that removal, so it is
  // watched for rather than listened for.
  watchForLostFocus() {
    // Nothing to recover for content that was never given focus in the first place.
    if (this.modeValue === "hint" || !this.moveFocusValue || !this.hasContentTarget) return

    this.focusWatcher ||= new MutationObserver(this.onContentMutated)
    this.focusWatcher.observe(this.contentTarget, { childList: true, subtree: true })
  }

  stopWatchingForLostFocus() {
    this.focusWatcher?.disconnect()
  }

  keepFocusInside() {
    if (!this.shown || !this.hasContentTarget) return

    const active = document.activeElement
    if (active && active !== document.body) return

    this.moveFocusIn()
  }

  // Focus restore is the browser's for both <dialog> and popovers, so this only steps in where
  // the browser left focus nowhere: on <body>, or on an element inside the overlay that is
  // about to stop being rendered. A dismiss that moved focus somewhere else on purpose keeps it.
  restoreFocusIfLost() {
    const target = this.focusRestoreTarget()
    const deferred = this.dismissReason === "outside"
    this.returnTarget = null
    this.returnTargetId = null
    this.dismissReason = null
    if (!this.restoreFocusValue || !target) return

    // An outside gesture is deferred to the next frame; everything else restores in this task. A
    // click on another control focuses it as the mousedown's default action, which runs after
    // this listener, and with no exit animation to wait for (reduced motion) the close finishes
    // first -- so restoring now would take focus off the control the user just pressed, and leave
    // the browser restoring the wrong element when that control's own overlay closes. A close
    // with no pointer behind it (Escape, a close button, a Turbo Stream that replaced this
    // overlay with another) has nothing to wait for, and the overlay opening in its place reads
    // focus in the same task -- so deferring there would hand it the wrong element instead.
    const restore = () => {
      const active = document.activeElement
      const inside = this.hasContentTarget && this.contentTarget.contains(active)
      // Focus the browser parked somewhere for us counts as lost, not as a place the user chose:
      // a click on non-focusable content inside a modal <dialog> leaves focus on the dialog, and
      // an element that stops being focusable leaves it on <body>. Either way the trigger is
      // where item 12 says focus goes when the overlay closes.
      const parked = !active || active === document.body || active === document.documentElement ||
        (active.tagName === "DIALOG" && active.contains(this.element))
      if ((!parked && !inside) || !target.isConnected) return

      target.focus({ preventScroll: true })
    }

    if (deferred) requestAnimationFrame(restore)
    else restore()
  }

  // The element focus goes back to. Normally the one that was focused when the overlay opened --
  // but a server response that closes an overlay commonly re-renders the region its trigger sat
  // in, which leaves that element detached and focus with nowhere to go. An id is the app's own
  // name for a control, so whatever now carries it is the trigger. With no id there is nothing to
  // look up and focus is left where it is, rather than thrown to the top of the page.
  focusRestoreTarget() {
    if (this.returnTarget?.isConnected) return this.returnTarget

    return this.returnTargetId ? document.getElementById(this.returnTargetId) : null
  }

  setExpanded(open) {
    const trigger = this.triggerControl
    if (!trigger || this.modeValue === "hint") return

    trigger.setAttribute("aria-expanded", open ? "true" : "false")
  }

  // ARIA state belongs on the caller's control, not on a wrapping <div>: a wrapper is neither
  // focusable nor announced with state, and in a block layout it spans the full width.
  get triggerControl() {
    if (!this.hasTriggerTarget) return null
    if (this.triggerTarget.matches(FOCUSABLE)) return this.triggerTarget

    return this.triggerTarget.querySelector(FOCUSABLE) || this.triggerTarget
  }
}
