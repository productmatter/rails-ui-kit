# frozen_string_literal: true

module KitInvariants
  # Invariant 5: focus is somewhere a user can be. document.activeElement is connected; unless it
  # is <body> it has a box, is rendered, and isn't inside [inert], a closed <dialog> or a hidden
  # popover; it is inside the topmost open modal when there is one. <body> is allowed only when
  # declared, after a document render. A declared target is met by that element or by whatever
  # now holds its id.
  #
  # Script can't read top-layer order, so with more than one modal open the sequence names the
  # topmost.
  module Focus
    REPORT = <<~JS.freeze
      ((focusKind, focusSelector, focusElement, topmostSelector) => {
        #{DESCRIBE}
        const failures = []
        const active = document.activeElement
        const modals = [...document.querySelectorAll(":modal")]

        if (!active || !active.isConnected) {
          failures.push("document.activeElement is not connected")
        } else if (active === document.body) {
          if (focusKind !== "body") failures.push("focus is on <body>, and the sequence declared no document render")
        } else {
          const rect = active.getBoundingClientRect()
          const checks = [
            [focusKind === "body", "focus was declared on <body>, is on"],
            [rect.width === 0 || rect.height === 0, "focus is on an element with no box:"],
            [!active.checkVisibility({ visibilityProperty: true }), "focus is on an unrendered element:"],
            [active.closest("[inert]"), "focus is inside [inert]:"],
            [active.closest("dialog:not([open])"), "focus is inside a closed <dialog>:"],
            [active.closest("[popover]:not(:popover-open)"), "focus is inside a hidden popover:"]
          ]
          for (const [failed, message] of checks) if (failed) failures.push(`${message} ${describe(active)}`)

          let topmost = modals.length === 1 ? modals[0] : null
          if (topmostSelector) {
            topmost = document.querySelector(topmostSelector)
            if (!topmost?.matches(":modal")) failures.push(`declared topmost modal "${topmostSelector}" is not an open modal`)
          } else if (modals.length > 1) {
            failures.push(`${modals.length} modals are open: declare the topmost`)
          }
          if (topmost && !topmost.contains(active)) failures.push(`focus is outside the topmost modal: ${describe(active)}`)
        }

        if (focusKind === "element") {
          const expected = focusSelector ? document.querySelector(focusSelector) : focusElement
          if (!expected) failures.push(`the declared focus target "${focusSelector}" is not on the page`)
          else if (active !== expected && !(expected.id && active?.id === expected.id)) failures.push(`focus is on ${describe(active)}, declared on ${describe(expected)}`)
        }
        return failures
      })(...arguments)
    JS

    private

    def focus_failures(focus, topmost_modal)
      selector = focus if focus.is_a?(String)
      element = focus if focus.is_a?(Capybara::Node::Element)
      kind = if focus == :body then 'body'
             elsif focus.nil? then 'real'
             else 'element'
             end

      { focus: page.evaluate_script(REPORT, kind, selector, element, topmost_modal) }
    end
  end
end
