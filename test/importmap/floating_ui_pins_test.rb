# frozen_string_literal: true

require 'test_helper'
require 'net/http'

# The engine ships config/importmap.rb and invites host apps to override any pin in it. With
# Floating UI spread over four pins, a host that overrode @floating-ui/dom alone kept the kit's
# older core and utils and got a graph that fails in the browser. One pin removes that failure
# mode by construction, which is what these tests hold in place.
class FloatingUiPinsTest < ActiveSupport::TestCase
  IMPORTMAP = File.expand_path('../../config/importmap.rb', __dir__)
  PACKAGE_JSON = File.expand_path('../../package.json', __dir__)

  # Bare specifiers -- anything that isn't a URL or a path -- need an importmap entry of their own.
  # A URL-only graph is a closed graph.
  SPECIFIER = /(?:^|[\s};])(?:import|export)\s*(?:[^'"]*?from\s*)?["']([^"']+)["']|import\(["']([^"']+)["']\)/

  def pins
    @pins ||= File.read(IMPORTMAP).scan(/^\s*pin\s+'([^']+)',\s*to:\s*'([^']+)'/).to_h
  end

  def floating_ui_pins
    pins.select { |name, _| name.start_with?('@floating-ui/') }
  end

  test 'Floating UI is pinned exactly once' do
    assert_equal ['@floating-ui/dom'], floating_ui_pins.keys,
                 'Floating UI must reach importmap consumers as a single pin whose version set moves as a unit'
  end

  test 'the single pin is a self-resolving bundled build' do
    url = floating_ui_pins.fetch('@floating-ui/dom')

    assert_match %r{\Ahttps://cdn\.jsdelivr\.net/npm/@floating-ui/dom@\d+\.\d+\.\d+/\+esm\z}, url
  end

  test 'the pinned version satisfies the peer dependency range in package.json' do
    range = JSON.parse(File.read(PACKAGE_JSON))['peerDependencies']['@floating-ui/dom']
    pinned = floating_ui_pins.fetch('@floating-ui/dom')[%r{@floating-ui/dom@([\d.]+)}, 1]

    assert npm_caret_requirement(range).satisfied_by?(Gem::Version.new(pinned)),
           "pinned @floating-ui/dom@#{pinned} is outside the declared peer range #{range}"
  end

  test 'the pinned module graph closes: every specifier in it is a URL, never a bare name' do
    fetched = {}
    queue = [floating_ui_pins.fetch('@floating-ui/dom')]

    while (url = queue.shift)
      next if fetched.key?(url)

      body = fetch(url) || skip("#{url} is unreachable from here; the graph check needs network access")
      fetched[url] = true

      specifiers(body).each do |specifier|
        assert_match %r{\A(?:https?:)?/}, specifier,
                     "#{url} imports the bare specifier #{specifier.inspect}, which needs an importmap pin of its own"
        queue << URI.join(url, specifier).to_s
      end
    end

    assert_operator fetched.size, :>, 1, 'expected the bundled build to pull in at least one further module'
  end

  private

  # npm's "^1.6.0" is ">= 1.6.0, < 2.0.0" -- not RubyGems' "~> 1.6.0", which stops at 1.7.
  def npm_caret_requirement(range)
    version = Gem::Version.new(range.delete('^'))
    Gem::Requirement.new(">= #{version}", "< #{version.segments.first + 1}")
  end

  def specifiers(body)
    body.scan(SPECIFIER).flatten.compact
  end

  def fetch(url)
    response = Net::HTTP.get_response(URI(url))
    response = Net::HTTP.get_response(URI.join(url, response['location'])) if response.is_a?(Net::HTTPRedirection)
    response.body if response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    nil
  end
end
