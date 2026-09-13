import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  initialize() {
    const savedTheme = this.readStoredTheme()

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
    this.writeStoredTheme(newTheme)
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
    this.toggleTargets.forEach(target => {
      target.setAttribute("aria-label", label)
      target.setAttribute("aria-pressed", theme === "dark" ? "true" : "false")
    })
  }

  handleStorageChange(event) {
    if (event.key === "theme" && event.newValue) {
      this.applyTheme(event.newValue, true)
    }
  }

  get currentTheme() {
    return document.documentElement.classList.contains("dark") ? "dark" : "light"
  }

  readStoredTheme() {
    try {
      return localStorage.getItem("theme")
    } catch (error) {
      return null
    }
  }

  writeStoredTheme(theme) {
    try {
      localStorage.setItem("theme", theme)
    } catch (error) {
      // Storage can throw in private browsing, embedded/sandboxed contexts,
      // or when disabled by the user — the toggle still works, it just
      // won't persist across reloads.
    }
  }
}
