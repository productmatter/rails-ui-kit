// Page-level state for Primitive B. The scroll-lock reference count, the one stacking value
// used where `popover` is unsupported, and the light-dismiss recovery batch are properties of
// the page, not of any element, so there is nothing for Stimulus to bind them to.
//
// There is deliberately no stack of open overlays and no depth counter here: paint order and
// dismiss ordering are the browser's top layer's, which is LIFO by construction.

// The one stacking value in the kit, applied only where `popover` is unsupported and there is
// no top layer to be placed in. Never per depth, and never in a component.
export const FALLBACK_Z_INDEX = 9999

export function supportsTopLayer() {
  return Object.prototype.hasOwnProperty.call(HTMLElement.prototype, "popover")
}

// --- Scroll lock -------------------------------------------------------------------------
//
// showModal() inerts the page behind it but does not stop it scrolling, and on mobile does
// not stop touch scrolling at all, so the lock is ours. Holders are counted, because the
// first overlay to close must not unlock the page underneath the second.

const holders = new Set()
let lock = null

export function lockScroll(holder) {
  if (holders.has(holder)) return

  holders.add(holder)
  if (holders.size === 1) applyLock()
}

export function unlockScroll(holder) {
  if (!holders.delete(holder)) return
  if (holders.size === 0) releaseLock()
}

const LOCKED_PROPERTIES = ["position", "top", "left", "right", "overflow", "paddingRight"]

function applyLock() {
  const root = document.documentElement
  const body = document.body
  // 0 with overlay scrollbars, which need no gutter and produce no shift either way.
  const scrollbar = window.innerWidth - root.clientWidth

  lock = {
    body,
    x: window.scrollX,
    y: window.scrollY,
    gutter: root.style.scrollbarGutter,
    style: Object.fromEntries(LOCKED_PROPERTIES.map((property) => [property, body.style[property]]))
  }

  // Reserve the scrollbar's gutter before it disappears, so locking shifts nothing sideways.
  // CSS does it without measuring anything, including for fixed-position elements; the
  // measured padding is the fallback where scrollbar-gutter isn't supported.
  if (scrollbar > 0) {
    if (CSS.supports("scrollbar-gutter", "stable")) {
      root.style.scrollbarGutter = "stable"
    } else {
      body.style.paddingRight = `${parseFloat(getComputedStyle(body).paddingRight) + scrollbar}px`
    }
  }

  // overflow: hidden alone is ignored by iOS Safari for touch scrolling; taking the body out
  // of flow at its current offset is what actually holds the page still there, and it is
  // correct everywhere else too.
  Object.assign(body.style, {
    position: "fixed",
    top: `${-lock.y}px`,
    left: `${-lock.x}px`,
    right: `${lock.x}px`,
    overflow: "hidden"
  })
}

function releaseLock() {
  const { body, x, y, gutter, style } = lock
  lock = null

  LOCKED_PROPERTIES.forEach((property) => { body.style[property] = style[property] })
  document.documentElement.style.scrollbarGutter = gutter

  // Restoring the scroll position in the same task as the styles means no frame is painted in
  // between, so the page never visibly jumps. A Turbo visit can swap <body> out from under an
  // open overlay; that page's scroll position is not this one's, so it is left alone.
  if (body === document.body) window.scrollTo({ left: x, top: y, behavior: "instant" })
}

// --- Light-dismiss recovery --------------------------------------------------------------
//
// The browser light-dismisses a nest of popovers from the top down. Putting them back (which
// is how an exit animation or a vetoed dismissal is possible at all -- see overlay_controller)
// has to happen outermost-first, or each one would close the one before it. Recoveries are
// therefore batched into a single frame and run in that order.

const recoveries = []

export function recoverFromLightDismiss(element, recover) {
  recoveries.push({ element, recover })
  if (recoveries.length > 1) return

  requestAnimationFrame(() => {
    recoveries.splice(0).sort(outermostFirst).forEach(({ recover: run }) => run())
  })
}

function outermostFirst(first, second) {
  const position = first.element.compareDocumentPosition(second.element)

  if (position & Node.DOCUMENT_POSITION_CONTAINED_BY) return -1
  if (position & Node.DOCUMENT_POSITION_CONTAINS) return 1

  return position & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1
}
