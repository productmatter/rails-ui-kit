// Primitive D -- presence, as a plain module.
//
// The platform has no "hold this element until its exit animation has finished": both
// <dialog>.close() and a popover hide are immediate. This is that, and nothing else. It
// moves an element through data-state="open" | "closing" | "closed", keeps it laid out
// while it animates out, and never guesses a duration -- the wait ends on the element's
// own animation events, with a timer only as a bounded safety net.
//
// It lives outside ui--presence because ui--overlay needs the behaviour, not the
// controller; composing by import beats reaching across controllers through outlets.

const DEFAULT_TIMEOUT = 1000
const END_EVENTS = ["transitionend", "transitioncancel", "animationend", "animationcancel"]
const REDUCED_MOTION = "(prefers-reduced-motion: reduce)"

// Per-element bookkeeping: which transition is current, and how to abandon it.
const transitions = new WeakMap()

function stateFor(element) {
  let state = transitions.get(element)

  if (!state) {
    state = { generation: 0, cancel: null }
    transitions.set(element, state)
  }

  return state
}

// Interruption is settled state, not a race: every new request abandons the one in flight,
// whose promise resolves false so its caller knows it was superseded and does nothing more.
function supersede(element) {
  const state = stateFor(element)
  const cancel = state.cancel

  state.generation += 1
  state.cancel = null
  if (cancel) cancel()

  return state.generation
}

function announce(element, name) {
  element.dispatchEvent(new CustomEvent(name, { bubbles: true }))
}

// Read at transition time, not at connect, so changing the setting mid-session is honoured.
function prefersReducedMotion() {
  return window.matchMedia(REDUCED_MOTION).matches
}

const times = (value) => value.split(",").map((part) => parseFloat(part) || 0)
const at = (values, index) => values[index % values.length] || 0

// The longest declared animation or transition on the element, in milliseconds. Zero means
// "nothing is declared", which is what makes an element with no transition close in the same
// frame rather than waiting out a timeout. An infinite animation reports Infinity, which the
// caller's ceiling turns into the safety timer.
function declaredDuration(element) {
  const style = getComputedStyle(element)
  const iterations = style.animationIterationCount
    .split(",")
    .map((count) => (count.trim() === "infinite" ? Infinity : parseFloat(count) || 0))

  const transitionTimes = times(style.transitionDuration).map(
    (duration, index) => duration + at(times(style.transitionDelay), index)
  )
  const animationTimes = times(style.animationDuration).map(
    (duration, index) => duration * at(iterations, index) + at(times(style.animationDelay), index)
  )

  return Math.max(0, ...transitionTimes, ...animationTimes) * 1000
}

// Whether the element itself is still animating. Descendants have their own animations and
// are not asked; their events bubble through here and are ignored for the same reason.
function animating(element) {
  return element
    .getAnimations()
    .some(({ playState }) => playState !== "finished" && playState !== "idle")
}

// The whole primitive. Resolves true once the element has finished animating, false if a
// later enter/exit/reset superseded this one.
function settle(element, state, generation, timeout) {
  return new Promise((resolve) => {
    if (state.generation !== generation) return resolve(false)

    const duration = declaredDuration(element)
    // getAnimations() flushes pending style changes, so a declared transition that nothing
    // actually changes is answered here rather than waited out.
    if (prefersReducedMotion() || duration === 0 || !animating(element)) return resolve(true)

    const finish = (settled) => {
      clearTimeout(timer)
      END_EVENTS.forEach((name) => element.removeEventListener(name, onEnd))
      if (state.cancel === cancel) state.cancel = null
      resolve(settled)
    }

    const onEnd = (event) => {
      if (event.target !== element) return
      if (animating(element)) return

      finish(true)
    }

    const cancel = () => finish(false)

    END_EVENTS.forEach((name) => element.addEventListener(name, onEnd))
    // Bounded safety net for an animation that is interrupted, or never fires at all.
    const timer = setTimeout(() => finish(true), Math.min(duration * 1.5 + 50, timeout))
    state.cancel = cancel
  })
}

// Makes the element visible and runs it to data-state="open". Resolves true once the entry
// transition has settled, false if superseded.
export function enter(element, { timeout = DEFAULT_TIMEOUT } = {}) {
  const generation = supersede(element)
  const state = stateFor(element)

  element.removeAttribute("hidden")
  if (element.dataset.state === "open") return Promise.resolve(true)

  const run = () => {
    if (state.generation !== generation) return Promise.resolve(false)

    element.dataset.state = "open"

    return settle(element, state, generation, timeout).then((settled) => {
      if (settled) announce(element, "ui--presence:opened")
      return settled
    })
  }

  // Interrupting an exit: the element is already laid out mid-animation, so it reverses from
  // where it is. Otherwise the closed state is flushed first, to give the entry transition a
  // start state to run from.
  if (element.dataset.state === "closing") return run()

  element.dataset.state = "closed"
  void element.offsetHeight // flushes the closed state, so the entry transition has somewhere to run from

  if (prefersReducedMotion()) return run()

  return new Promise((resolve) => {
    const frame = requestAnimationFrame(() => resolve(run()))
    state.cancel = () => {
      cancelAnimationFrame(frame)
      resolve(false)
    }
  })
}

// Runs the element out: data-state="closing" while it stays visible and laid out, then
// closed plus the hidden attribute once the exit animation has settled.
export function exit(element, { timeout = DEFAULT_TIMEOUT } = {}) {
  const generation = supersede(element)
  const state = stateFor(element)

  if (element.dataset.state === "closed" && element.hasAttribute("hidden")) {
    return Promise.resolve(true)
  }

  element.dataset.state = "closing"
  announce(element, "ui--presence:closing")

  return settle(element, state, generation, timeout).then((settled) => {
    if (!settled || state.generation !== generation) return false

    element.dataset.state = "closed"
    element.setAttribute("hidden", "")
    announce(element, "ui--presence:closed")

    return true
  })
}

// The closed resting state, at once: no animation, no pending timer or frame, no events.
// This is what connect, disconnect and turbo:before-cache use, so a snapshot is never
// cached mid-transition or open.
export function reset(element) {
  supersede(element)
  element.dataset.state = "closed"
  element.setAttribute("hidden", "")
}
