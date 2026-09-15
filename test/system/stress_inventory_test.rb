# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'stress_sequences'

# The page's own check that it contains what the table says (docs/specs/ui-stress-page § Behavior,
# item 16): an overlay added to the page without a row fails here, which is what keeps "every
# nesting pair the page allows" true after the page changes. It also proves each condition can be
# applied and detected on its own, and that teardown takes every one back off.
class StressInventoryTest < ApplicationSystemTestCase
  include StressSequences

  define_profile StressSequences::PROFILES.fetch(:p0)

  # What each openable thing is, and where its trigger sits. The pair is the container the trigger
  # is inside, not where the overlay's own markup lives: the shared Confirm Dialog is rendered by
  # the layout, and what makes it a nesting is being opened from inside the Modal.
  PAIRS_FROM_DOM = <<~JS
    (() => {
      // Every overlay's own root, which is what says which component it is.
      const rootOf = (overlay) => overlay.matches('[data-slot]') ? overlay : overlay.querySelector('[data-slot]')
      const keyOf = (overlay) => {
        const root = rootOf(overlay)
        if (!root) return null
        const slot = root.dataset.slot
        if (slot === 'modal') return 'M'
        if (slot === 'confirm-dialog') return 'C'
        if (slot === 'select') return root.getAttribute('data-ui--select-search-value') === 'true' ? 'S2' : 'S1'
        if (slot === 'popover') return 'Po'
        if (slot === 'tooltip') return 'T'
        if (slot === 'dropdown') return root.querySelector('[role=menu]') ? 'Dm' : 'Dd'
        return null
      }
      // What opens it: the Modal's frame link and the Confirm Dialog's data-turbo-confirm button
      // are the two the kit doesn't render as an ui--overlay trigger.
      const triggerOf = (overlay, key) => {
        if (key === 'M') return document.querySelector('[data-turbo-frame=stress-modal]')
        if (key === 'C') return document.querySelector('[data-turbo-confirm] [type=submit]')
        // A Tooltip's trigger is the wrapper ui--tooltip names, not an ui--overlay target.
        return overlay.querySelector('[data-ui--overlay-target=trigger], [data-ui--tooltip-target=trigger]')
      }

      const openables = [...document.querySelectorAll('[data-controller~="ui--overlay"]')]
      const containers = openables.map((overlay) => ({
        key: keyOf(overlay),
        content: overlay.querySelector('[data-ui--overlay-target=content]')
      })).filter((container) => container.key && container.content)

      const pairs = new Set()
      for (const overlay of openables) {
        const key = keyOf(overlay)
        const trigger = key && triggerOf(overlay, key)
        if (!trigger) continue

        // The innermost container the trigger sits in, by depth: a Select inside a Dropdown inside
        // the Modal is a Dd>S1, not an M>S1.
        const depth = (node) => { let n = 0; for (let e = node; e; e = e.parentElement) n++; return n }
        const inside = containers.filter(({ content }) => content !== overlay && content.contains(trigger))
        const innermost = inside.sort((a, b) => depth(b.content) - depth(a.content))[0]
        if (innermost) pairs.add(`${innermost.key}>${key}`)
      }
      return [...pairs].sort()
    })()
  JS

  test 'the nesting pairs the page allows are exactly the ones the table lists' do
    visit_stress(profile)
    open_overlay(Stress::Overlay.build(:M))

    assert_equal Stress::Nesting::PAIRS.map { |outer, inner| "#{outer}>#{inner}" }.sort,
                 page.evaluate_script(PAIRS_FROM_DOM),
                 'the page and the sequence table disagree about which overlay sits inside which'
  end

  { theme: :dark, motion: :reduced, viewport: 320, direction: :rtl, locale: :pseudo, turbo: :off }.each do |condition, value|
    test "the #{condition} condition applies on its own, and is detected" do
      variant = profile.merge(condition => value, name: "inventory #{condition}")
      apply_emulation(variant)
      visit_stress(variant)

      assert_conditions(variant, "inventory #{condition}")
      assert_not_equal profile[condition], value, 'the variant is the same as the baseline, so it proves nothing'
    end
  end

  test 'teardown takes every condition back off, so the next profile starts from the baseline' do
    every_condition = profile.merge(theme: :dark, motion: :reduced, viewport: 320, direction: :rtl, name: 'inventory all')
    apply_emulation(every_condition)
    visit_stress(every_condition)
    assert_conditions(every_condition, 'inventory all')

    finish_stress
    visit_stress(profile)
    assert_conditions(profile, 'inventory baseline after teardown')
  end

  private

  def profile
    self.class.stress_profile
  end
end
