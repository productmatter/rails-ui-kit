# frozen_string_literal: true

require 'application_system_test_case'
require_relative 'stress_sequences'

# P5 (docs/specs/ui-stress-page § Behavior, item 6): the same sequences as the baseline, on the
# diagonal, under this profile's conditions.
class StressP5Test < ApplicationSystemTestCase
  include StressSequences

  define_for StressSequences::PROFILES.fetch(:p5)
end
