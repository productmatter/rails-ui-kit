# frozen_string_literal: true

module Ui
  class ButtonComponent < Ui::Base
    data_slot 'button'

    # `text-primary-foreground` carries the destructive label because the token
    # contract has no `destructive-foreground`; it is the kit's one near-white ink
    # for saturated surfaces, in both modes.
    class_variants(
      base: 'inline-flex shrink-0 items-center justify-center gap-2 whitespace-nowrap ' \
            'rounded-md text-sm font-medium transition-colors outline-none ' \
            'focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 ' \
            'disabled:pointer-events-none disabled:opacity-50 ' \
            'aria-disabled:pointer-events-none aria-disabled:opacity-50 ' \
            "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
      variants: {
        variant: {
          default: 'bg-primary text-primary-foreground shadow-xs hover:bg-primary/90',
          destructive: 'bg-destructive text-primary-foreground shadow-xs hover:bg-destructive/90 focus-visible:ring-destructive/40',
          outline: 'border border-input bg-background shadow-xs hover:bg-accent hover:text-accent-foreground',
          secondary: 'bg-secondary text-secondary-foreground shadow-xs hover:bg-secondary/80',
          ghost: 'hover:bg-accent hover:text-accent-foreground',
          link: 'text-primary underline-offset-4 hover:underline'
        },
        size: {
          default: 'h-9 px-4 py-2 has-[>svg]:px-3',
          sm: 'h-8 gap-1.5 px-3 has-[>svg]:px-2.5',
          lg: 'h-10 px-6 has-[>svg]:px-4',
          icon: 'size-9'
        }
      },
      defaults: { variant: :default, size: :default }
    )

    attr_reader :variant, :size, :href, :type

    def initialize(variant: :default, size: :default, href: nil, type: 'button', **html_attributes)
      @variant = variant.to_sym
      @size = size.to_sym
      @href = href
      @type = type
      @disabled = html_attributes[:disabled]
      # An <a> ignores `disabled` entirely, so it is translated below rather than forwarded.
      html_attributes.delete(:disabled) if link?
      super(**html_attributes)
    end

    def variant_values
      { variant: variant, size: size }
    end

    def root_tag
      link? ? :a : :button
    end

    # A disabled link drops its href: without one the anchor is inert and
    # unfocusable without JavaScript, and role/aria-disabled keep it announced.
    def element_attributes
      return { type: type } unless link?
      return { href: href } unless disabled?

      { role: 'link', aria: { disabled: true } }
    end

    private

    def link?
      href.present?
    end

    def disabled?
      @disabled.present?
    end
  end
end
