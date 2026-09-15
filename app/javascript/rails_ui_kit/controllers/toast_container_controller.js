import { Controller } from "@hotwired/stimulus"

const TOAST_EVENT = "rails-ui-kit:toast"

// The same rules Ui::Toast::Payload and Ui::Toast::Action apply in Ruby (ui-toast § Behavior,
// items 1, 6, 9 and 15), so a payload is accepted or rejected the same way from every entry point.
const TYPES = ["success", "error", "notice", "alert", "warning", "info"]
const KEYS = ["type", "title", "description", "actions", "duration", "icon"]
const RENAMED = { body: "description", timeout: "duration" }
const ACTION_KEYS = ["label", "href", "method", "variant", "class", "dismiss"]
const METHODS = ["get", "post", "patch", "put", "delete"]
const DEFAULT_VARIANT = "outline"
const ERROR_DURATION = 20000
const DEFAULT_DURATION = 3000

// The WHATWG URL parser's own first steps: strip leading and trailing C0 controls and spaces, and
// every tab and newline. Then any scheme must be http or https, and the browser's parser confirms.
const EDGE_CONTROLS = /^[\x00-\x20]+|[\x00-\x20]+$/g
const TAB_OR_NEWLINE = /[\t\n\r]/g
const SCHEME = /^[A-Za-z][A-Za-z0-9+.-]*:/

export function allowedHref(href) {
  if (typeof href !== "string") return false

  const cleaned = href.replace(EDGE_CONTROLS, "").replace(TAB_OR_NEWLINE, "")
  if (!cleaned) return false

  const scheme = cleaned.match(SCHEME)
  if (scheme && !["http:", "https:"].includes(scheme[0].toLowerCase())) return false

  try {
    return ["http:", "https:"].includes(new URL(href, document.baseURI).protocol)
  } catch {
    return false
  }
}

// Where toasts appear, and the three ways in: server-rendered children, a Turbo Stream appending
// to the stack, and window.triggerToast / the rails-ui-kit:toast event, which clone the templates
// Ui::ToastContainerComponent rendered. JavaScript writes text, URLs, ids and data attributes into
// those clones and removes the parts a payload leaves out. It never writes a class
// (ui-toast § Business rules, rule 2).
export default class extends Controller {
  static targets = ["template", "actionTemplate", "stack", "politeRegion", "assertiveRegion"]
  // Ui::ToastContainerComponent renders these from I18n and from Ui::Base.raise_on_unknown_variant?.
  // The literal is only the fallback for a hand-written container that never set the attribute.
  static values = {
    defaultTitle: { type: String, default: "Notification" },
    actionsHint: String,
    strict: Boolean
  }

  connect() {
    this.onToastEvent = (event) => this.showToast(event.detail)
    this.onKeydown = this.reachOnF8.bind(this)
    this.onBeforeCache = () => this.toasts.forEach((toast) => toast.remove())

    document.addEventListener(TOAST_EVENT, this.onToastEvent)
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)

    this.previousTriggerToast = window.triggerToast
    this.boundShowToast = (first, second) => this.showToast(first, second)
    window.triggerToast = this.boundShowToast

