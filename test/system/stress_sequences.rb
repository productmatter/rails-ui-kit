# frozen_string_literal: true

require_relative 'toast_helpers'
require_relative 'modal_turbo_probes'
require_relative 'stress/overlay'
require_relative 'stress/gestures'
require_relative 'stress/moves'
require_relative 'stress/conditions'
require_relative 'stress/arrival'
require_relative 'stress/nesting'
require_relative 'stress/flows'
require_relative 'stress/flow_steps'
require_relative 'stress/stream_table'
require_relative 'stress/form'
require_relative 'stress/profiles'

# The stress suite's table and generator (docs/specs/ui-stress-page § Behavior, items 5 to 16).
# Every sequence starts from a fresh visit and ends with assert_kit_invariants, whose declared open
# set and focus target cite the owning scope's § Behavior (§ Business rules, rules 1 and 2).
#
#   class StressP3Test < ApplicationSystemTestCase
#     include StressSequences
#     define_for StressSequences::PROFILES.fetch(:p3)
#   end
module StressSequences
  extend ActiveSupport::Concern
  include ToastHelpers
  include ModalTurboProbes
  include Stress::Gestures
  include Stress::Moves
  include Stress::Conditions
  include Stress::Arrival
  include Stress::Nesting
  include Stress::Flows
  include Stress::FlowSteps
  include Stress::StreamTable
  include Stress::Form

  PROFILES = Stress::Profiles::ALL

  # The table is fixed, so its count is asserted: a changed table shows in the diff as a changed
  # number too (§ Behavior, item 14).
  EXPECTED_COUNTS = { cross: 87, diagonal: 44 }.freeze

  included do
    setup { start_stress(self.class.stress_profile) }
    teardown { finish_stress }
  end

  class_methods do
    attr_reader :stress_profile

    # For a file that drives the page under a profile without generating the table's sequences.
    def define_profile(profile)
      @stress_profile = profile
    end

    # cross: the full dismissal cross of every nesting pair, which runs once, in the baseline.
    def define_for(profile, cross: false)
      define_profile(profile)
      defined = define_nesting(profile, cross) + define_flows(profile, cross)
      expected = StressSequences::EXPECTED_COUNTS.fetch(cross ? :cross : :diagonal)
      raise "#{profile[:name]} generated #{defined} sequences, the table says #{expected}" unless defined == expected
    end

    private

    def define_nesting(profile, cross)
      pairs = Stress::Nesting::PAIRS.sum do |outer_key, inner_key|
        outer = Stress::Overlay.build(outer_key)
        define_pair(profile, outer, Stress::Overlay.build(inner_key, outer_key == :M ? 'modal' : 'page'), cross)
      end
      pairs + define_chain(profile) + define_outside_both(profile) + (cross ? define_soak(profile) : 0)
    end

    def define_pair(profile, outer, inner, cross)
      outer.ways.sum do |outer_way|
        inner_ways = if cross
                       inner.ways
                     else
                       [inner.ways.include?(outer_way) ? outer_way : :escape]
                     end
        inner_ways.each do |inner_way|
          stress_test "#{outer.key}>#{inner.key} #{inner_way}/#{outer_way}" do
            nesting_sequence(profile, outer.key, inner.key, inner_way, outer_way)
          end
        end
        inner_ways.size
      end
    end

    def define_chain(profile)
      Stress::WAYS.each { |way| stress_test("M>Dd>S1 #{way}") { chain_sequence(profile, way) } }.size
    end

    def define_outside_both(profile)
      stress_test('M>Dm outside both') { outside_both_sequence(profile) }
      1
    end

    def define_soak(profile)
      stress_test('soak') { soak_sequence(profile) }
      1
    end

    # Every way in the baseline; one rotating way elsewhere, so the five profiles between them
    # still cover all three (§ Behavior, item 13, "Displacement").
    def define_displacement(profile, cross)
      Stress::Flows::DISPLACEMENTS.each_with_index.sum do |kind, index|
        ways = cross ? Stress::WAYS : [Stress::WAYS[(profile[:index] + index) % Stress::WAYS.size]]
        ways.each { |way| stress_test("#{kind} #{way}") { displacement_sequence(profile, kind, way) } }
        ways.size
      end
    end

    def define_flows(profile, cross)
      define_displacement(profile, cross) + define_toasts(profile) + define_streams(profile) +
        define_morphs(profile) + define_backs(profile) + define_form(profile)
    end

    def define_toasts(profile)
      Stress::WAYS.each { |way| stress_test("toast over M, M closed by #{way}") { toast_sequence(profile, way) } }.size
    end

    def define_streams(profile)
      Stress::Flows::STREAMS.each { |kind| stress_test("stream #{kind}") { stream_sequence(profile, kind) } }.size
    end

    def define_morphs(profile)
      Stress::Flows::MORPHS.each { |kind| stress_test("morph with #{kind} open") { morph_sequence(profile, kind) } }.size
    end

    def define_backs(profile)
      Stress::Flows::BACKS.each { |kind| stress_test("back with #{kind} open") { back_sequence(profile, kind) } }.size
    end

    # § Behavior, item 13, "The form": both follow the profile's Turbo value.
    def define_form(profile)
      stress_test('form: an invalid submit, the 422, then S1 dismissed by Escape') { form_invalid_sequence(profile) }
      stress_test('form: a valid submit, its toast reached by F8 and closed by Escape') { form_valid_sequence(profile) }
      2
    end

    # Named so a failure line reads as the sequence: "P3 M>Dd escape/outside".
    def stress_test(name, &)
      test("#{@stress_profile[:name]} #{name}", &)
    end
  end
end
