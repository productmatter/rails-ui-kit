# frozen_string_literal: true

module Ui
  # A callout with optional icon, title and description, in that fixed order
  # whatever order the caller sets them in (Card). Carries no live-region role by
  # default -- a caller that injects the alert dynamically passes `role: "alert"`
  # through forwarded attributes; it needs no keyword of its own for that.
  class AlertComponent < Ui::Base
    data_slot 'alert'

    # The border comes from --input, the same boundary token Input/Alert/outline
    # Badge share (ui-presentational-components, Assumptions): an alert's edge is
    # read as a boundary, not decoration, so it is held to the 3:1 non-text rule.
    # The icon column only opens up when a caller sets one, so a title-only alert
    # doesn't carry a blank gutter.
    class_variants(
      base: 'relative grid w-full grid-cols-[0_1fr] items-start gap-x-3 gap-y-0.5 rounded-lg border px-4 py-3 text-sm',
      variants: {
        variant: {
          default: 'border-input bg-card text-card-foreground',
          destructive: 'border-destructive bg-card text-destructive'
        },
        icon: 'grid-cols-[1rem_1fr] gap-x-3'
      },
      defaults: { variant: :default }
    )

    attr_reader :variant

    renders_one :icon, Ui::Alert::IconComponent
    renders_one :title, Ui::Alert::TitleComponent
    renders_one :description, Ui::Alert::DescriptionComponent

    def initialize(variant: :default, **html_attributes)
      @variant = variant
      super(**html_attributes)
    end

    def variant_values
      { variant: variant, icon: icon? }
    end
  end
end
