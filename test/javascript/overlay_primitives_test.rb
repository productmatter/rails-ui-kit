# frozen_string_literal: true

require 'test_helper'

# The delegation boundary of ui-presence-and-overlay-stack, held in place where it is cheapest
# to check. Everything these primitives *do* is asserted in a real browser under test/system/;
# what is asserted here is what they must never grow back: a stacking order of our own, a
# document-level dismissal listener that cannot tell whether it is on top, a hand-written focus
# trap, or a hardcoded animation duration. A reviewer that finds one of those fails the scope
# regardless of green browser tests, so they are worth catching in the fast lane.
class OverlayPrimitivesTest < ActiveSupport::TestCase
  JAVASCRIPT = File.expand_path('../../app/javascript/rails_ui_kit', __dir__)
  IMPORTMAP = File.expand_path('../../config/importmap.rb', __dir__)

  CONTROLLERS = {
    'ui--presence' => 'PresenceController',
    'ui--overlay' => 'OverlayController'
  }.freeze

  MODULES = %w[presence overlay_stack].freeze

  def read(relative_path)
    File.read(File.join(JAVASCRIPT, relative_path))
  end

  def index
    @index ||= read('index.js')
  end

  # The controllers, plus the modules they compose by import: a primitive that is written but
  # not registered -- or imported from a path nothing pins -- does nothing in a host app.
  def primitive_sources
    @primitive_sources ||= CONTROLLERS.values.map { |constant| read("controllers/#{constant.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}.js") } +
                           MODULES.map { |name| read("overlay/#{name}.js") }
  end

  CONTROLLERS.each do |identifier, constant|
    test "registers #{identifier}" do
      assert_includes index, %(application.register("#{identifier}", #{constant}))
      assert_includes index, %(import #{constant} from "rails_ui_kit/controllers/)
    end
  end

  MODULES.each do |name|
    test "#{name}.js exists and is reachable through an importmap pin" do
      assert File.exist?(File.join(JAVASCRIPT, "overlay/#{name}.js"))
      assert_match(%r{pin_all_from.*rails_ui_kit/overlay.*\n.*under: 'rails_ui_kit/overlay'}, File.read(IMPORTMAP))
    end
  end

  test 'neither primitive invents a stacking order' do
    primitive_sources.each do |source|
      assert_no_match(/z-?index\s*[:=]\s*\d/i, source, 'a z-index literal is back; the top layer is the stacking order')
    end
    # The one exception: a single fallback value in the stack module, applied once, not per depth.
    assert_match(/FALLBACK_Z_INDEX = \d+/, read('overlay/overlay_stack.js'))
    assert_equal 1, read('overlay/overlay_stack.js').scan('FALLBACK_Z_INDEX = ').size
  end

  # Turbo's own events are dispatched on the document and can only be heard there: the cache hook,
  # and turbo:morph, which is when a morphing refresh has just morphed the scroll lock off <body>.
  # Neither is a dismissal listener, which is what this guard is about.
  test 'the only document-level listeners are the Turbo hooks and the one named Escape exception' do
    events = primitive_sources.flat_map { |source| source.scan(/document\.addEventListener\("([^"]+)"/).flatten }

    assert_equal ['keydown', 'turbo:before-cache', 'turbo:before-cache', 'turbo:morph'].sort, events.sort,
                 "document-level listeners are #{events.inspect}; dismissal ordering is the top layer's"
    assert_includes read('controllers/overlay_controller.js'), 'document.addEventListener("keydown", this.onHintKeydown, true)'
  end

  test 'neither primitive contains a focus trap' do
    primitive_sources.each do |source|
      assert_no_match(/"Tab"/, source, 'Tab handling means a hand-written focus trap; <dialog> inerts the document instead')
    end
  end

  test 'presence never sleeps a literal duration' do
    source = read('overlay/presence.js')

    assert_no_match(/setTimeout\([^)]*,\s*\d/, source, 'a hardcoded animation length is back')
    assert_includes source, 'Math.min(duration * 1.5 + 50, timeout)'
  end

  test 'neither primitive imports Floating UI: positioning belongs to another primitive' do
    primitive_sources.each { |source| assert_no_match(/@floating-ui/, source) }
  end
end
