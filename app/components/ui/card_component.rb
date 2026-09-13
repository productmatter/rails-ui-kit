# frozen_string_literal: true

module Ui
  # A surface with a fixed anatomy: header, body, footer, always in that order.
  # A block that sets no parts renders straight into the card.
  class CardComponent < Ui::Base
    data_slot 'card'

    class_variants(
      base: 'flex flex-col gap-6 rounded-xl border border-border bg-card py-6 text-card-foreground shadow-sm'
    )

    # `content` is reserved by ViewComponent (it is the block itself), so the
    # shadcn CardContent part is exposed as `body`.
    renders_one :header, Ui::Card::HeaderComponent
    renders_one :body, Ui::Card::ContentComponent
    renders_one :footer, Ui::Card::FooterComponent
  end
end
