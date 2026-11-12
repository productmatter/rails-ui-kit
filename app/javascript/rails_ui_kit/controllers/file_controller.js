import { Controller } from "@hotwired/stimulus"

// File. The native <input type="file"> is the control and the only place the file lives: it is laid
// over the whole box, so a press opens the platform picker and a drop is the browser's own drop onto
// a file input. This controller owns only what the platform can't show:
//
//   - the swap from the drop area to the file row once a file is chosen, with the file's name and
//     size (a host that knows more -- a PDF's page count -- writes the meta target itself, on
//     `ui--file:chosen`);
//   - the drop target while a file is dragged over the box (`data-dragging`);
//   - refusing a dropped file `accept` doesn't allow: a browser applies `accept` to its picker,
//     never to a drop.
//
//   <div data-controller="ui--file" data-state="empty|chosen">
//     <input type="file" data-ui--file-target="input" data-action="change->ui--file#render">
//     <div data-ui--file-target="empty">…</div>
//     <div data-ui--file-target="chosen"><span data-ui--file-target="name"></span>
//       <span data-ui--file-target="meta"></span></div>
//   </div>
//
// Events: `ui--file:chosen` (detail: { file }) once a file is chosen, and `ui--file:rejected`
// (detail: { files }) when a drop is refused. The input's own `change` is what a form listens to.
export default class extends Controller {
  static targets = ["input", "empty", "chosen", "name", "meta"]

  static values = {
    // The locale the component's strings resolved in, so the size reads in the same language.
    locale: { type: String, default: "" }
  }

  initialize() {
    this.onFormReset = () => setTimeout(() => this.render())
    this.onBeforeCache = () => this.restore()
  }

  connect() {
    // What the server rendered for a file the record already has: a reset or a cancelled pick goes
    // back to it.
    this.initial = {
      state: this.element.dataset.state,
      name: this.hasNameTarget ? this.nameTarget.textContent : "",
      meta: this.hasMetaTarget ? this.metaTarget.textContent : ""
    }
    this.form?.addEventListener("reset", this.onFormReset)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
    this.render()
  }

  disconnect() {
    this.form?.removeEventListener("reset", this.onFormReset)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  // --- the mirror ----------------------------------------------------------------------------

  // Everything shown is derived from the input: a file in it is the row, no file is whatever the
  // server rendered.
  render() {
    const file = this.inputTarget.files?.[0]
    if (!file) return this.restore()

    this.show("chosen", file.name, this.formatSize(file.size))
    this.dispatch("chosen", { detail: { file } })
  }

  restore() {
    const { state, name, meta } = this.initial || {}
    this.show(state === "chosen" ? "chosen" : "empty", name, meta)
  }

  show(state, name, meta) {
    this.element.dataset.state = state
    if (this.hasEmptyTarget) this.emptyTarget.hidden = state !== "empty"
    if (this.hasChosenTarget) this.chosenTarget.hidden = state !== "chosen"
    if (this.hasNameTarget) this.nameTarget.textContent = name || ""
    if (this.hasMetaTarget) {
      this.metaTarget.textContent = meta || ""
      this.metaTarget.hidden = !meta
    }
    this.describe(state)
  }

  // The input is described by whichever part is showing -- the drop area's meta line, or the file
  // row -- after the Field's own ids, so a screen reader hears the state the box shows.
  describe(state) {
    const id = this.inputTarget.id
    const own = [`${id}-meta`, `${id}-file`]
    const ids = (this.inputTarget.getAttribute("aria-describedby") || "").split(/\s+/).filter((token) => token && !own.includes(token))
    const showing = state === "chosen" ? `${id}-file` : `${id}-meta`
    if (document.getElementById(showing)) ids.push(showing)

    if (ids.length) this.inputTarget.setAttribute("aria-describedby", ids.join(" "))
    else this.inputTarget.removeAttribute("aria-describedby")
  }

  // Bytes in the largest unit that keeps the number above one, in the component's locale:
  // "372 kB", "1.4 MB".
  formatSize(bytes) {
    const units = ["byte", "kilobyte", "megabyte", "gigabyte"]
    let value = bytes
    let unit = 0
    while (value >= 1000 && unit < units.length - 1) {
      value /= 1000
      unit += 1
    }
    try {
      return new Intl.NumberFormat(this.localeValue || undefined, {
        style: "unit", unit: units[unit], unitDisplay: "short", maximumFractionDigits: unit < 2 ? 0 : 1
      }).format(value)
    } catch {
      return `${Math.round(value)} ${["B", "kB", "MB", "GB"][unit]}`
    }
  }

  // --- dragging --------------------------------------------------------------------------------

  // A drag over a child fires leave on the box and enter on the child, so entries are counted
  // rather than trusting the last event.
  dragenter(event) {
    if (!this.carriesFiles(event)) return
    this.depth = (this.depth || 0) + 1
    this.setDragging(event)
  }

  dragover(event) {
    if (!this.carriesFiles(event)) return
    this.setDragging(event)
  }

  dragleave() {
    this.depth = Math.max((this.depth || 1) - 1, 0)
    if (this.depth === 0) delete this.element.dataset.dragging
  }

  // The browser puts a dropped file in the input itself. Only a refused drop is stopped here,
  // before it does.
  drop(event) {
    this.depth = 0
    delete this.element.dataset.dragging
    const files = Array.from(event.dataTransfer?.files || [])
    if (this.inputTarget.disabled || files.length === 0 || files.every((file) => this.accepts(file))) return

    event.preventDefault()
    this.dispatch("rejected", { detail: { files } })
  }

  // While dragging, only the item's type is known -- not its name -- so a type `accept` refuses is
  // shown as not droppable; an extension-only `accept` waits for the drop.
  setDragging(event) {
    if (this.inputTarget.disabled) return
    const refused = this.draggedTypes(event).some((type) => type && !this.acceptsType(type, null))
    this.element.dataset.dragging = refused ? "refused" : "true"
    if (refused) {
      event.preventDefault()
      event.dataTransfer.dropEffect = "none"
    }
  }

  carriesFiles(event) {
    return Array.from(event.dataTransfer?.types || []).includes("Files")
  }

  draggedTypes(event) {
    return Array.from(event.dataTransfer?.items || []).filter((item) => item.kind === "file").map((item) => item.type)
  }

  // --- accept ----------------------------------------------------------------------------------

  // The HTML accept list: extensions (".pdf"), exact types ("application/pdf") and wildcards
  // ("image/*"). An empty list accepts everything, as the input does. A null name is a drag still in
  // flight, whose name isn't known yet: an extension can't refuse it until the drop.
  get acceptList() {
    return (this.inputTarget.accept || "").split(",").map((token) => token.trim().toLowerCase()).filter(Boolean)
  }

  accepts(file) {
    return this.acceptsType(file.type, file.name)
  }

  acceptsType(type, name) {
    const list = this.acceptList
    if (list.length === 0) return true

    const mime = (type || "").toLowerCase()
    return list.some((token) => {
      if (token.startsWith(".")) return name === null || name.toLowerCase().endsWith(token)
      if (token.endsWith("/*")) return mime.startsWith(token.slice(0, -1))
      return mime === token
    })
  }

  get form() {
    return this.inputTarget.form
  }
}
