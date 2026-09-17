# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'stress_sequences'

# P0, the baseline: light, full motion, 1400 px, ltr, en, Turbo on, and the only profile that runs
# the full dismissal cross and the soak (docs/specs/ui-stress-page § Behavior, items 6 and 13).
class StressP0Test < ApplicationSystemTestCase
  include StressSequences

  define_for StressSequences::PROFILES.fetch(:p0), cross: true
end
