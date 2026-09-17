# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'tmpdir'

module RailsUiKit
  # The conversion's claim, read from a real tailwindcss build rather than assumed
  # (ui-localization-rtl § Acceptance checks): each replacement sets the logical property that
  # computes to the physical one it replaced in a left-to-right document, and Tailwind's `rtl:`
  # variant is what pairs the two properties that have no logical form.
  class TailwindLogicalUtilitiesTest < ActiveSupport::TestCase
    class << self
      attr_accessor :built_css
    end

    # What the kit now writes => the declaration it has to produce.
    REPLACEMENTS = {
      'ps-3' => 'padding-inline-start',
      'pe-8' => 'padding-inline-end',
      'ps-2' => 'padding-inline-start',
      'ms-3' => 'margin-inline-start',
      'ms-4' => 'margin-inline-start',
      'sm:ms-3' => 'margin-inline-start',
      'sm:ms-4' => 'margin-inline-start',
      'inset-e-0' => 'inset-inline-end',
      'inset-e-2' => 'inset-inline-end',
      'inset-e-2.5' => 'inset-inline-end',
      'inset-e-4' => 'inset-inline-end',
      'text-start' => 'text-align: start',
      'sm:text-start' => 'text-align: start',
      'wrap-break-word' => 'overflow-wrap',
      'max-w-xs' => 'max-width'
    }.freeze

    test 'TL1 every class the conversion introduced compiles to a logical declaration' do
      css = build_css

      REPLACEMENTS.each do |klass, declaration|
        rule = rule_for(css, klass)

        assert rule, "#{klass} produced no rule at all"
        assert_includes rule, declaration, "#{klass} should set #{declaration}"
      end
    end

    test 'TL2 a logical inset equals its physical twin in LTR, and its mirror in RTL' do
      css = build_css

      assert_equal declaration_value(css, 'right-4', 'right'), declaration_value(css, 'inset-e-4', 'inset-inline-end')
      assert_equal declaration_value(css, 'pl-3', 'padding-left'), declaration_value(css, 'ps-3', 'padding-inline-start')
    end

    # tailwindcss 4.3.1 emits this one nested (`.rtl\:origin-right { &:where(…) { … } }`), so the
    # direction selector is in the rule's body rather than beside its class.
    test 'TL3 the rtl: variant targets the document direction, not a hand-written selector' do
      css = build_css
      start = css.index('.rtl\\:origin-right')

      assert start, 'rtl:origin-right produced no rule'
      rule = css[start, 200]
      assert_includes rule, ':dir(rtl)'
      assert_includes rule, '[dir="rtl"]'
      assert_includes rule, 'transform-origin: 100%'
    end

    private

    def build_css
      self.class.built_css ||= Dir.mktmpdir do |dir|
        input = File.join(dir, 'in.css')
        output = File.join(dir, 'out.css')
        classes = (REPLACEMENTS.keys + %w[right-4 pl-3 rtl:origin-right rtl:sm:-translate-x-2 origin-left]).join(' ')
        File.write(input, %(@import "tailwindcss" source(none);\n@source inline("#{classes}");\n))
        _stdout, stderr, status = Open3.capture3(Tailwindcss::Ruby.executable, '-i', input, '-o', output)
        assert status.success?, "tailwindcss build failed:\n#{stderr}"
        File.read(output)
      end
    end

    def rule_for(css, klass)
      escaped = Regexp.escape(klass.gsub(%r{([:./])}) { "\\#{Regexp.last_match(1)}" })
      css[/\.#{escaped}[^{]*\{(?<body>[^}]*)\}/, 'body']
    end

    def declaration_value(css, klass, property)
      rule_for(css, klass)[/#{Regexp.escape(property)}:\s*([^;]+);/, 1]&.strip
    end
  end
end