    if (this.hasStackTarget) {
      this.stackObserver = new MutationObserver(() => this.syncLandmark())
      this.stackObserver.observe(this.stackTarget, { childList: true })
      this.syncLandmark()
    }
  }

  disconnect() {
    document.removeEventListener(TOAST_EVENT, this.onToastEvent)
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    this.stackObserver?.disconnect()

    if (window.triggerToast === this.boundShowToast) window.triggerToast = this.previousTriggerToast
  }

  get toasts() {
    return this.hasStackTarget ? Array.from(this.stackTarget.querySelectorAll('[data-controller~="ui--toast"]')) : []
  }

  // A landmark only while it holds a toast, so a landmark list carries no empty region.
  syncLandmark() {
    this.stackTarget.hidden = this.stackTarget.children.length === 0
  }

  // --- Entry point 3 -----------------------------------------------------------------------

  // window.triggerToast(payload), or 0.2.0's triggerToast(type, content) where content is text
  // (the description) or a payload without its type. The event's detail is a payload, or 0.2.0's
  // { type, message }.
  showToast(first, second) {
    const payload = this.readPayload(this.rawPayload(first, second))
    const toast = this.buildToast(payload)
    this.stackTarget.appendChild(toast)
    return toast
  }

  rawPayload(first, second) {
    if (typeof first === "string") {
      if (typeof second === "string") return { type: first, description: second }
      return { ...(isObject(second) ? second : {}), type: first }
    }
    if (!isObject(first)) return {}

    const { message, ...rest } = first
    if (!("message" in first)) return { ...first }
    if (typeof message === "string") return { ...rest, description: message }
    return { ...(isObject(message) ? message : {}), ...rest }
  }

  readPayload(raw) {
    const attributes = { ...raw }
    Object.entries(RENAMED).forEach(([old, renamed]) => {
      if (!(old in attributes)) return
      this.invalid(`${old} is now ${renamed}. Rename it; ${renamed} is used in its place.`)
      if (!(renamed in attributes)) attributes[renamed] = attributes[old]
      delete attributes[old]
    })

    const unknown = Object.keys(attributes).filter((key) => !KEYS.includes(key))
    if (unknown.length) this.invalid(`unknown keys ${unknown.join(", ")}; expected ${KEYS.join(", ")}. They are ignored.`)

    const type = this.readType(attributes.type)
    const actions = this.readActions(attributes.actions)
    return {
      type,
      title: this.readText("title", attributes.title),
      description: this.readText("description", attributes.description),
      actions,
      duration: this.readDuration(attributes.duration, type, actions),
      icon: this.readIcon(attributes.icon)
    }
  }

  readType(value) {
    if (value === undefined || value === null) return "info"
    if (TYPES.includes(String(value))) return String(value)

    this.invalid(`there is no type ${JSON.stringify(value)}; expected one of ${TYPES.join(", ")}. Rendering info instead.`)
    return "info"
  }

  readText(key, value) {
    if (value === undefined || value === null || typeof value === "string") return value || ""

    this.invalid(`${key} must be a string, got ${typeof value}. It is left out.`)
    return ""
  }

  readDuration(value, type, actions) {
    const fallback = actions.length ? 0 : (type === "error" ? ERROR_DURATION : DEFAULT_DURATION)
    if (value === undefined || value === null) return fallback
    if (Number.isInteger(value) && value >= 0) return value
    if (typeof value === "string" && /^\d+$/.test(value)) return Number(value)

    this.invalid(`duration must be a whole number of milliseconds, 0 or more, got ${JSON.stringify(value)}. The default is used instead.`)
    return fallback
  }

  readIcon(value) {
    if (value === undefined || value === null) return true
    if (value === false) return false

    this.invalid(`icon accepts only false, which removes the glyph, got ${JSON.stringify(value)}. The type's glyph is kept.`)
    return true
  }

  readActions(value) {
    if (value === undefined || value === null) return []
    if (!Array.isArray(value)) {
      this.invalid("actions must be an array. They are left out.")
      return []
    }
    return value.map((action) => this.readAction(action)).filter(Boolean)
  }

  readAction(raw) {
    if (!isObject(raw)) return this.rejectAction(undefined, "must be an object")

    const label = raw.label
    const unknown = Object.keys(raw).filter((key) => !ACTION_KEYS.includes(key))
    if (unknown.length) return this.rejectAction(label, `has unknown keys ${unknown.join(", ")}; expected ${ACTION_KEYS.join(", ")}`)
    if (typeof label !== "string" || !label.trim()) return this.rejectAction(label, "needs a label: it is the visible text and the accessible name")
    if ("class" in raw) {
      return this.rejectAction(label, "sets class, which only Ruby and a Turbo Stream can merge; style it with variant")
    }

    const variant = String(raw.variant ?? DEFAULT_VARIANT)
    if (!this.actionTemplate("button", variant)) return this.rejectAction(label, `has no variant ${variant}`)

    const href = raw.href
    if (raw.method !== undefined && href === undefined) return this.rejectAction(label, "sets method without an href, so it would do nothing")
    const method = String(raw.method ?? "get").toLowerCase()
    if (!METHODS.includes(method)) return this.rejectAction(label, `has no method ${raw.method}; expected one of ${METHODS.join(", ")}`)
    if (href !== undefined && !allowedHref(href)) return this.rejectAction(label, `has href ${JSON.stringify(href)}, which is not a relative or http(s) URL`)

    const dismiss = raw.dismiss ?? true
    if (typeof dismiss !== "boolean") return this.rejectAction(label, "sets dismiss to something other than true or false")
    if (!dismiss && href === undefined) return this.rejectAction(label, "sets dismiss: false without an href, so it would do nothing")

    return { label, href, method, variant, dismiss, kind: href === undefined ? "button" : (method === "get" ? "link" : "form") }
  }

  rejectAction(label, problem) {
    this.invalid(`the action ${JSON.stringify(label)} ${problem}. The action is dropped.`)
    return null
  }

  invalid(problem) {
    const message = `triggerToast: ${problem}`
    if (this.strictValue) throw new Error(message)

    console.warn(`[rails_ui_kit] ${message}`)
  }

  // --- Building from templates -------------------------------------------------------------

  buildToast(payload) {
    const template = this.templateTargets.find((element) => element.dataset.toastType === payload.type)
    const toast = template.content.firstElementChild.cloneNode(true)
    const id = `ui-toast-${Math.random().toString(16).slice(2, 14)}`
    toast.id = id

    const title = toast.querySelector("[data-slot=toast-title]")
    const description = toast.querySelector("[data-slot=toast-description]")
    const titleText = payload.title || (payload.description ? "" : this.defaultTitleValue)

    this.fill(title, titleText, `${id}-title`)
    this.fill(description, payload.description, `${id}-description`)
    toast.setAttribute("aria-labelledby", titleText ? title.id : description.id)
    if (titleText && payload.description) {
      toast.setAttribute("aria-describedby", description.id)
    } else {
      toast.removeAttribute("aria-describedby")
    }

    if (payload.icon === false) toast.querySelector("[data-slot=toast-icon]")?.remove()
    this.fillActions(toast.querySelector("[data-slot=toast-actions]"), payload.actions)

    toast.setAttribute("data-ui--toast-duration-value", String(payload.duration))
    if (payload.duration === 0) toast.querySelector("[data-slot=toast-progress]")?.remove()

    return toast
  }

  fill(element, text, id) {
    if (!text) return element.remove()

    element.id = id
    element.textContent = text
  }

  fillActions(footer, actions) {
    if (!actions.length) return footer.remove()

    actions.forEach((action) => footer.appendChild(this.buildAction(action)))
  }

  buildAction(action) {
    const node = this.actionTemplate(action.kind, action.variant).content.firstElementChild.cloneNode(true)
    const button = action.kind === "form" ? node.querySelector("[data-slot=button]") : node

    button.textContent = action.label
    button.setAttribute("data-ui--toast-dismiss-param", String(action.dismiss))

    if (action.kind === "link") node.setAttribute("href", action.href)
    if (action.kind === "form") {
      node.setAttribute("action", action.href)
      const methodField = node.querySelector("input[name=_method]")
      action.method === "post" ? methodField.remove() : methodField.setAttribute("value", action.method)
    }
    return node
  }

  actionTemplate(kind, variant) {
    return this.actionTemplateTargets.find(
      (element) => element.dataset.actionKind === kind && element.dataset.actionVariant === variant
    )
  }

  // --- Reaching a toast (§ Behavior, item 12) ----------------------------------------------

  // F8 from anywhere moves focus to the newest toast's first action, or its close button. With no
  // toast, F8 isn't intercepted.
  reachOnF8(event) {
    if (event.key !== "F8" || event.defaultPrevented) return

    const target = this.focusTargetIn(this.liveToasts().pop())
    if (!target) return

    event.preventDefault()
    const active = document.activeElement
    if (active && active !== document.body && !this.stackTarget.contains(active)) this.returnFocus = active
    target.focus()
  }

  // Called by a toast closing with focus inside it: back to where F8 came from, else the
  // next-newest toast, else the page.
  restoreFocus(closing) {
    if (this.returnFocus?.isConnected && !closing.contains(this.returnFocus)) {
      this.returnFocus.focus()
      return
    }

    const next = this.focusTargetIn(this.liveToasts().filter((toast) => toast !== closing).pop())
    if (next) return next.focus()

    document.activeElement?.blur()
  }

  liveToasts() {
    return this.toasts.filter((toast) => toast.dataset.state !== "closing" && !toast.hidden)
  }

  focusTargetIn(toast) {
    if (!toast) return null
    return toast.querySelector("[data-slot=toast-actions] [data-slot=button]") ||
      toast.querySelector('[data-action~="click->ui--toast#close"]')
  }
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}
