import { Controller } from "@hotwired/stimulus"
import * as presence from "rails_ui_kit/overlay/presence"

// Field's help-text swap. The server renders the answer: an invalid field's description is
// hidden and its error follows it, a valid field shows the description and no error. This
// controller only animates between those two answers, and only when a Turbo morph changes one
// into the other on the same element (ui-field-model-binding § Behavior, items 21-23).
//
//   <div data-slot="field" data-controller="ui--field" data-invalid="true">
//     <label>…</label> <input …>
//     <p data-slot="field-description" hidden>…</p>
//     <p data-slot="field-error">…</p>
//   </div>
//
// Every wait is the presence primitive's, composed by import as ui--overlay composes it. It
// does nothing on connect: a page load, a frame render or a stream replace delivers a new field
// with nothing earlier on the page to animate from.
const DESCRIPTION = "field-description"
const ERROR = "field-error"
// What presence owns on a part, and so what a morph must not reset under it.
const PRESENCE_ATTRIBUTES = ["hidden", "data-state"]

export default class extends Controller {
  initialize() {
    this.leaving = new Set()
    this.generation = 0
    this.onBeforeMorphAttribute = this.guardAttribute.bind(this)
    this.onBeforeMorphElement = this.holdLeavingError.bind(this)
    this.onMorph = this.swapAfterMorph.bind(this)
    this.onBeforeCache = () => this.rest()
  }

  connect() {
    this.invalid = this.element.dataset.invalid === "true"
    this.element.addEventListener("turbo:before-morph-attribute", this.onBeforeMorphAttribute)
    this.element.addEventListener("turbo:before-morph-element", this.onBeforeMorphElement)
    this.element.addEventListener("turbo:morph-element", this.onMorph)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-morph-attribute", this.onBeforeMorphAttribute)
    this.element.removeEventListener("turbo:before-morph-element", this.onBeforeMorphElement)
    this.element.removeEventListener("turbo:morph-element", this.onMorph)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  // --- during the morph ----------------------------------------------------------------------

  // The morph sets every attribute to the server's markup, which would re-hide the outgoing part
  // at once and wipe the state presence is animating. The wrapper's data-invalid still changes,
  // and that is the state the swap is derived from. A role this controller gave an error is kept
  // too, so a message that changes while the field stays invalid is still announced.
  guardAttribute(event) {
    const { attributeName, mutationType } = event.detail
    if (!this.isPart(event.target)) return

    const presenceOwned = PRESENCE_ATTRIBUTES.includes(attributeName)
    const announcedRole = attributeName === "role" && mutationType === "remove" && this.isError(event.target)
    if (presenceOwned || announcedRole) event.preventDefault()
  }

  // A field that became valid loses its error from the server's markup. It is held in place so it
  // can run out, and removed once it has. If the next morph renders it again, it is matched and
  // kept.
  holdLeavingError(event) {
    const error = event.target
    if (!this.isError(error)) return

    if (event.detail.newElement) {
      this.leaving.delete(error)
    } else {
      event.preventDefault()
      this.leaving.add(error)
    }
  }

  // --- after the morph -----------------------------------------------------------------------

  swapAfterMorph(event) {
    if (event.target !== this.element) return

    const invalid = this.element.dataset.invalid === "true"
    if (invalid === this.invalid) return

    const error = this.parts(ERROR).find((part) => !this.leaving.has(part))
    this.invalid = invalid
    this.swap(invalid ? this.parts(DESCRIPTION) : [], invalid ? error : this.parts(DESCRIPTION)[0])
  }

  // Out, then in: the outgoing parts hold their space until presence settles their exit, then the
  // incoming part enters, so the field's height changes once rather than twice.
  async swap(outgoing, incoming) {
    const generation = ++this.generation

    // A part the morph has only just inserted is visible until told otherwise. Hiding it now, in
    // the same task as the morph, means it never paints before its turn.
    if (incoming && this.atRest(incoming) && !incoming.hasAttribute("hidden")) presence.reset(incoming)
    if (incoming && this.isError(incoming)) this.announce(incoming)

    await Promise.all([...outgoing.map((part) => presence.exit(part)), ...[...this.leaving].map((part) => this.runOut(part))])
    if (generation !== this.generation || !incoming) return

    presence.enter(incoming)
  }

  async runOut(error) {
    const settled = await presence.exit(error)
    if (settled && this.leaving.has(error)) {
      this.leaving.delete(error)
      error.remove()
    }
  }

  // --- rest ----------------------------------------------------------------------------------

  // The resting state for the current data-invalid, at once, so a Turbo snapshot never holds a
  // part mid-swap, a leaving error, or a role that would announce again on restore. Only parts a
  // swap has touched carry data-state; the rest are still exactly what the server rendered.
  rest() {
    this.generation += 1
    this.leaving.forEach((error) => error.remove())
    this.leaving.clear()

    const invalid = this.element.dataset.invalid === "true"
    this.parts(ERROR).forEach((error) => error.removeAttribute("role"))
    this.parts(DESCRIPTION).forEach((part) => this.settle(part, !invalid))
    this.parts(ERROR).forEach((part) => this.settle(part, invalid))
    this.invalid = invalid
  }

  settle(part, shown) {
    if (this.atRest(part)) return

    presence.reset(part)
    if (!shown) return

    part.removeAttribute("hidden")
    delete part.dataset.state
  }

  // --- helpers -------------------------------------------------------------------------------

  // A node with role="alert" is announced as it enters the accessibility tree, which is when
  // presence removes its hidden attribute.
  announce(error) {
    error.setAttribute("role", "alert")
  }

  atRest(part) {
    return !part.dataset.state
  }

  parts(slot) {
    return [...this.element.children].filter((child) => child.dataset.slot === slot)
  }

  isPart(node) {
    return node.parentElement === this.element && [DESCRIPTION, ERROR].includes(node.dataset?.slot)
  }

  isError(node) {
    return node instanceof Element && node.parentElement === this.element && node.dataset.slot === ERROR
  }
}
