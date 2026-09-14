import { Controller } from "@hotwired/stimulus"

// A matchMedia watcher. Sidebar and Drawer (Phase C) read data-media-matches or the
// optional matches class to decide layout; nothing here shows, hides or measures
// anything itself.
export default class extends Controller {
  static values = { query: String }
  static classes = ["matches"]

  connect() {
    this.mediaQueryList = window.matchMedia(this.queryValue)
    this.onChange = this.onChange.bind(this)
    this.mediaQueryList.addEventListener("change", this.onChange)

    this.update(this.mediaQueryList.matches)
  }

  disconnect() {
    this.mediaQueryList.removeEventListener("change", this.onChange)
  }

  onChange(event) {
    this.update(event.matches)
  }

  update(matches) {
    this.element.setAttribute("data-media-matches", matches)
    if (this.hasMatchesClass) this.element.classList.toggle(this.matchesClass, matches)

    this.dispatch("change", { detail: { matches, query: this.queryValue } })
  }
}
