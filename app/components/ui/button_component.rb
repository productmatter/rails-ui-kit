# frozen_string_literal: true

module Ui
  class ButtonComponent < Ui::Base
    data_slot 'button'

    # The focus indicator is an outline, not a box-shadow ring: forced-colors mode
    # (Windows High Contrast) drops box-shadows but keeps outlines, and the offset
    # gap shows the surface behind the button, so the ring contrasts with that
    # surface rather than blending into the button's own fill.
    #
    # A direct child <svg> gets a default size inside :where(), which has zero
    # specificity, so any sizing class the caller puts on the svg (size-*, h-*, w-*)
    # wins. Nested svgs are the caller's markup and are left alone.
    class_variants(
      base: 'inline-flex shrink-0 items-center justify-center gap-2 whitespace-nowrap ' \
            'rounded-md text-sm font-medium transition-colors ' \
            'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring ' \
            'disabled:pointer-events-none disabled:opacity-50 ' \
            'aria-disabled:pointer-events-none aria-disabled:opacity-50 ' \
            '[&_svg]:pointer-events-none [&>svg]:shrink-0 [:where(&>svg)]:size-4',
      variants: {
        variant: {
          default: 'bg-primary text-primary-foreground shadow-xs hover:bg-primary/90',
          destructive: 'bg-destructive text-destructive-foreground shadow-xs hover:bg-destructive/90',
          outline: 'border border-input bg-background dark:bg-muted/50 text-foreground shadow-xs hover:bg-accent hover:text-accent-foreground',
          secondary: 'bg-secondary text-secondary-foreground shadow-xs hover:bg-secondary/80',
          ghost: 'hover:bg-accent hover:text-accent-foreground',
          link: 'text-primary underline-offset-4 hover:underline'
        },
        # Heights come from the shared control scale in engine.css, in arbitrary-value form: a
        # caller's h-* merges over `h-(--token)`, where a named key like `h-control` would
        # survive tailwind_merge beside it. `icon` is a square at the default step, so it lines
        # up beside a default Input whatever the host sets.
        size: {
          default: 'h-(--control-height) px-4 py-2 has-[>svg]:px-3',
          sm: 'h-(--control-height-sm) gap-1.5 px-3 has-[>svg]:px-2.5',
          lg: 'h-(--control-height-lg) px-6 has-[>svg]:px-4',
          icon: 'size-(--control-height)'
        }
      },
      defaults: { variant: :default, size: :default }
    )

    attr_reader :variant, :size, :href, :type

    # `variant:`/`size:` accept a symbol or string; nil means the default.
    def initialize(variant: :default, size: :default, href: nil, type: 'button', **html_attributes)
      @variant = variant
      @size = size
      @href = href
      @type = type
      super(**html_attributes)
      # Taken out of the forwarded attributes and rendered from here: an <a> ignores
      # `disabled` entirely, so this component's own link-vs-button branching needs
      # a real boolean rather than whatever string form the caller forwarded it in.
      @disabled = boolean_attribute?(self.html_attributes.delete(:disabled))
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
      return { type: type, disabled: disabled? } unless link?
      return { href: href } unless disabled?

      { role: 'link', aria: { disabled: true } }
    end

    private

    def link?
      href.present?
    end

    def disabled?
      @disabled
    end
  end
end
