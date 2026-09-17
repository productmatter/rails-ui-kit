# frozen_string_literal: true

module Stress
  # Rule 7 of ui-component-library as sequences: a component nested inside another behaves as it
  # does standalone, and nested overlays dismiss in the reverse of the order they opened
  # (docs/specs/ui-stress-page § Behavior, item 13).
  module Nesting
    # [outer, inner]. The inner one is rendered by the cluster inside whatever contains it.
    PAIRS = [%i[M S2], %i[M Dm], %i[M Dd], %i[M Po], %i[M T], %i[M C], %i[Dd S1]].freeze

    def pair(outer_key, inner_key)
      outer = Overlay.build(outer_key)
      [outer, Overlay.build(inner_key, outer_key == :M ? 'modal' : outer.scope)]
    end

    # Open A, open B inside A, dismiss B, invariants with A declared open, dismiss A, invariants.
    def nesting_sequence(profile, outer_key, inner_key, inner_way, outer_way)
      outer, inner = pair(outer_key, inner_key)
      visit_stress(profile)
      open_overlay(outer)
      open_overlay(inner)

      dismiss_overlay(inner, inner_way)
      check(profile, "#{outer_key}>#{inner_key} #{inner_way}, with #{outer_key} open",
            open: [outer.content], focus: inner.returns_focus_to, topmost: topmost_for(outer, [outer]))

      dismiss_overlay(outer, outer_way)
      check(profile, "#{outer_key}>#{inner_key} #{inner_way}/#{outer_way}", focus: outer.returns_focus_to)
    end

    # M > Dd > S1, dismissed uniformly by one way, innermost first.
    def chain_sequence(profile, way)
      chain = [Overlay.build(:M), Overlay.build(:Dd, 'modal'), Overlay.build(:S1, 'modal')]
      visit_stress(profile)
      chain.each { |overlay| open_overlay(overlay) }

      chain.reverse.each { |overlay| dismiss_and_check(profile, chain, overlay, way) }
    end

    def dismiss_and_check(profile, chain, overlay, way)
      still_open = chain[0...chain.index(overlay)]
      dismiss_overlay(overlay, way)
      check(profile, "M>Dd>S1 #{way}, #{still_open.size} left open", open: still_open.map(&:content),
                                                                     focus: overlay.returns_focus_to, topmost: (chain.first.content if still_open.any?))
    end

    # One click outside both layers closes both, innermost first, as the browser does
    # (open-questions.md, decided 2026-09-15).
    def outside_both_sequence(profile)
      modal, menu = pair(:M, :Dm)
      visit_stress(profile)
      open_overlay(modal)
      open_overlay(menu)

      click_backdrop(modal.content)
      await_state(menu.content, 'closed')
      await_state(modal.content, 'closed')
      check(profile, 'M>Dm outside both', focus: modal.returns_focus_to)
    end

    # Every nesting pair's diagonal in one page visit, for the defects that need many operations to
    # show: a lock count that drifts, listeners that pile up (§ Behavior, item 13, "Soak").
    def soak_sequence(profile)
      visit_stress(profile)
      PAIRS.each do |outer_key, inner_key|
        outer, inner = pair(outer_key, inner_key)
        outer.ways.each do |way|
          open_overlay(outer)
          open_overlay(inner)
          dismiss_overlay(inner, diagonal_way(inner, way))
          dismiss_overlay(outer, way)
          check(profile, "soak #{outer_key}>#{inner_key} #{way}", focus: outer.returns_focus_to)
        end
      end
    end

    # The diagonal: B is dismissed the same way as A, or by Escape where B lacks that way.
    def diagonal_way(inner, way)
      inner.ways.include?(way) ? way : :escape
    end

    private

    # Script can't read top-layer order, so a sequence that leaves a modal open names it.
    def topmost_for(outer, open)
      outer.key == :M && open.any? ? outer.content : nil
    end
  end
end
