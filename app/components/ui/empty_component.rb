# frozen_string_literal: true

module Ui
  # An empty state: header (media, title, description), then body, in that fixed
  # order whatever order the caller sets them in (Card). `content` is
  # ViewComponent's block, so the shadcn Content part is exposed as `with_body`;
  # its class and data-slot keep the name `content` (rule 3).
  class EmptyComponent < Ui::Base
    data_slot 'empty'

    # `border-dashed` sets the style, not a border -- there's no plain `border`
    # here, so it paints nothing until a caller adds `class: "border"` for a
    # dashed box; nested inside a Card or another bordered surface, most Emptys
    # want no edge of their own.
    class_variants(base: 'flex min-w-0 flex-1 flex-col items-center justify-center gap-6 rounded-lg border-dashed p-6 text-center text-balance md:p-12')

    renders_one :header, Ui::Empty::HeaderComponent
    renders_one :body, Ui::Empty::ContentComponent
  end
end
