# frozen_string_literal: true

module Stress
  # The sequences that aren't a nesting pair: displacement, a toast across a Modal, a Turbo Stream
  # or a morph while something is open, and Back (docs/specs/ui-stress-page § Behavior, item 13).
  module Flows
    TOAST = '#ui-toasts [data-slot=toast]'
    DISPLACEMENTS = %i[po_then_dm dm_then_po dm_then_t].freeze
    STREAMS = %i[status_field cluster_over_dm cluster_over_po modal city_field].freeze
    MORPHS = %i[modal form_select dropdown_select].freeze
    BACKS = %i[modal dropdown select].freeze

    # An auto popover displaces the one before it; a hint does not (ui-presence-and-overlay-stack
    # § Behavior, item 8).
    def displacement_sequence(profile, kind, way)
      remaining = displace(profile, kind)
      check(profile, "#{kind} displaced", open: remaining.map(&:content))

      remaining.each { |overlay| dismiss_overlay(overlay, overlay.ways.include?(way) ? way : :escape) }
      check(profile, "#{kind} then #{way}", focus: remaining.last.returns_focus_to)
    end

    # Opens the second over the first, and returns what is still open, innermost first.
    def displace(profile, kind)
      first, second = displacement_pair(kind)
      visit_stress(profile)
      open_overlay(first)
      open_overlay(second)
      return [second, first] if kind == :dm_then_t

      await_state(first.content, 'closed')
      [second]
    end

    # A toast fired from inside a Modal is occluded, so F8 leaves focus in the Modal; once the
    # Modal is gone the same toast is reachable (ui-toast § Behavior, item 12).
    def toast_sequence(profile, way)
      modal = Overlay.build(:M)
      visit_stress(profile)
      open_overlay(modal)
      fire_modal_toast

      press(:f8)
      await_event(:f8, 1)
      check(profile, "toast over M, F8 (#{way})", open: [modal.content], topmost: modal.content)

      dismiss_overlay(modal, way)
      reach_toast_and_close
      check(profile, "toast after M #{way}", focus: modal.returns_focus_to)
    end

    # Each replacement is a real server response rendered by Turbo's own stream renderer, started
    # from a script: anything on the page that could start it would dismiss the overlay first.
    def stream_sequence(profile, kind)
      visit_stress(profile)
      open = stream_setup(kind)
      target = stream_target(kind)
      previous = token_of(target)
      render_stream(stream_name(kind))
      await_new_token(target, previous)
      await_js(Arrival::READY, message: 'the replacement never connected its controllers')
      # A replacement that renders an overlay open has to finish entering before anything is read
      # of it: a half-entered dialog is still transparent.
      stream_expectation(kind, open)[:open]&.each { |selector| await_state(selector, 'open') }

      check(profile, "stream #{kind}", **stream_expectation(kind, open))
    end

    # A morphing refresh is what a broadcast sends: an open layer survives it, as the same element
    # (open-questions.md, decided 2026-09-15).
    def morph_sequence(profile, kind)
      visit_stress(profile)
      open = morph_setup(kind)
      morph_the_page(profile, open)

      # The same elements, not re-mounted ones that look the same.
      open.each { |overlay| assert_selector "#{overlay.content}[data-stress-tag='morph-#{overlay.key}']", visible: :all }
      check(profile, "morph with #{kind} open", open: open.map(&:content), focus: morph_focus(kind), topmost: morph_topmost(kind))
    end

    def morph_the_page(profile, open)
      open.each { |overlay| tag(overlay.content, "morph-#{overlay.key}") }
      morphs = events['morph']
      render_stream('refresh')
      await_event(:morph, morphs + 1)
      arrive(profile)
    end

    # Back restores the page with everything closed at rest and focus not pulled in
    # (ui-presence-and-overlay-stack § Behavior, item 19).
    def back_sequence(profile, kind)
      visit_stress(profile)
      leave_from(kind)
      # The bare page's own element, which has no box of its own, so it is matched as markup.
      assert_selector '#stress-bare', visible: :all
      assert_no_selector '#stress-form'

      loads = events['load']
      page.go_back
      await_event(:load, loads + 1)
      arrive(profile)

      assert_select_restored if kind == :select
      check(profile, "back with #{kind} open", focus: :body)
    end
  end
end
