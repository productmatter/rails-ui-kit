import { Controller } from "@hotwired/stimulus"
import { computePosition, autoUpdate, flip, shift, offset, arrow } from "@floating-ui/dom"

// The only module in the kit that imports Floating UI. It computes geometry and publishes it;
// it never shows, hides, portals, moves focus or writes data-state. Components drive it through
// a Stimulus outlet by setting activeValue, and style from the data-side / data-align it writes.
//
//   <div data-controller="ui--anchor" data-ui--anchor-placement-value="bottom-start"
//        data-ui--anchor-active-value="true">
//     <div data-ui--anchor-target="anchor"><button type="button">Options</button></div>
//     <div data-ui--anchor-target="floating" class="absolute">…</div>
//   </div>

const FOCUSABLE = 'button, a[href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
const STATIC_SIDE = { top: "bottom", right: "left", bottom: "top", left: "right" }

export default class extends Controller {
  static targets = ["anchor", "floating", "arrow"]

  static values = {
    placement: { type: String, default: "bottom" },
    offset: { type: Number, default: 8 },
    padding: { type: Number, default: 8 },
    flip: { type: Boolean, default: true },
    shift: { type: Boolean, default: true },
    matchWidth: { type: Boolean, default: false },
    strategy: { type: String, default: "absolute" },
    arrowPadding: { type: Number, default: 4 },
    active: { type: Boolean, default: false }
  }

  // Stimulus replays stored values, and connects targets, before connect(). Nothing starts until
  // connect() has run, so an element restored from Turbo's cache begins from its markup alone.
  connect() {
    this.connected = true
    this.sync()
  }

  disconnect() {
    this.connected = false
    this.stop()
  }

  activeValueChanged() {
    this.sync()
  }

  // A change to any value that shapes the computation repositions at once, not on the next scroll.
  placementValueChanged() { this.update() }
  offsetValueChanged() { this.update() }
  paddingValueChanged() { this.update() }
  flipValueChanged() { this.update() }
  shiftValueChanged() { this.update() }
  matchWidthValueChanged() { this.update() }
  strategyValueChanged() { this.update() }
  arrowPaddingValueChanged() { this.update() }

  // A Turbo Stream that swaps the anchor or the floating element must not leave autoUpdate
  // watching the element that left: restart against whatever is there now.
  anchorTargetConnected() { this.restart() }
  anchorTargetDisconnected() { this.restart() }
  floatingTargetConnected() { this.restart() }
  floatingTargetDisconnected() { this.restart() }
  arrowTargetConnected() { this.update() }
  arrowTargetDisconnected() { this.update() }

  // Recomputes once. Public, so an owner can ask for a position after changing the floating
  // element's content in a way no observer sees; a no-op while inactive.
  update() {
    if (!this.running) return

    const reference = this.reference
    const floating = this.floatingTarget
    const arrowElement = this.hasArrowTarget ? this.arrowTarget : null
    const token = this.token

    if (this.matchWidthValue) floating.style.width = `${reference.offsetWidth}px`

    computePosition(reference, floating, {
      placement: this.placementValue,
      strategy: this.strategyValue,
      middleware: this.middleware(arrowElement)
    }).then(({ x, y, placement, strategy, middlewareData }) => {
      // A computation that resolves after stop() -- or after a restart -- belongs to a run that
      // no longer exists, and must not write or announce anything.
      if (token !== this.token) return
      this.apply({ floating, arrowElement, x, y, placement, strategy, middlewareData })
    })
  }

  // --- private ---

  sync() {
    if (this.connected && this.activeValue && this.hasAnchorTarget && this.hasFloatingTarget) {
      this.start()
    } else {
      this.stop()
    }
  }

  restart() {
    this.stop()
    this.sync()
  }

  start() {
    if (this.running) return

    this.running = true
    this.token = {}
    // autoUpdate runs update() once straight away, then on ancestor scroll, ancestor and window
    // resize, element resize and layout shift. Its return value releases every one of those.
    this.cleanupAutoUpdate = autoUpdate(this.reference, this.floatingTarget, () => this.update())
  }

  stop() {
    this.running = false
    this.token = null
    this.cleanupAutoUpdate?.()
    this.cleanupAutoUpdate = null
  }

  // The anchor target often wraps the caller's control, normally a <button>. In a block layout
  // that wrapper spans the full width, so positioning against it lands the floating element far
  // from the thing it points at. Measure the control; fall back to the target itself when it
  // holds nothing focusable.
  get reference() {
    const target = this.anchorTarget
    if (target.matches(FOCUSABLE)) return target
    return target.querySelector(FOCUSABLE) || target
  }

  middleware(arrowElement) {
    const padding = this.paddingValue
    const middleware = [offset(this.offsetValue)]

    if (this.flipValue) middleware.push(flip({ padding }))
    if (this.shiftValue) middleware.push(shift({ padding }))
    if (arrowElement) middleware.push(arrow({ element: arrowElement, padding: this.arrowPaddingValue }))

    return middleware
  }

  apply({ floating, arrowElement, x, y, placement, strategy, middlewareData }) {
    const [side, align = "center"] = placement.split("-")

    Object.assign(floating.style, { position: strategy, left: `${x}px`, top: `${y}px` })
    floating.dataset.side = side
    floating.dataset.align = align

    // Read defensively: the arrow middleware reports nothing when it did not run.
    const arrowData = middlewareData.arrow
    if (arrowElement && arrowData) {
      Object.assign(arrowElement.style, {
        left: arrowData.x != null ? `${arrowData.x}px` : "",
        top: arrowData.y != null ? `${arrowData.y}px` : "",
        right: "",
        bottom: "",
        [STATIC_SIDE[side]]: `${-arrowElement.offsetWidth / 2}px`
      })
    }

    this.dispatch("positioned", { detail: { x, y, placement, side, align } })
  }
}
