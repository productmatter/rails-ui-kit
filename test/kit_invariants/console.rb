# frozen_string_literal: true

require 'securerandom'

module KitInvariants
  # Invariant 7: nothing logged to console.error or console.warn, thrown or rejected since the
  # page first loaded. Capture is installed before any page script runs, and a check that finds
  # it missing fails rather than reporting silence.
  module Console
    extend ActiveSupport::Concern

    # Kept in sessionStorage under a key unique to this capture, so a full page load (a form with
    # Turbo off) doesn't wipe what the previous document logged, and no earlier test's entries are
    # read back.
    CAPTURE = <<~JS
      (() => {
        if (window.top !== window || window.__kitConsoleInstalled) return
        const key = "__kitConsole:__TOKEN__"
        let entries = []
        try { entries = JSON.parse(sessionStorage.getItem(key) || "[]") } catch (error) {}
        window.__kitConsole = entries
        const text = (part) => {
          if (part instanceof Error) return part.stack || String(part)
          if (typeof part === "string") return part
          try { return JSON.stringify(part) } catch (error) { return String(part) }
        }
        const record = (kind, parts) => {
          entries.push(`${kind}: ${parts.map(text).join(" ")}`)
          try { sessionStorage.setItem(key, JSON.stringify(entries)) } catch (error) {}
        }
        for (const level of ["error", "warn"]) {
          const original = console[level]
          console[level] = function (...args) {
            record(`console.${level}`, args)
            return original.apply(this, args)
          }
        }
        window.addEventListener("error", (event) => record("uncaught error", [event.error || event.message]))
        window.addEventListener("unhandledrejection", (event) => record("unhandled rejection", [event.reason]))
        window.__kitConsoleInstalled = true
      })()
    JS

    REPORT = <<~JS
      window.__kitConsoleInstalled ? [...window.__kitConsole] : ["console capture was not installed: call capture_console before the visit"]
    JS

    included do
      teardown { remove_console_capture }
    end

    # Call before the first visit, and before registering any other script on new documents:
    # Chrome runs them in the order they were added, so one added earlier logs before capture.
    def capture_console
      @console_capture = add_script_to_new_documents(CAPTURE.sub('__TOKEN__', SecureRandom.hex(8)))
    end

    # Registers a script Chrome runs on every new document before the page's own, and returns the
    # identifier that removes it. It outlives the test in the shared browser unless removed.
    def add_script_to_new_documents(source)
      browser = cdp_browser
      flunk 'a script on new documents needs a driver with a CDP session' unless browser

      browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument', source: source)['identifier']
    end

    def remove_script_from_new_documents(identifier)
      cdp_browser&.execute_cdp('Page.removeScriptToEvaluateOnNewDocument', identifier: identifier)
    end

    private

    def console_failures
      { console: page.evaluate_script(REPORT) }
    end

    def remove_console_capture
      return unless @console_capture

      remove_script_from_new_documents(@console_capture)
      @console_capture = nil
    end
  end
end
