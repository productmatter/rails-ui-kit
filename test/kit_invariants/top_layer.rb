# frozen_string_literal: true

module KitInvariants
  # Invariants 1 to 4, which share one question -- what is open, and who says so:
  #   1. no scroll lock left: <html> and <body> styles as they arrived, or, while a declared
  #      overlay holds the lock, held; and every release put the page back where it locked. The
  #      scroll position itself isn't compared with arrival -- a driver's click scrolls its target
  #      into view, so that would fail on the test's own gestures;
  #   2. what is open is exactly what was declared, and each is claimed by a ui--overlay that
  #      agrees, with no ui--overlay claiming open content that isn't;
  #   3. nothing stuck closing, and nothing data-state="open" that isn't rendered;
  #   4. aria-expanded="true" exactly when what it controls is open.
  module TopLayer
    # The arrival snapshot, and a watch on <body> that records a lock released anywhere but where
    # it was taken. Installed once per document; Turbo keeps the window across visits.
    ARRIVAL = <<~JS
      window.__kitArrival = { html: document.documentElement.style.cssText, body: document.body.style.cssText }
      if (!window.__kitLockWatch) {
        const watch = window.__kitLockWatch = { releases: [], locked: null }
        new MutationObserver((records) => {
          const body = document.body
          if (!records.some((record) => record.target === body)) return
          if (watch.locked?.body !== body) watch.locked = null
          const fixed = body.style.position === "fixed"
          if (fixed && !watch.locked) {
            watch.locked = { body, x: -parseFloat(body.style.left || 0), y: -parseFloat(body.style.top || 0) }
          } else if (!fixed && watch.locked) {
            const { x, y } = watch.locked
            if (Math.abs(scrollX - x) > 1 || Math.abs(scrollY - y) > 1) watch.releases.push(`the scroll lock released at ${scrollX},${scrollY}, not ${x},${y} where it locked`)
            watch.locked = null
          }
        }).observe(document.documentElement, { attributes: true, attributeFilter: ["style"], subtree: true })
      }
    JS

    REPORT = <<~JS.freeze
      ((declaredOpen) => {
        #{DESCRIBE}
        const report = { scroll: [], open: [], transitions: [], expanded: [] }
        const OPEN = "dialog[open], :modal, :popover-open"
        const isOpen = (element) => element.matches(OPEN)
        const stimulus = window.Stimulus
        const overlayOn = (element) => stimulus?.getControllerForElementAndIdentifier?.(element, "ui--overlay")
        // Stimulus scopes targets, so an outer overlay never claims a nested overlay's content.
        const claimant = (element) => {
          for (let node = element; node; node = node.parentElement) {
            const controller = node.matches('[data-controller~="ui--overlay"]') && overlayOn(node)
            if (controller && controller.contentTargets.includes(element)) return controller
          }
          return null
        }
        const declared = declaredOpen.map((selector) => ({ selector, open: [...document.querySelectorAll(selector)].filter(isOpen) }))
        const declaredElements = declared.flatMap(({ open }) => open)

        const arrival = window.__kitArrival
        const body = document.body.style
        const html = document.documentElement.style.cssText
        if (!arrival) {
          report.scroll.push("no arrival snapshot: call record_arrival once the page has settled")
        } else if (html !== arrival.html) {
          report.scroll.push(`<html> style is "${html}", arrived as "${arrival.html}"`)
        }
        if (arrival && declaredElements.some((element) => claimant(element)?.scrollLockValue)) {
          if (body.position !== "fixed" || body.overflow !== "hidden") report.scroll.push(`a declared overlay holds the scroll lock, but <body> style is "${body.cssText}"`)
        } else if (arrival && body.cssText !== arrival.body) {
          report.scroll.push(`<body> style is "${body.cssText}", arrived as "${arrival.body}"`)
        }
        report.scroll.push(...(window.__kitLockWatch?.releases || []))

        for (const { selector, open } of declared) {
          if (open.length !== 1) report.open.push(`declared open "${selector}" matches ${open.length} open elements`)
        }
        for (const element of document.querySelectorAll(OPEN)) {
          const controller = claimant(element)
          if (!declaredElements.includes(element)) report.open.push(`open but not declared: ${describe(element)}`)
          if (!controller) report.open.push(`open with no connected ui--overlay claiming it: ${describe(element)}`)
          else if (!controller.openValue) report.open.push(`open while its ui--overlay says closed: ${describe(element)}`)
        }
        for (const element of document.querySelectorAll('[data-controller~="ui--overlay"]')) {
          const controller = overlayOn(element)
          if (controller?.openValue && !controller.contentTargets.some(isOpen)) report.open.push(`ui--overlay says open, its content isn't: ${describe(element)}`)
        }

        for (const element of document.querySelectorAll('[data-state="closing"]')) report.transitions.push(`stuck closing: ${describe(element)}`)
        for (const element of document.querySelectorAll('[data-state="open"]')) {
          if (element.hidden || !element.checkVisibility()) report.transitions.push(`data-state="open" but not rendered: ${describe(element)}`)
        }

        // A combobox's aria-controls names the listbox inside its popup, so resolve up to the
        // nearest top-layer element.
        const controlled = (element) => {
          const target = (element.getAttribute("aria-controls") || "").split(/\\s+/).map((id) => id && document.getElementById(id)).find(Boolean)
          return target && (target.closest("[popover], dialog") || target)
        }
        const shown = (element) => element.matches("[popover], dialog") ? isOpen(element) : !element.hidden && element.checkVisibility()
        for (const element of document.querySelectorAll("[aria-expanded]")) {
          const target = controlled(element)
          const claimsOpen = element.getAttribute("aria-expanded") === "true"
          if (!target) report.expanded.push(`aria-expanded controls nothing that resolves: ${describe(element)}`)
          else if (claimsOpen !== shown(target)) report.expanded.push(`aria-expanded="${claimsOpen}" but ${describe(target)} is ${claimsOpen ? "closed" : "open"}`)
        }
        return report
      })(...arguments)
    JS

    # The state invariant 1 compares against. Take it once the page has settled, and again after
    # any document render.
    def record_arrival
      page.execute_script(ARRIVAL)
    end

    private

    def top_layer_failures(open)
      page.evaluate_script(REPORT, open).transform_keys(&:to_sym)
    end
  end
end
