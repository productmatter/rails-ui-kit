# frozen_string_literal: true

module Ui
  # An image with a fallback (initials) layered beneath it. No load-detection
  # controller (rule 8): the fallback is always in the DOM and the image sits on
  # top of it (`absolute inset-0`), so a missing `src` or a failed load leaves
  # nothing painted over the fallback and it shows through on its own.
  #
  # Alt text lives on the avatar, not the image. `alt:` absent (the default) means
  # the avatar is decorative -- the common case where a name already sits next to
  # it in text, and repeating it would double-announce. `alt:` present means this
  # avatar is the only identification, so the root becomes `role="img"` with that
  # `aria-label`, and both the image and the fallback stay presentational: one
  # accessible name for the whole avatar, never two, and the image's own `alt`
  # never carries text that a failed load could flash on screen.
  class AvatarComponent < Ui::Base
    data_slot 'avatar'

    class_variants(base: 'relative flex size-8 shrink-0 overflow-hidden rounded-full select-none')

    attr_reader :alt

    renders_one :image, Ui::Avatar::ImageComponent
    renders_one :fallback, Ui::Avatar::FallbackComponent

    def initialize(alt: nil, **html_attributes)
      @alt = alt
      super(**html_attributes)
    end

    def element_attributes
      return {} if alt.blank?

      { role: 'img', aria: { label: alt } }
    end
  end
end
