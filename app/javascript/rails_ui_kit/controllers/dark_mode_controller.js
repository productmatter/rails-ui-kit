import { Controller } from "@hotwired/stimulus"

// Namespaced, because "theme" is a key a host app plausibly uses for itself, with values of its own.
// The unprefixed key is still read when ours is unset, so a preference saved before the rename
// survives; the <head> no-flash script on the Dark Mode docs page reads both the same way.
const STORAGE_KEY = "rails_ui_kit:theme"
const LEGACY_STORAGE_KEY = "theme"
const THEMES = ["dark", "light"]

export default class extends Controller {
  static targets = ["toggle"]
  // No Ruby component owns this controller -- a host wires it up on its own toggle button -- so
  // there's nothing to render these from automatically. A host that wants them translated sets
  // the data attributes itself (see rails_ui_kit.dark_mode.* in the locale file); these literals
  // are only the fallback when it doesn't.
  static values = {
    lightLabel: { type: String, default: "Switch to light mode" },
    darkLabel: { type: String, default: "Switch to dark mode" }
  }

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
    const label = theme === "dark" ? this.lightLabelValue : this.darkLabelValue
    this.toggleTargets.forEach(target => {
      target.setAttribute("aria-label", label)
      target.setAttribute("aria-pressed", theme === "dark" ? "true" : "false")
    })
  }

  handleStorageChange(event) {
    if (event.key === STORAGE_KEY && THEMES.includes(event.newValue)) {
      this.applyTheme(event.newValue, true)
    }
  }

  get currentTheme() {
    return document.documentElement.classList.contains("dark") ? "dark" : "light"
  }

  // Anything but "dark" or "light" -- a host's own "system", say -- is no preference at all, and
  // the OS decides, as the <head> script does.
  readStoredTheme() {
    try {
      const theme = localStorage.getItem(STORAGE_KEY) || localStorage.getItem(LEGACY_STORAGE_KEY)
      return THEMES.includes(theme) ? theme : null
    } catch (error) {
      return null
    }
  }

  writeStoredTheme(theme) {
    try {
      localStorage.setItem(STORAGE_KEY, theme)
    } catch (error) {
      // Storage can throw in private browsing, embedded/sandboxed contexts,
      // or when disabled by the user — the toggle still works, it just
      // won't persist across reloads.
    }
  }
}
