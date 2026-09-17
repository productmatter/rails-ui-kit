# frozen_string_literal: true

module Stress
  # Getting to the page and knowing when it has settled. Every sequence starts from a fresh visit,
  # so a failure is attributable (docs/specs/ui-stress-page § Behavior, item 13).
  module Arrival
    # Counters installed before any page script, so a sequence can wait on the event a change
    # produces rather than on a duration. Turbo Drive keeps the window, so they survive a visit.
    EVENTS = <<~JS
      (() => {
        if (window.__stressEvents) return
        const counts = window.__stressEvents = { load: 0, morph: 0, frame: 0, f8: 0 }
        addEventListener('turbo:load', () => { counts.load++ })
        addEventListener('turbo:morph', () => { counts.morph++ })
        addEventListener('turbo:frame-render', () => { counts.frame++ })
        addEventListener('keydown', (event) => { if (event.key === 'F8') counts.f8++ })
      })()
    JS

    # The page has connected when every ui--* controller on it has an instance. Waiting on this,
    # rather than on markup, is what keeps a click off a control whose controller isn't live yet.
    READY = <<~JS
      !!window.Stimulus && !!document.querySelector('#stress-form') &&
        [...document.querySelectorAll('[data-controller*="ui--"]')].every((element) =>
          element.getAttribute('data-controller').split(/\\s+/).filter((identifier) => identifier.startsWith('ui--'))
            .every((identifier) => !!Stimulus.getControllerForElementAndIdentifier(element, identifier)))
    JS

    def start_stress(profile)
      capture_console
      @stress_events_script = add_script_to_new_documents(EVENTS)
      apply_emulation(profile)
    end

    def finish_stress
      remove_script_from_new_documents(@stress_events_script) if @stress_events_script
      reset_emulation
      page.execute_script('try { localStorage.clear() } catch (error) {}')
      page.execute_script("document.documentElement.removeAttribute('dir')")
    rescue StandardError
      # A session already torn down has nothing left to reset.
    end

    def visit_stress(profile)
      visit stress_path(stress_query(profile))
      arrive(profile)
    end

    # After any document render: the conditions the server doesn't carry are re-applied, the page
    # is waited on, and a new arrival snapshot is taken for invariant 1.
    def arrive(profile)
      await_js(READY, message: 'the page never finished connecting its controllers')
      apply_page_conditions(profile)
      record_arrival
    end

    def events
      page.evaluate_script('window.__stressEvents')
    end

    def await_event(kind, count)
      await_js('window.__stressEvents[arguments[0]] >= arguments[1]', kind.to_s, count,
               message: "no #{kind} event arrived (#{count} expected)")
    end

    # Every invariant, with the profile's conditions proved still in force (§ Behavior, item 5).
    # The pointer is parked first, unless the sequence declares a hint open: where the pointer
    # happens to have come to rest is not part of the sequence, and at 320 px it can be left on a
    # Tooltip's trigger, which would leave a hint legitimately open.
    def check(profile, name, open: [], focus: nil, topmost: nil)
      context = "#{profile[:name]} #{name}"
      park_pointer unless open.any? { |selector| selector.include?('-t >') }
      assert_conditions(profile, context)
      assert_kit_invariants(open: open, focus: focus, topmost_modal: topmost, context: context)
    end

    # Off every control, and settled: a hint the pointer was resting on runs out on its own.
    def park_pointer
      page.driver.browser.action.move_to_location(1, 1).perform
      await_js("![...document.querySelectorAll('[data-slot=tooltip-content]')].some((hint) => hint.matches(':popover-open'))",
               message: 'a Tooltip stayed open with the pointer parked away from it')
    end
  end
end
