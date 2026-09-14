import { Controller } from "@hotwired/stimulus"
import * as presence from "rails_ui_kit/overlay/presence"

// Primitive D as a Stimulus controller: the open/closing/closed lifecycle of one element.
//
// It sets data-state and nothing else -- no classes, by design. Tailwind's animate-in /
// animate-out utilities and any consumer CSS key off that attribute, so a class-swap API
// here would just be the modal-*-visible code this primitive exists to subsume.
//
//   <div data-controller="ui--presence"
//        data-ui--presence-open-value="false"
//        data-action="ui--presence:closed->thing#tidyUp"
//        class="transition duration-200 data-[state=closed]:opacity-0 data-[state=closing]:opacity-0"
//        hidden>…</div>
//
// Usable standalone -- an Accordion panel or a Collapsible needs presence and no overlay.
export default class extends Controller {
  static values = {
    open: Boolean,
    timeout: { type: Number, default: 1000 }
  }

  initialize() {
    this.onBeforeCache = () => this.reset()
  }

  connect() {
    // Stimulus replays a stored value before connect(), which is how a page restored from
    // Turbo's cache would otherwise replay an open element. An element rendered open by the
    // server still opens, from the closed resting state, through the normal enter path.
    const renderedOpen = this.openValue

    document.addEventListener("turbo:before-cache", this.onBeforeCache)
    this.reset()
    this.connected = true
    if (!renderedOpen) return

    // Entered here rather than by putting the value back, because Stimulus reads a value's
    // change from the live attribute: reset() clearing it and this restoring it inside one task
    // look to it like no change at all, and the callback never runs.
    this.openValue = true
    presence.enter(this.element, { timeout: this.timeoutValue })
  }

  disconnect() {
    this.connected = false
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    presence.reset(this.element)
  }

  openValueChanged() {
    if (!this.connected) return

    if (this.openValue) {
      presence.enter(this.element, { timeout: this.timeoutValue })
    } else {
      presence.exit(this.element, { timeout: this.timeoutValue })
    }
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  toggle() {
    this.openValue = !this.openValue
  }

  // The closed resting state, at once: no exit animation, no pending timer or frame. Runs on
  // connect, on disconnect and on turbo:before-cache, so a snapshot is never cached open or
  // mid-transition.
  reset() {
    presence.reset(this.element)
    if (this.openValue) this.openValue = false
  }
}
