# frozen_string_literal: true

module Ui
  module Avatar
    # Initials or an icon, underneath the image. Hidden from assistive tech by
    # default -- Ui::AvatarComponent's `alt:` carries the avatar's one accessible
    # name when it has one, so the fallback text is presentational, not a second
    # name. A caller whose fallback does carry meaning on its own overrides that
    # with `aria: { hidden: false }` (the same override Alert's icon takes).
    class FallbackComponent < Ui::Base
      data_slot 'avatar-fallback'

      class_variants(base: 'flex size-full items-center justify-center rounded-full bg-muted text-sm font-medium text-muted-foreground')

      def call
        content_tag(:span, content, root_attributes(aria: { hidden: true }))
      end
    end
  end
end
