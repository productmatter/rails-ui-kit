# frozen_string_literal: true

module Ui
  module Select
    # `multiple: true`'s half of Select, held apart from the component the way Ui::Select::Box and
    # Ui::Select::Primitives are, so the component stays about names, values and wiring. Everything
    # here answers "nothing" for a single Select, which is what keeps its markup unchanged.
    #
    # A multiple Select posts `name[]` with Rails' hidden empty value first -- what
    # `select(..., multiple: true)` renders -- so un-choosing everything clears the attribute.
    class Multiple
      # Rails' option keywords a multiple select has no meaning for. A prompt is how a single select
      # holds "nothing chosen", and a blank is a choice of nothing; a multiple select holds nothing
      # by choosing nothing, so both would be an option the user could tick alongside real ones.
      # `empty_label:` is what the control shows instead.
      REFUSED_KEYS = %i[prompt include_blank].freeze

      attr_reader :name, :empty_label

      def initialize(component:, name:, form:, disabled:, multiple:, empty_label:, include_hidden:, native:)
        @component = component
        @enabled = multiple
        @name = name_for(name)
        @form = form
        @disabled = disabled
        @empty_label = empty_label
        @include_hidden = include_hidden
        return unless @enabled && native

        # Native mode has no multiple form: a desktop browser draws <select multiple> as an open
        # list box several rows tall, which is not a control the kit's box can hold.
        raise ArgumentError, "#{component} has no native: true with multiple: true — a desktop browser " \
                             'draws a multiple select as an open list box, not a control. Leave native: off.'
      end

      def enabled?
        @enabled
      end

      def refuse!(keys)
        refused = enabled? ? keys & REFUSED_KEYS : []
        return if refused.empty?

        raise ArgumentError, "#{@component} has no #{refused.map { |key| "#{key}:" }.join(', ')} with multiple: true — " \
                             'a multiple select holds nothing by choosing nothing. Pass empty_label: for what the control shows then.'
      end

      # Rails' hidden empty value (`include_hidden:`), rendered before the select so a chosen value
      # is the later one. Disabled with the select, unlike Rails' -- a disabled select posts
      # nothing, and its hidden field posting "" would clear the attribute it was showing: the
      # departure Choices makes for its own hidden field.
      def hidden_field_attributes
        return unless enabled? && @include_hidden

        { type: 'hidden', name: name, value: '', autocomplete: hidden_autocomplete,
          form: @form, disabled: (true if @disabled) }.compact
      end

      # What ui--select reads to take its multiple branches, and the placeholder it shows.
      def root_data
        return {} unless enabled?

        { 'ui--select-multiple-value': true, 'ui--select-empty-label-value': empty_label }.compact
      end

      private

      # Rails renders its multiple-select hidden field with autocomplete="off", so a browser can't
      # restore a stale value to it. Rails 8.1 added a flag to drop that hack and defaults it on
      # (ActionView::Base.remove_hidden_field_autocomplete); 7.2 and 8.0 have no such flag and always
      # emit it. Mirror Rails' own select renderer -- omit only when the flag exists and is set -- so
      # the kit's hidden field matches it on every supported version.
      def hidden_autocomplete
        return 'off' unless ActionView::Base.respond_to?(:remove_hidden_field_autocomplete)

        'off' unless ActionView::Base.remove_hidden_field_autocomplete
      end

      # Rails appends `[]` to a multiple select's name, so the param is an array; a name that
      # already says so is left alone.
      def name_for(name)
        name = name.to_s
        enabled? && !name.end_with?('[]') ? "#{name}[]" : name
      end
    end
  end
end
