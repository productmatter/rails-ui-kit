# frozen_string_literal: true

module Stress
  # What a sequence does to the page, each gesture proving its reference is laid out before it
  # acts, and each wait on something only the change produces (docs/specs/ui-stress-page
  # § Business rules, rule 5). No fixed sleeps: every wait is a polled condition with a timeout.
  module Gestures
    # An element has settled open (entered, in the top layer) or closed (left the top layer and
    # presence says closed, or removed -- the disappearance of a node that was open).
    SETTLED = <<~JS
      ((selector, wanted) => {
        const element = document.querySelector(selector)
        if (!element) return wanted === 'closed'
        if (element.getAnimations().some((animation) => !['finished', 'idle'].includes(animation.playState))) return false
        const shown = element.matches(':modal, :popover-open, dialog[open]')
        return wanted === 'open' ? shown && element.dataset.state === 'open' : !shown && element.dataset.state === 'closed'
      })(...arguments)
    JS

    # A point inside a region that the browser hit-tests to the region itself. The centre first,
    # then a grid across it: an anchored layer can cover part of a region, and a click that lands
    # on the layer is not the outside click the sequence names. `problem` rather than `error`,
    # which WebDriver reads as a failed script.
    REGION = <<~JS
      ((selector) => {
        const region = document.querySelector(selector)
        if (!region || region.hidden) return { problem: 'is not on the page' }
        region.scrollIntoView({ block: 'nearest', inline: 'nearest' })
        const rect = region.getBoundingClientRect()
        if (!rect.width || !rect.height) return { problem: 'has no box' }

        let covered = 'nothing'
        for (const fy of [0.5, 0.25, 0.75]) {
          for (const fx of [0.5, 0.15, 0.85, 0.3, 0.7, 0.03, 0.97]) {
            const x = rect.left + rect.width * fx
            const y = rect.top + rect.height * fy
            if (x < 0 || y < 0 || x >= innerWidth || y >= innerHeight) continue
            const hit = document.elementFromPoint(x, y)
            if (hit === region) return { x, y, hit: true }
            if (hit) covered = hit.outerHTML.slice(0, 120)
          }
        }
        return { problem: `is covered by ${covered}, so an outside click would land there` }
      })(...arguments)
    JS

    # A point on an open modal dialog's backdrop: a click there targets the dialog itself, which is
    # what a backdrop dismissal listens for.
    BACKDROP = <<~JS
      ((selector) => {
        const dialog = document.querySelector(selector)
        if (!dialog || !dialog.matches(':modal')) return { problem: 'is not an open modal' }
        for (const fx of [0.5, 0.03, 0.97]) {
          for (const fy of [0.03, 0.97, 0.5]) {
            const x = Math.round(innerWidth * fx)
            const y = Math.round(innerHeight * fy)
            if (document.elementFromPoint(x, y) === dialog) return { x, y, hit: true }
          }
        }
        return { problem: 'has no point where a click reaches its backdrop' }
      })(...arguments)
    JS

    def await_js(expression, *args, message: nil, timeout: Capybara.default_max_wait_time)
      Timeout.timeout(timeout) { sleep 0.02 until page.evaluate_script(expression, *args) }
    rescue Timeout::Error
      flunk message || "timed out waiting for #{expression.strip[0, 160]}"
    end

    def await_state(selector, wanted)
      await_js(SETTLED, selector, wanted, message: "#{selector} never settled #{wanted}")
    end

    # A click on a neutral region, at a point proved to land on the region itself (§ Behavior,
    # item 12).
    def click_region(selector)
      click_at(*probe(REGION, selector).values_at('x', 'y'))
    end

    def click_backdrop(selector)
      point = probe(BACKDROP, selector)
      click_at(point['x'], point['y'])
    end

    # The pointer on a region, proved laid out, without clicking.
    def point_at(selector)
      point = probe(REGION, selector)
      page.driver.browser.action.move_to_location(point['x'].to_i, point['y'].to_i).perform
    end

    def press_chord(modifier, key)
      page.driver.browser.action.key_down(modifier).send_keys(key).key_up(modifier).perform
    end

    def tag(selector, name)
      page.execute_script('document.querySelector(arguments[0]).dataset.stressTag = arguments[1]', selector, name)
    end

    def token_of(selector)
      page.evaluate_script('document.querySelector(arguments[0])?.dataset.stressRender', selector)
    end

    def await_new_token(selector, previous)
      await_js('document.querySelector(arguments[0])?.dataset.stressRender !== arguments[1] && !!document.querySelector(arguments[0])',
               selector, previous, message: "#{selector} was never re-rendered")
    end

    private

    def probe(script, selector)
      point = page.evaluate_script(script, selector)
      flunk "#{selector} #{point['problem']}" if point['problem']
      point
    end
  end
end
