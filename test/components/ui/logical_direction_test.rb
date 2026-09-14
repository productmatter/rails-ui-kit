# frozen_string_literal: true

require 'test_helper'

module Ui
  # Direction hygiene (ui-localization-rtl § Business rules, rule 1): a component uses the
  # logical utility wherever one exists. The kit makes no RTL support claim — this is about not
  # accruing physical classes that a later RTL pass would have to unpick one by one.
  #
  # Everything in ALLOWED is a decision, with its reason, not a ratchet of whatever happened to
  # be there. Adding to it should feel like a choice.
  class LogicalDirectionTest < ActiveSupport::TestCase
    ROOT = File.expand_path('../../..', __dir__)
    # The docs app too: it is not the kit, but a running docs app that mixes logical and physical
    # classes is the half-converted state this guard exists to prevent.
    SOURCES = Dir[File.join(ROOT, 'app/components/**/*.{rb,erb}')] +
              Dir[File.join(ROOT, 'app/javascript/**/*.js')] +
              Dir[File.join(ROOT, 'examples/app/views/**/*.erb')]

    # A physical-side utility, as it is actually written in a class list. Bare words like
    # `left:` in a JavaScript object, or Floating UI's `left-start` placement, are not classes,
    # so a side that takes a value has to have one. A class carrying Tailwind's own `rtl:` or
    # `ltr:` variant is deliberate pairing, not an oversight, and is skipped.
    VALUE = %r{auto|full|px|reverse|\d+(?:\.\d+)?(?:/\d+)?|\[[^\]]*\]|\([^)]*\)}
    PHYSICAL = /
      (?<![\w-])
      (?<class>-?(?<variants>(?:[a-z0-9\[\]&_>.*()-]+:)*)
        (?:
            (?:m[lr]|p[lr]|left|right|scroll-m[lr]|scroll-p[lr])-(?:#{VALUE})
          | (?:border-[lr]|rounded-[lr]|rounded-[tb][lr])(?:-(?:#{VALUE}|[a-z]+))?
          | text-(?:left|right)
          | float-(?:left|right)
          | clear-(?:left|right)
          | origin-(?:left|right|top-left|top-right|bottom-left|bottom-right)
        ))
      (?![\w-])
    /x

    ALLOWED = {
      # A caller naming a side of the viewport means that side. The slide transforms in
      # components.css are correct in both directions as written.
      'app/components/ui/modal_component.rb' => {
        %w[left-1/2 left-0 left-auto right-0 right-auto] =>
          'position: :left/:right are physical by definition, and left-1/2 with a -50% translate ' \
          'centres identically in either direction'
      },
      'app/components/ui/toast_component.html.erb' => {
        %w[left-0 right-0] => 'a symmetric pair: the timer bar spans the card in either direction',
        %w[origin-left] => 'paired with rtl:origin-right; Tailwind has no logical transform-origin',
        %w[sm:translate-x-2 sm:translate-x-0] =>
          'paired with rtl:sm:-translate-x-2; Tailwind has no logical translate'
      }
    }.freeze

    test 'LD1 no component or controller writes a physical direction class' do
      offenders = SOURCES.flat_map { |file| offending_classes(file) }

      assert_empty offenders, <<~WHY
        Each of these has a logical equivalent that compiles today: ps-/pe-, ms-/me-, inset-s-/inset-e-,
        text-start/text-end, border-s/border-e, rounded-s/rounded-e. Where none exists (transform-origin,
        translate-x), pair the physical class with Tailwind's rtl: variant and allow-list it here.
      WHY
    end

    test 'LD2 the allow-list names only classes that are actually still there' do
      ALLOWED.each do |path, groups|
        source = File.read(File.join(ROOT, path))

        groups.each_key do |classes|
          classes.each do |klass|
            assert_includes source, klass,
                            "#{path} no longer has #{klass}, so its allow-list entry is stale"
          end
        end
      end
    end

    test 'LD3 every physical class kept for want of a logical one is paired with its rtl: variant' do
      toast = File.read(File.join(ROOT, 'app/components/ui/toast_component.html.erb'))

      assert_includes toast, 'rtl:origin-right'
      assert_includes toast, 'rtl:sm:-translate-x-2'
    end

    private

    def offending_classes(file)
      relative = file.delete_prefix("#{ROOT}/")
      allowed = ALLOWED.fetch(relative, {}).keys.flatten

      File.readlines(file).each_with_index.flat_map do |line, index|
        next [] if line.strip.start_with?('#', '//', '<%#', '*')

        physical_classes(line, allowed).map { |klass| "#{relative}:#{index + 1} #{klass}" }
      end
    end

    # A class carrying Tailwind's own rtl:/ltr: variant is the deliberate pairing for a property
    # with no logical form, not an oversight.
    def physical_classes(line, allowed)
      line.to_enum(:scan, PHYSICAL).map { Regexp.last_match }.filter_map do |match|
        klass = match[:class]
        next if allowed.include?(klass) || match[:variants].to_s.match?(/\b(?:rtl|ltr):/)

        klass
      end
    end
  end
end
