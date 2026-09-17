# frozen_string_literal: true

module Stress
  # The six condition profiles (docs/specs/ui-stress-page § Behavior, item 6).
  module Profiles
    # A strength-2 covering array over six two-value conditions (§ Behavior, item 6): every pair of
    # values of every two conditions happens at least once, in six profiles rather than 64.
    ALL = {
      p0: { name: 'P0', theme: :light, motion: :full, viewport: 1400, direction: :ltr, locale: :en, turbo: :on, index: 0 },
      p1: { name: 'P1', theme: :dark, motion: :reduced, viewport: 1400, direction: :rtl, locale: :en, turbo: :off, index: 1 },
      p2: { name: 'P2', theme: :dark, motion: :full, viewport: 320, direction: :ltr, locale: :pseudo, turbo: :off, index: 2 },
      p3: { name: 'P3', theme: :dark, motion: :full, viewport: 1400, direction: :rtl, locale: :pseudo, turbo: :on, index: 3 },
      p4: { name: 'P4', theme: :light, motion: :reduced, viewport: 320, direction: :rtl, locale: :en, turbo: :on, index: 4 },
      p5: { name: 'P5', theme: :light, motion: :reduced, viewport: 320, direction: :ltr, locale: :pseudo, turbo: :off, index: 5 }
    }.freeze
  end
end
