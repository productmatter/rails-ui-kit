# frozen_string_literal: true

module KitInvariants
  # Shared by every family's script: names an offending element by the start of its outerHTML.
  DESCRIBE = 'const describe = (element) => element ? element.outerHTML.slice(0, 120) : String(element)'
end

require_relative 'kit_invariants/console'
require_relative 'kit_invariants/top_layer'
require_relative 'kit_invariants/focus'
require_relative 'kit_invariants/connections'

# The promises the kit makes about any page at rest, checked in one pass after a sequence has
# settled (docs/specs/ui-stress-page § Behavior, items 9 and 10). Nothing here knows about the
# stress page, so any component suite can end a sequence with it:
#
#   capture_console                      # before the first visit
#   visit dropdown_path
#   record_arrival                       # once the page has settled
#   ...open and dismiss things, waiting on each change...
#   assert_kit_invariants(focus: trigger)
#
# Declare what the sequence leaves open, as CSS selectors, and where focus belongs: nil for
# "somewhere real", :body only after a document render the sequence itself caused, or a selector
# or element for a return target. With more than one modal open, name the topmost.
#
# Each family module checks its invariants in one script round trip and returns
# { invariant key => [message, ...] }.
module KitInvariants
  extend ActiveSupport::Concern
  include Console
  include TopLayer
  include Focus
  include Connections

  INVARIANTS = {
    scroll: 'invariant 1, no scroll lock left',
    open: 'invariant 2, no stray open element',
    transitions: 'invariant 3, nothing stuck mid-transition',
    expanded: 'invariant 4, honest aria-expanded',
    focus: 'invariant 5, focus somewhere real',
    accessible: 'invariant 6, accessibility audit',
    console: 'invariant 7, silent console',
    controllers: 'invariant 8, kit controllers connected',
    ids: 'invariant 9, no duplicate or dangling ids'
  }.freeze

  def assert_kit_invariants(open: [], focus: nil, topmost_modal: nil, context: name)
    failures = kit_invariant_failures(open: open, focus: focus, topmost_modal: topmost_modal)
    assert failures.empty?, kit_invariant_message(context, failures)
  end

  # Only the invariants that failed, in the order the spec checks them.
  def kit_invariant_failures(open: [], focus: nil, topmost_modal: nil)
    report = top_layer_failures(Array(open)).merge(focus_failures(focus, topmost_modal), accessibility_failures,
                                                   console_failures, connection_failures)
    INVARIANTS.keys.filter_map { |key| [key, report[key]] if report[key].present? }.to_h
  end

  private

  def accessibility_failures
    assert_accessible
    { accessible: [] }
  rescue Minitest::Assertion => e
    { accessible: [e.message] }
  end

  def kit_invariant_message(context, failures)
    lines = failures.flat_map do |key, messages|
      ["  #{INVARIANTS.fetch(key)}:", *messages.map { |message| "    - #{message}" }]
    end
    "Kit invariants failed after #{context}:\n#{lines.join("\n")}"
  end
end
