# frozen_string_literal: true

module Stress
  WAYS = %i[escape outside own].freeze

  # One row of the overlay table (docs/specs/ui-stress-page § Behavior, item 11): where the
  # overlay's content and trigger are, how it opens, and each dismissal it promises. Every
  # dismissal but a Tooltip's returns focus to the trigger (ui-presence-and-overlay-stack
  # § Behavior, item 12); a hint never moves focus at all (item 8), so it declares none.
  #
  # `scope` is the cluster's id prefix, "page" or "modal", and `outside` the neutral region an
  # outside click on this overlay lands in (§ Behavior, item 12). :backdrop means the dialog's own
  # backdrop.
  Overlay = Struct.new(:key, :scope, :content, :trigger, :outside, :ways, keyword_init: true) do
    def self.build(key, scope = 'page')
      send(:"row_#{key.downcase}", scope)
    end

    def self.row_m(_scope)
      new(key: :M, scope: 'modal', content: '#stress-modal dialog', trigger: '#stress-modal-link', outside: :backdrop, ways: WAYS)
    end

    # No outside click: the dialog's own full-viewport wrapper takes every click, so nothing ever
    # reaches the backdrop. ui-confirm-dialog pins "the backdrop behaving as today" without saying
    # what that is, and this is what it is -- a table edit, as § Assumptions says
    # (docs/specs/ui-stress-page/status.md).
    def self.row_c(_scope)
      new(key: :C, scope: 'modal', content: '#default-confirm', trigger: '#stress-modal-confirm',
          outside: nil, ways: %i[escape own])
    end

    def self.row_s2(_scope)
      new(key: :S2, scope: 'modal', content: '#modal_city-popup', trigger: '#modal_city-combobox', outside: '#modal-outside', ways: WAYS)
    end

    def self.row_s1(scope)
      new(key: :S1, scope: scope, content: "##{scope}_status-popup", trigger: "##{scope}_status-combobox",
          outside: "##{scope}-dd-outside", ways: WAYS)
    end

    %i[dm dd po].each do |name|
      define_singleton_method(:"row_#{name}") do |scope|
        new(key: name.to_s.capitalize.to_sym, scope: scope, content: "##{scope}-#{name} > [data-ui--overlay-target=content]",
            trigger: "##{scope}-#{name}-trigger", outside: "##{scope}-outside", ways: WAYS)
      end
    end

    # The form's own two Selects, which the morph and Back sequences drive: select-only over the
    # enum, and searchable over a collection.
    def self.row_sf(_scope)
      new(key: :SF, scope: 'page', content: '#stress_record_plan-popup', trigger: '#stress_record_plan-combobox',
          outside: '#page-outside', ways: WAYS)
    end

    def self.row_sc(_scope)
      new(key: :SC, scope: 'page', content: '#stress_record_city-popup', trigger: '#stress_record_city-combobox',
          outside: '#page-outside', ways: WAYS)
    end

    def self.row_t(scope)
      new(key: :T, scope: scope, content: "##{scope}-t > [data-ui--overlay-target=content]", trigger: "##{scope}-t-trigger",
          outside: nil, ways: %i[escape own])
    end

    def select?
      %i[S1 S2 SF SC].include?(key)
    end

    # The editable comboboxes, which open on Alt+ArrowDown rather than a click.
    def searchable?
      %i[S2 SC].include?(key)
    end

    def hint?
      key == :T
    end

    # Where focus belongs once this overlay is dismissed, or nil for "wherever it was".
    def returns_focus_to
      hint? ? nil : trigger
    end
  end
end
