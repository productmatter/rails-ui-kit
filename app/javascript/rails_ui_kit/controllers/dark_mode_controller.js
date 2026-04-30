import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  initialize() {
    const savedTheme = localStorage.getItem("theme")

    if (savedTheme) {
      this.applyTheme(savedTheme, false)
    } else {
      const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
      this.applyTheme(prefersDark ? "dark" : "light", false)
    }
  }

  connect() {
    this.storageHandler = this.handleStorageChange.bind(this)
    window.addEventListener("storage", this.storageHandler)

    if (this.hasToggleTarget) {
      this.updateToggleButton(this.currentTheme)
    }
  }

  disconnect() {
    window.removeEventListener("storage", this.storageHandler)
  }

  toggle(event) {
    const newTheme = this.currentTheme === "dark" ? "light" : "dark"
    this.applyTheme(newTheme, true)
    localStorage.setItem("theme", newTheme)
  }

  applyTheme(theme, updateButton = true) {
    if (theme === "dark") {
      document.documentElement.classList.add("dark")
    } else {
      document.documentElement.classList.remove("dark")
    }

    if (updateButton && this.hasToggleTarget) {
      this.updateToggleButton(theme)
    }
  }

  updateToggleButton(theme) {
    const label = theme === "dark" ? "Switch to light mode" : "Switch to dark mode"
    this.toggleTarget.setAttribute("aria-label", label)
  }

  handleStorageChange(event) {
    if (event.key === "theme" && event.newValue) {
      this.applyTheme(event.newValue, true)
    }
  }

  get currentTheme() {
    return document.documentElement.classList.contains("dark") ? "dark" : "light"
  }
}
