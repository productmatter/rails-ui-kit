# frozen_string_literal: true

module KitInvariants
  # Invariants 8 and 9, what the markup names and whether it resolves:
  #   8. every ui--* identifier in a data-controller has a live controller on that element -- an
  #      element Turbo swapped in whose controller never connected fails here. It needs the
  #      Stimulus application at window.Stimulus, and fails loudly without it;
  #   9. no id is on two elements, and every id named by for, aria-controls, aria-labelledby,
  #      aria-describedby or aria-activedescendant is a connected element.
  #
  # Stimulus connects on a microtask after insertion, so check after a settle signal, never
  # straight after a swap.
  module Connections
    REFERENCES = %w[for aria-controls aria-labelledby aria-describedby aria-activedescendant].freeze

    REPORT = <<~JS.freeze
      ((references) => {
        #{DESCRIBE}
        const report = { controllers: [], ids: [] }
        const stimulus = window.Stimulus
        if (typeof stimulus?.getControllerForElementAndIdentifier !== "function") {
          report.controllers.push("window.Stimulus is not the Stimulus application, so nothing can be proven connected")
        } else {
          for (const element of document.querySelectorAll('[data-controller*="ui--"]')) {
            for (const identifier of element.getAttribute("data-controller").split(/\\s+/)) {
              if (identifier.startsWith("ui--") && !stimulus.getControllerForElementAndIdentifier(element, identifier)) {
                report.controllers.push(`${identifier} is not connected: ${describe(element)}`)
              }
            }
          }
        }

        const counts = new Map()
        for (const element of document.querySelectorAll("[id]")) counts.set(element.id, (counts.get(element.id) || 0) + 1)
        for (const [id, count] of counts) if (id && count > 1) report.ids.push(`id "${id}" is on ${count} elements`)
        for (const attribute of references) {
          for (const element of document.querySelectorAll(`[${attribute}]`)) {
            for (const id of element.getAttribute(attribute).split(/\\s+/).filter(Boolean)) {
              if (!document.getElementById(id)) report.ids.push(`${attribute}="${id}" names no element: ${describe(element)}`)
            }
          }
        }
        return report
      })(...arguments)
    JS

    private

    def connection_failures
      page.evaluate_script(REPORT, REFERENCES).transform_keys(&:to_sym)
    end
  end
end
