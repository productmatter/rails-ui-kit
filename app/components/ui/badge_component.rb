# frozen_string_literal: true

module Ui
  class BadgeComponent < Ui::Base
    data_slot 'badge'

    # The outline variant's border comes from --input, not --border: a badge is
    # small enough that its outline reads as the only thing marking its edge, so
    # it is treated as a boundary (rule 4), not decoration, and needs the same 3:1
    # the retuned --input token guarantees Input/Alert/Button's outline variant
    # (ui-presentational-components, Assumptions). The hover tint only fires on the
    # `<a>` form: a plain badge isn't interactive and shouldn't look like it is.
    class_variants(
      base: 'inline-flex w-fit shrink-0 items-center justify-center gap-1 whitespace-nowrap ' \
            'overflow-hidden rounded-md border px-2 py-0.5 text-xs font-medium ' \
            'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring ' \
            '[&>svg]:pointer-events-none [:where(&>svg)]:size-3',
      variants: {
        variant: {
          default: 'border-transparent bg-primary text-primary-foreground [a&]:hover:bg-primary/90',
          secondary: 'border-transparent bg-secondary text-secondary-foreground [a&]:hover:bg-secondary/90',
          destructive: 'border-transparent bg-destructive text-destructive-foreground [a&]:hover:bg-destructive/90',
          outline: 'border-input text-foreground [a&]:hover:bg-accent [a&]:hover:text-accent-foreground'
        }
      },
      defaults: { variant: :default }
    )

    attr_reader :variant, :href

    # `variant:` accepts a symbol or string; nil means the default.
    def initialize(variant: :default, href: nil, **html_attributes)
      @variant = variant
      @href = href
      super(**html_attributes)
    end

    def variant_values
      { variant: variant }
    end

    def root_tag
      link? ? :a : :span
    end

    def element_attributes
      link? ? { href: href } : {}
    end

    private

    def link?
      href.present?
    end
  end
end
