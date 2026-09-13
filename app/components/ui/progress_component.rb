# frozen_string_literal: true

module Ui
  # A determinate progress bar. The native <progress> element was tried first, per
  # spec, but its track and fill only take colour through non-standard vendor
  # pseudo-elements -- ::-webkit-progress-bar/-value for Blink/WebKit,
  # ::-moz-progress-bar for Gecko -- and while those paint correctly on screen,
  # `getComputedStyle(element, '::-webkit-progress-value')` comes back transparent
  # in headless Chrome: there is no real DOM node there for the kit's shared colour
  # probe (test/application_system_test_case.rb) to read, so the fill-vs-track 3:1
  # rule can't be verified against it the way every other component's contrast
  # checks are. A div with role="progressbar" gives up nothing visually -- it's
  # also what shadcn/ui itself ships for Progress -- and puts both track and fill
  # on real, measurable elements.
  class ProgressComponent < Ui::Base
    data_slot 'progress'

    class_variants(base: 'relative h-2 w-full overflow-hidden rounded-full bg-muted')

    attr_reader :value, :max

    # value: nil renders as 0, never omitted, so the bar is always a real number --
    # this component is determinate only, per spec; there's no indeterminate variant.
    # label: is the accessible name and is required: unlike Spinner's generic
    # "Loading" default, there's no generic name for "37% of what?" that wouldn't
    # mislead more than it helps, so the caller must say what's progressing --
    # or point at their own visible label with aria: { labelledby: }.
    def initialize(value: nil, max: 100, label: nil, **html_attributes)
      @max = positive_number(max)
      @value = clamped_value(value)
      @label = label
      super(**html_attributes)
      ensure_accessible_name!
    end

    def percentage
      return 0 if max.zero?

      to_number(((value.to_f / max) * 100).clamp(0.0, 100.0))
    end

    def element_attributes
      aria = { valuenow: value, valuemin: 0, valuemax: max }
      aria[:label] = @label if @label.present?
      { role: 'progressbar', aria: aria }
    end

    private

    def positive_number(max)
      number = to_number(max)
      number.positive? ? number : to_number(0)
    end

    def clamped_value(value)
      return to_number(0) if value.nil?

      to_number(value.to_f.clamp(0.0, max.zero? ? 0.0 : max.to_f))
    end

    # Renders "100" rather than "100.0" for the common whole-number case, without
    # losing a caller's fractional value (33.3%).
    def to_number(value)
      float = value.to_f
      (float % 1).zero? ? float.to_i : float
    end

    def accessible_name_given?
      @label.present? || html_attributes.dig(:aria, :label).present? || html_attributes.dig(:aria, :labelledby).present?
    end

    # Fails loudly while developing, the same way an unknown variant does
    # (Ui::Base#raise_on_unknown_variant?): a progress bar with no accessible name
    # is a bug worth catching before it ships, not a rendering error worth crashing
    # a production page over. Outside dev/test it logs and falls back to a generic
    # name so the page still renders.
    def ensure_accessible_name!
      return if accessible_name_given?

      message = 'Ui::ProgressComponent requires an accessible name: pass label:, or forward ' \
                'aria: { label: } / aria: { labelledby: }.'
      raise ArgumentError, message if self.class.raise_on_unknown_variant?

      Rails.logger&.warn("[rails_ui_kit] #{message} Rendering with a generic name instead.")
      html_attributes[:aria] = (html_attributes[:aria] || {}).merge(label: 'Progress')
    end
  end
end
